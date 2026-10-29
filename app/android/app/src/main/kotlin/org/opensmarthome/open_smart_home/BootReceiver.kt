package org.opensmarthome.open_smart_home

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** After a restart, reconnects if the user chose to receive messages always. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!ConnectionService.enabled(context)) return
        val prefs = context.getSharedPreferences("connection_service", Context.MODE_PRIVATE)
        ConnectionService.start(
            context,
            prefs.getString("title", "Open Smart Home") ?: "Open Smart Home",
            prefs.getString("text", "") ?: "",
        )
    }
}
