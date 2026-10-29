package org.opensmarthome.open_smart_home

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Home Assistant NFC tags: `https://www.home-assistant.io/tag/<id>`, the
 * format of the official apps, so tags work with either. Reading comes in
 * as an intent (NDEF_DISCOVERED, or a scanned QR code); writing uses reader
 * mode while the user holds a tag to the phone.
 */
class NfcHandler(private val activity: Activity, private val channel: MethodChannel) :
    MethodChannel.MethodCallHandler {
    private val main = Handler(Looper.getMainLooper())
    private var pendingWrite: MethodChannel.Result? = null
    private var initialTag: String? = scan(activity.intent)

    companion object {
        private val ID = Regex("^[A-Za-z0-9_-]{1,64}$")

        /**
         * `nfc:<id>` for a tag held to the phone (Android attaches the real
         * [Tag]), `link:<id>` for the same address from a QR code, a web
         * page or another app — which any app could send, so the app asks
         * before telling Home Assistant.
         */
        fun scan(intent: Intent?): String? {
            val id = tagId(intent) ?: return null
            @Suppress("DEPRECATION")
            val physical = intent?.action == NfcAdapter.ACTION_NDEF_DISCOVERED &&
                (if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
                } else {
                    intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
                }) != null
            return if (physical) "nfc:$id" else "link:$id"
        }

        fun tagId(intent: Intent?): String? {
            val uri = intent?.data ?: ndefUri(intent) ?: return null
            if (uri.scheme != "https" || uri.host != "www.home-assistant.io") return null
            val path = uri.path ?: return null
            if (!path.startsWith("/tag/")) return null
            return path.removePrefix("/tag/").takeIf { ID.matches(it) }
        }

        @Suppress("DEPRECATION")
        private fun ndefUri(intent: Intent?): Uri? {
            if (intent?.action != NfcAdapter.ACTION_NDEF_DISCOVERED) return null
            val messages = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES, NdefMessage::class.java)
            } else {
                intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            } ?: return null
            return messages.filterIsInstance<NdefMessage>()
                .flatMap { it.records.toList() }
                .firstNotNullOfOrNull { it.toUri() }
        }
    }

    /** A tag scanned while the app runs. */
    fun onNewIntent(intent: Intent) {
        scan(intent)?.let { channel.invokeMethod("scanned", it) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> {
                val adapter = NfcAdapter.getDefaultAdapter(activity)
                result.success(mapOf("hardware" to (adapter != null), "enabled" to (adapter?.isEnabled == true)))
            }
            "initialTag" -> {
                result.success(initialTag)
                initialTag = null
            }
            "write" -> write(call.argument<String>("uri"), result)
            "cancel" -> {
                stopReader()
                pendingWrite?.error("cancelled", "write cancelled", null)
                pendingWrite = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun write(uri: String?, result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(activity)
        if (uri == null || adapter == null || !adapter.isEnabled) {
            result.error("unavailable", "NFC is off or missing", null)
            return
        }
        pendingWrite?.error("cancelled", "replaced", null)
        pendingWrite = result
        val message = NdefMessage(arrayOf(NdefRecord.createUri(uri)))
        val flags = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V
        adapter.enableReaderMode(activity, { tag -> writeTag(tag, message) }, flags, null)
    }

    private fun writeTag(tag: Tag, message: NdefMessage) {
        val outcome: String? = try {
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()
                try {
                    when {
                        !ndef.isWritable -> "read_only"
                        ndef.maxSize < message.toByteArray().size -> "too_small"
                        else -> {
                            ndef.writeNdefMessage(message)
                            null
                        }
                    }
                } finally {
                    runCatching { ndef.close() }
                }
            } else {
                val formatable = NdefFormatable.get(tag)
                if (formatable == null) {
                    "unsupported"
                } else {
                    formatable.connect()
                    try {
                        formatable.format(message)
                        null
                    } finally {
                        runCatching { formatable.close() }
                    }
                }
            }
        } catch (e: Exception) {
            "failed"
        }
        main.post {
            stopReader()
            val result = pendingWrite ?: return@post
            pendingWrite = null
            if (outcome == null) result.success(true) else result.error(outcome, outcome, null)
        }
    }

    private fun stopReader() {
        runCatching { NfcAdapter.getDefaultAdapter(activity)?.disableReaderMode(activity) }
    }

    fun dispose() {
        stopReader()
        pendingWrite?.error("cancelled", "activity gone", null)
        pendingWrite = null
    }
}
