package org.opensmarthome.open_smart_home

import android.Manifest
import android.content.ComponentName
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.home.matter.Matter
import com.google.android.gms.home.matter.commissioning.CommissioningRequest
import android.content.Intent
import android.content.pm.PackageManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: required by local_auth (biometric prompt).
class MainActivity : FlutterFragmentActivity() {
    private var nsd: NsdDiscoveryHandler? = null
    private var widget: MethodChannel? = null
    private var nfc: NfcHandler? = null
    private var assist: MethodChannel? = null
    private var audio: AudioLevelHandler? = null
    private var motion: MotionHandler? = null
    private var micResult: MethodChannel.Result? = null
    private var cameraResult: MethodChannel.Result? = null
    private var matterResult: MethodChannel.Result? = null

    // Google's Matter screens (scan, Bluetooth, network) return here.
    private val matterLauncher =
        registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
            matterResult?.success(result.resultCode == RESULT_OK)
            matterResult = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val handler = NsdDiscoveryHandler(applicationContext)
        nsd = handler
        EventChannel(messenger, "org.opensmarthome/nsd").setStreamHandler(handler)
        MethodChannel(messenger, "org.opensmarthome/device")
            .setMethodCallHandler(DeviceAdminHandler(this))
        MethodChannel(messenger, "org.opensmarthome/updater")
            .setMethodCallHandler(UpdateInstaller(this))

        // Opened as the phone's assistant (long press of home / power).
        assist = MethodChannel(messenger, "org.opensmarthome/assist").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        result.success(intent?.action == Intent.ACTION_ASSIST)
                        if (intent?.action == Intent.ACTION_ASSIST) intent?.action = Intent.ACTION_MAIN
                    }
                    "openSettings" -> {
                        // "Digital assistant app" lives under voice input /
                        // default apps, depending on the Android version.
                        val opened = listOf(
                            android.provider.Settings.ACTION_VOICE_INPUT_SETTINGS,
                            android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS,
                        ).any { action ->
                            runCatching { startActivity(Intent(action)) }.isSuccess
                        }
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        val nfcChannel = MethodChannel(messenger, "org.opensmarthome/nfc")
        nfc = NfcHandler(this, nfcChannel).also { nfcChannel.setMethodCallHandler(it) }

        // One per process: keeps reporting while the cached engine runs in
        // the background service, after this activity is gone.
        EventChannel(messenger, "org.opensmarthome/battery")
            .setStreamHandler(BatteryHandler.get(applicationContext))

        val microphone = AudioLevelHandler(applicationContext)
        audio = microphone
        EventChannel(messenger, "org.opensmarthome/audio_level").setStreamHandler(microphone.levels)
        EventChannel(messenger, "org.opensmarthome/audio_pcm").setStreamHandler(microphone.pcm)
        val motionHandler = MotionHandler(this)
        motion = motionHandler
        EventChannel(messenger, "org.opensmarthome/motion").setStreamHandler(motionHandler)
        MethodChannel(messenger, "org.opensmarthome/camera").setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> requestCamera(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "org.opensmarthome/microphone").setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> requestMicrophone(result)
                else -> result.notImplemented()
            }
        }

        // Kiosk night brightness: this window only, never the system setting.
        MethodChannel(messenger, "org.opensmarthome/brightness").setMethodCallHandler { call, result ->
            if (call.method != "set") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val level = call.argument<Double>("level") ?: -1.0
            window.attributes = window.attributes.apply {
                screenBrightness = if (level < 0) {
                    WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                } else {
                    level.toFloat().coerceIn(0.01f, 1f)
                }
            }
            result.success(null)
        }

        MethodChannel(messenger, MatterCommissioningService.CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "commissionNewDevice") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val request = CommissioningRequest.builder()
                .setCommissioningService(ComponentName(this, MatterCommissioningService::class.java))
                .build()
            Matter.getCommissioningClient(this)
                .commissionDevice(request)
                .addOnSuccessListener { sender ->
                    matterResult?.success(false)
                    matterResult = result
                    matterLauncher.launch(IntentSenderRequest.Builder(sender).build())
                }
                // No Google Play services (or too old): the app says so.
                .addOnFailureListener { e ->
                    val status = (e as? com.google.android.gms.common.api.ApiException)?.statusCode
                    android.util.Log.w("OpenSmartHome", "Matter commissioning unavailable: status=$status ${e.message}")
                    result.error("unavailable", e.message, status)
                }
        }

        MethodChannel(messenger, "org.opensmarthome/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ConnectionService.start(
                        applicationContext,
                        call.argument<String>("title") ?: "Open Smart Home",
                        call.argument<String>("text") ?: "",
                    )
                    result.success(null)
                }
                "stop" -> {
                    ConnectionService.stop(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        widget = MethodChannel(messenger, "org.opensmarthome/widget").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "setScenes" -> {
                        ScenesWidgetProvider.save(
                            applicationContext,
                            call.argument<String>("scenes") ?: "[]",
                            call.argument<String>("emptyText") ?: "",
                        )
                        result.success(null)
                    }
                    "setHomeWidget" -> {
                        HomeWidgets.save(
                            applicationContext,
                            call.argument<String>("kind") ?: "",
                            call.argument<String>("json"),
                        )
                        result.success(null)
                    }
                    // The widget link that started the app, read once.
                    "initialLink" -> {
                        result.success(widgetLink(intent))
                        intent?.data = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    // The engine outlives this screen (see Engines): while the connection
    // service runs, closing the app keeps it connected to Home Assistant.
    override fun getCachedEngineId(): String {
        Engines.ensure(this)
        return Engines.MAIN
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing && !ConnectionService.running) Engines.destroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        widgetLink(intent)?.let { widget?.invokeMethod("link", it) }
        nfc?.onNewIntent(intent)
        if (intent.action == Intent.ACTION_ASSIST) assist?.invokeMethod("open", null)
    }

    // Dart may not get to cancel the stream when the activity goes away.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nsd?.stop()
        nsd = null
        audio?.stop()
        audio = null
        motion?.dispose()
        motion = null
        nfc?.dispose()
        nfc = null
        assist?.setMethodCallHandler(null)
        assist = null
        widget?.setMethodCallHandler(null)
        widget = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun requestMicrophone(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        micResult?.success(false)
        micResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), MIC_REQUEST)
    }

    private fun requestCamera(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        cameraResult?.success(false)
        cameraResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST)
    }

    @Deprecated("Still the callback for ActivityCompat.requestPermissions")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        when (requestCode) {
            MIC_REQUEST -> {
                micResult?.success(granted)
                micResult = null
            }
            CAMERA_REQUEST -> {
                cameraResult?.success(granted)
                cameraResult = null
            }
        }
    }

    private fun widgetLink(intent: Intent?): String? =
        intent?.data?.takeIf { it.scheme == "opensmarthome" }?.toString()

    companion object {
        private const val MIC_REQUEST = 4711
        private const val CAMERA_REQUEST = 4712
    }
}
