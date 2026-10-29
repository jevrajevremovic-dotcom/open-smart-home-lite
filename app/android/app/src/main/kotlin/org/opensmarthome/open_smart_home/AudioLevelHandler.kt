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
 * Nothing is ever written to storage. Recording runs only while it has a
 * listener.
 */
class AudioLevelHandler(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var levelSink: EventChannel.EventSink? = null

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
        if (levelSink == null) stop()
    }

    fun stop() {
        levelSink = null
        running = false
        thread?.join(500)
        thread = null
    }

    private fun fail(code: String, message: String) {
        val sink = levelSink
        main.post { sink?.error(code, message, null) }
        levelSink = null
        running = false
    }

    private fun capture() {
        val rate = 16000
        val frame = rate / 50 // 20 ms
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
