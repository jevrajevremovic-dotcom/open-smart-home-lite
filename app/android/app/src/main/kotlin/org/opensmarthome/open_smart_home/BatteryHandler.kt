package org.opensmarthome.open_smart_home

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import io.flutter.plugin.common.EventChannel

/**
 * Battery level and charging state, sent on every system battery broadcast
 * (the current state first: the broadcast is sticky). Only these three
 * values leave this class.
 */
class BatteryHandler private constructor(private val context: Context) :
    EventChannel.StreamHandler {
    private var receiver: BroadcastReceiver? = null

    companion object {
        @Volatile
        private var instance: BatteryHandler? = null

        fun get(context: Context): BatteryHandler =
            instance ?: synchronized(this) {
                instance ?: BatteryHandler(context.applicationContext).also { instance = it }
            }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                events.success(read(intent) ?: return)
            }
        }
        receiver = r
        val sticky = context.registerReceiver(r, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        sticky?.let { read(it) }?.let { events.success(it) }
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        receiver = null
    }

    private fun read(intent: Intent): Map<String, Any>? {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) return null
        val state = when (intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
            BatteryManager.BATTERY_STATUS_FULL -> "full"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "not_charging"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
            else -> "unknown"
        }
        val charger = when (intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)) {
            BatteryManager.BATTERY_PLUGGED_AC -> "ac"
            BatteryManager.BATTERY_PLUGGED_USB -> "usb"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "wireless"
            BatteryManager.BATTERY_PLUGGED_DOCK -> "dock"
            else -> "none"
        }
        return mapOf("level" to level * 100 / scale, "state" to state, "charger" to charger)
    }
}
