package org.opensmarthome.open_smart_home

import android.Manifest
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
    private var audio: AudioLevelHandler? = null
    private var motion: MotionHandler? = null
    private var micResult: MethodChannel.Result? = null
    private var cameraResult: MethodChannel.Result? = null
    private var bleResult: MethodChannel.Result? = null

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

        MethodChannel(messenger, "org.opensmarthome/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ConnectionService.start(
                        applicationContext,
                        call.argument<String>("title") ?: "Open Smart Home Lite",
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
    // service runs, closing the app keeps the automations running.
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
    }

    // Dart may not get to cancel the stream when the activity goes away.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nsd?.stop()
        nsd = null
        audio?.stop()
        audio = null
        motion?.dispose()
        motion = null
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

    private fun requestBle(result: MethodChannel.Result) {
        if (BleScanHandler.hasPermission(this)) {
            result.success(true)
            return
        }
        bleResult?.success(false)
        bleResult = result
        ActivityCompat.requestPermissions(this, arrayOf(BleScanHandler.permission), BLE_REQUEST)
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
            BLE_REQUEST -> {
                bleResult?.success(granted)
                bleResult = null
            }
        }
    }

    private fun widgetLink(intent: Intent?): String? =
        intent?.data?.takeIf { it.scheme == "opensmarthome" }?.toString()

    companion object {
        private const val MIC_REQUEST = 4711
        private const val BLE_REQUEST = 4713
        private const val CAMERA_REQUEST = 4712
    }
}
