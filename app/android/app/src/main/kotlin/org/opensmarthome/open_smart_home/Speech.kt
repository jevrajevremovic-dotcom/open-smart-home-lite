package org.opensmarthome.open_smart_home

import android.content.Context
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

/**
 * Assist's spoken answers through the phone's own text-to-speech engine
 * (works offline when the engine has the language). "speak" completes when
 * the sentence has been said, so the app can listen again afterwards.
 */
object Speech {
    private var tts: TextToSpeech? = null
    private var ready = false
    private val pending = mutableMapOf<String, MethodChannel.Result>()

    fun attach(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, "org.opensmarthome/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> speak(app, call.argument<String>("text") ?: "", call.argument<String>("language"), result)
                    "stop" -> {
                        tts?.stop()
                        finishAll()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun speak(context: Context, text: String, language: String?, result: MethodChannel.Result) {
        val engine = tts
        if (engine == null) {
            // First use: start the engine, then say it.
            tts = TextToSpeech(context) { status ->
                ready = status == TextToSpeech.SUCCESS
                if (ready) {
                    tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(id: String?) {}
                        override fun onDone(id: String?) = finish(id, true)
                        @Deprecated("Deprecated in Java")
                        override fun onError(id: String?) = finish(id, false)
                        override fun onError(id: String?, code: Int) = finish(id, false)
                    })
                    say(text, language, result)
                } else {
                    result.success(false)
                }
            }
            return
        }
        if (!ready) {
            result.success(false)
            return
        }
        say(text, language, result)
    }

    private fun say(text: String, language: String?, result: MethodChannel.Result) {
        val engine = tts ?: return result.success(false)
        if (language != null) {
            val locale = Locale.forLanguageTag(language)
            if (engine.isLanguageAvailable(locale) >= TextToSpeech.LANG_AVAILABLE) engine.language = locale
        }
        val id = UUID.randomUUID().toString()
        pending[id] = result
        if (engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), id) != TextToSpeech.SUCCESS) {
            finish(id, false)
        }
    }

    private fun finish(id: String?, ok: Boolean) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            pending.remove(id)?.success(ok)
        }
    }

    private fun finishAll() {
        val all = pending.values.toList()
        pending.clear()
        all.forEach { it.success(false) }
    }
}
