package org.opensmarthome.open_smart_home

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONException
import org.json.JSONObject

/**
 * The house's state, a thermostat, and one light on the home screen. As
 * with the scenes widget, the app stores only display text here (never a
 * token); a tap opens the app with an `opensmarthome://` link, and the
 * app acts on it only for the device it put on the widget.
 */
object HomeWidgets {
    private const val PREFS = "home_widgets"

    /** Saves what a widget kind shows and redraws its instances. */
    fun save(context: Context, kind: String, json: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(kind, json)
            .apply()
        val manager = AppWidgetManager.getInstance(context)
        val provider = when (kind) {
            "status" -> StatusWidgetProvider::class.java
            "thermostat" -> ThermostatWidgetProvider::class.java
            "light" -> LightWidgetProvider::class.java
            else -> return
        }
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isNotEmpty()) render(context, manager, kind, ids)
    }

    fun render(context: Context, manager: AppWidgetManager, kind: String, ids: IntArray) {
        val data = read(context, kind)
        for (id in ids) {
            val views = when (kind) {
                "status" -> status(context, data)
                "thermostat" -> thermostat(context, data)
                else -> light(context, data)
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun read(context: Context, kind: String): JSONObject? {
        val json = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(kind, null) ?: return null
        return try {
            JSONObject(json)
        } catch (_: JSONException) {
            null
        }
    }

    private fun status(context: Context, data: JSONObject?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.status_widget)
        val lines = intArrayOf(R.id.line1, R.id.line2, R.id.line3, R.id.line4)
        val texts = data?.optJSONArray("lines")
        views.setTextViewText(
            R.id.title,
            data?.optString("title")?.ifEmpty { null } ?: context.getString(R.string.status_widget_label),
        )
        lines.forEachIndexed { i, line ->
            val text = texts?.optString(i)?.ifEmpty { null }
            views.setViewVisibility(line, if (text == null) View.GONE else View.VISIBLE)
            views.setTextViewText(line, text ?: "")
        }
        views.setTextViewText(
            R.id.updated,
            data?.optString("updated") ?: context.getString(R.string.home_widget_open),
        )
        views.setOnClickPendingIntent(R.id.root, launch(context, "opensmarthome://check"))
        return views
    }

    private fun thermostat(context: Context, data: JSONObject?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.thermostat_widget)
        val has = data != null
        views.setTextViewText(
            R.id.name,
            data?.optString("name") ?: context.getString(R.string.home_widget_open),
        )
        views.setTextViewText(R.id.target, data?.optString("target") ?: "—")
        views.setTextViewText(R.id.current, data?.optString("current") ?: "")
        views.setViewVisibility(R.id.minus, if (has) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.plus, if (has) View.VISIBLE else View.GONE)
        views.setOnClickPendingIntent(R.id.minus, launch(context, "opensmarthome://climate?step=-1"))
        views.setOnClickPendingIntent(R.id.plus, launch(context, "opensmarthome://climate?step=1"))
        views.setOnClickPendingIntent(R.id.root, launch(context, "opensmarthome://open"))
        return views
    }

    private fun light(context: Context, data: JSONObject?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.light_widget)
        val on = data?.optBoolean("on") == true
        views.setTextViewText(
            R.id.name,
            data?.optString("name") ?: context.getString(R.string.home_widget_open),
        )
        views.setTextViewText(R.id.state, data?.optString("state") ?: "")
        views.setInt(
            R.id.root,
            "setBackgroundResource",
            if (on) R.drawable.widget_background_on else R.drawable.widget_background,
        )
        views.setOnClickPendingIntent(
            R.id.root,
            launch(context, if (data == null) "opensmarthome://open" else "opensmarthome://light?action=toggle"),
        )
        return views
    }

    private fun launch(context: Context, link: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse(link))
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

class StatusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        HomeWidgets.render(context, manager, "status", ids)
}

class ThermostatWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        HomeWidgets.render(context, manager, "thermostat", ids)
}

class LightWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        HomeWidgets.render(context, manager, "light", ids)
}
