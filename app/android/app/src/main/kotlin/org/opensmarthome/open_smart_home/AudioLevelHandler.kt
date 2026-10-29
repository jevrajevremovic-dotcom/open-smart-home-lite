package org.opensmarthome.open_smart_home

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs
import kotlin.math.max

/**
 * The kiosk microphone: one recorder shared by two streams, so the clap and
 * the wake word can listen at the same time.
 *
 * [levels]: loudness for clap detection, one number per 20 ms frame (the
 * loudest sample, 0…1). The samples are discarded right after the peak is
 * taken.
 *
 * [pcm]: raw 16 kHz 16-bit mono audio in 100 ms chunks (little-endian
 * bytes) for the wake word, which the Dart side streams to the user's own
 * Home Assistant only.
 *
 * Nothing is ever written to storage. Recording runs only while at least
 * one stream has a listener.
 */
class AudioLevelHandler(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var levelSink: EventChannel.EventSink? = null

    @Volatile
    private var pcmSink: EventChannel.EventSink? = null

    @Volatile
    private var running = false
    private var thread: Thread? = null

    val levels = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            if (!permitted(events)) return
            levelSink = events
            start()
        }

        override fun onCancel(arguments: Any?) {
            levelSink = null
            stopIfIdle()
        }
    }

    val pcm = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            if (!permitted(events)) return
            pcmSink = events
            start()
        }

        override fun onCancel(arguments: Any?) {
            pcmSink = null
            stopIfIdle()
        }
    }

    private fun permitted(events: EventChannel.EventSink): Boolean {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED
        ) {
            return true
        }
        events.error("permission", "microphone permission missing", null)
        return false
    }

    private fun start() {
        if (running) return
        running = true
        thread = Thread({ capture() }, "microphone").apply {
            isDaemon = true
            start()
        }
    }

    private fun stopIfIdle() {
        if (levelSink == null && pcmSink == null) stop()
    }

    fun stop() {
        levelSink = null
        pcmSink = null
        running = false
        thread?.join(500)
        thread = null
    }

    private fun fail(code: String, message: String) {
        val sinks = listOfNotNull(levelSink, pcmSink)
        main.post { sinks.forEach { it.error(code, message, null) } }
        levelSink = null
        pcmSink = null
        running = false
    }

    private fun capture() {
        val rate = 16000
        val frame = rate / 50 // 20 ms
        val framesPerChunk = 5 // 100 ms of audio for the wake word
        val record = try {
            AudioRecord(
                // No automatic gain control: claps keep their sharp peak.
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                max(
                    AudioRecord.getMinBufferSize(
                        rate,
                        AudioFormat.CHANNEL_IN_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                    ),
                    frame * 2 * 10,
                ),
            )
        } catch (e: SecurityException) {
            fail("permission", "microphone not allowed")
            return
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            fail("unavailable", "microphone unavailable")
            return
        }
        val buffer = ShortArray(frame)
        val chunk = ByteArray(frame * 2 * framesPerChunk)
        var filled = 0
        try {
            record.startRecording()
            while (running) {
                val n = record.read(buffer, 0, frame)
                if (n <= 0) continue
                levelSink?.let { sink ->
                    var peak = 0
                    for (i in 0 until n) peak = max(peak, abs(buffer[i].toInt()))
                    val level = peak / 32768.0
                    main.post { if (levelSink === sink) sink.success(level) }
                }
                val pcmTarget = pcmSink
                if (pcmTarget == null) {
                    filled = 0
                    continue
                }
                for (i in 0 until n) {
                    val v = buffer[i].toInt()
                    chunk[filled++] = (v and 0xFF).toByte()
                    chunk[filled++] = ((v shr 8) and 0xFF).toByte()
                    if (filled == chunk.size) {
                        val out = chunk.copyOf()
                        filled = 0
                        main.post { if (pcmSink === pcmTarget) pcmTarget.success(out) }
                    }
                }
            }
        } finally {
            try {
                record.stop()
            } catch (_: IllegalStateException) {
            }
            record.release()
        }
    }
}
