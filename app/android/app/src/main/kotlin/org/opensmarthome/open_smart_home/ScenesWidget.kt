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
import org.json.JSONArray
import org.json.JSONException

/**
 * Home screen widget with up to four scene buttons. The app stores only
 * scene ids and names here (no token); a tap opens the app with
 * `opensmarthome://scene?id=…`, and the app runs the scene once its data
 * is live.
 */
class ScenesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    companion object {
        private const val PREFS = "scenes_widget"
        private val buttons = intArrayOf(R.id.scene1, R.id.scene2, R.id.scene3, R.id.scene4)

        /** Saves what the widget shows and redraws every instance. */
        fun save(context: Context, scenesJson: String, emptyText: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("scenes", scenesJson)
                .putString("emptyText", emptyText)
                .apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ScenesWidgetProvider::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val scenes = parse(prefs.getString("scenes", null))
            val empty = prefs.getString("emptyText", null)
                ?: context.getString(R.string.scenes_widget_empty)
            for (widgetId in ids) {
                val views = RemoteViews(context.packageName, R.layout.scenes_widget)
                buttons.forEachIndexed { i, button ->
                    val scene = scenes.getOrNull(i)
                    if (scene == null) {
                        views.setViewVisibility(button, View.GONE)
                    } else {
                        views.setViewVisibility(button, View.VISIBLE)
                        views.setTextViewText(button, scene.second)
                        views.setOnClickPendingIntent(
                            button,
                            launch(context, "opensmarthome://scene?id=" + Uri.encode(scene.first)),
                        )
                    }
                }
                views.setViewVisibility(R.id.empty, if (scenes.isEmpty()) View.VISIBLE else View.GONE)
                views.setTextViewText(R.id.empty, empty)
                views.setOnClickPendingIntent(R.id.empty, launch(context, "opensmarthome://open"))
                manager.updateAppWidget(widgetId, views)
            }
        }

        private fun launch(context: Context, link: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(Uri.parse(link))
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            // The data URI makes each button's intent distinct.
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun parse(json: String?): List<Pair<String, String>> {
            if (json == null) return emptyList()
            return try {
                val array = JSONArray(json)
                (0 until minOf(array.length(), buttons.size)).mapNotNull { i ->
                    val o = array.optJSONObject(i) ?: return@mapNotNull null
                    val id = o.optString("id")
                    val name = o.optString("name")
                    if (id.isEmpty() || name.isEmpty()) null else id to name
                }
            } catch (_: JSONException) {
                emptyList()
            }
        }
    }
}
