package org.opensmarthome.open_smart_home

import android.app.Service
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.google.android.gms.home.matter.commissioning.CommissioningCompleteMetadata
import com.google.android.gms.home.matter.commissioning.CommissioningRequestMetadata
import com.google.android.gms.home.matter.commissioning.CommissioningService
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play services does the Bluetooth part of adding a new Matter
 * device (onboarding code, Wi-Fi/Thread credentials) and then hands the
 * device, now on the network with its commissioning window open, to this
 * service. The Flutter side asks Home Assistant's Matter integration to
 * take it over (`matter/commission_on_network`), the same way Home
 * Assistant's own Android app does.
 */
class MatterCommissioningService : Service(), CommissioningService.Callback {
    private lateinit var delegate: CommissioningService

    override fun onCreate() {
        super.onCreate()
        delegate = CommissioningService.Builder(this).setCallback(this).build()
    }

    override fun onBind(intent: Intent?): IBinder = delegate.asBinder()

    override fun onCommissioningRequested(metadata: CommissioningRequestMetadata) {
        val args = mapOf(
            "pin" to metadata.passcode,
            "ip" to metadata.networkLocation.formattedIpAddress,
        )
        Handler(Looper.getMainLooper()).post {
            val engine = Engines.ensure(this)
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                "commissionOnNetwork",
                args,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        delegate.sendCommissioningComplete(CommissioningCompleteMetadata.builder().build())
                    }

                    override fun error(code: String, message: String?, details: Any?) = fail()

                    override fun notImplemented() = fail()
                },
            )
        }
    }

    private fun fail() {
        delegate.sendCommissioningError(CommissioningService.CommissioningError.OTHER)
    }

    companion object {
        const val CHANNEL = "org.opensmarthome/matter"
    }
}
