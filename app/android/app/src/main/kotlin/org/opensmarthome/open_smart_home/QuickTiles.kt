package org.opensmarthome.open_smart_home

import android.app.PendingIntent
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/**
 * Three Quick Settings tiles. The app tells them what to show ("update":
 * label, on/off); a tap is queued and handed to the app, which starts in
 * the background if needed and sends the command to Home Assistant.
 * Only labels and on/off are stored here; no tokens, no addresses.
 */
object QuickTiles {
    private const val PREFS = "quick_tiles"
    private const val CHANNEL = "org.opensmarthome/tiles"
    private var channel: MethodChannel? = null

    /** Tiles on screen right now (the menu is open): redrawn on update. */
    val listening = mutableSetOf<QuickTileService>()

    val services = listOf(QuickTile1::class.java, QuickTile2::class.java, QuickTile3::class.java)

    /** Called once per engine (see [Engines.ensure]). */
    fun attach(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        prefs(app).edit().putString("tiles", call.argument<String>("tiles")).apply()
                        for (s in services) TileService.requestListeningState(app, ComponentName(app, s))
                        // Open menu: Android does not ask again, so redraw now.
                        for (tile in listening.toList()) tile.render()
                        result.success(null)
                    }
                    "takePending" -> {
                        val p = prefs(app)
                        val pending = p.getString("pending", "[]")
                        p.edit().remove("pending").apply()
                        result.success(pending)
                    }
                    "requestAdd" -> requestAdd(app, call.argument<Int>("index") ?: 0, call.argument<String>("label") ?: "", result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun state(context: Context, index: Int): Pair<String, Boolean?>? {
        val json = prefs(context).getString("tiles", null) ?: return null
        val list = runCatching { JSONArray(json) }.getOrNull() ?: return null
        val item = list.optJSONObject(index) ?: return null
        val label = item.optString("label").takeIf { it.isNotEmpty() } ?: return null
        val active = if (item.isNull("active")) null else item.optBoolean("active")
        return label to active
    }

    fun click(context: Context, index: Int) {
        val p = prefs(context)
        val pending = runCatching { JSONArray(p.getString("pending", "[]")) }.getOrDefault(JSONArray())
        pending.put(index)
        p.edit().putString("pending", pending.toString()).apply()
        // Starts the app's engine without a screen if it is not running.
        Engines.ensure(context)
        channel?.invokeMethod("clicked", null)
    }

    private fun requestAdd(context: Context, index: Int, label: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || index !in services.indices) {
            result.success(false)
            return
        }
        val manager = context.getSystemService(StatusBarManager::class.java)
        manager.requestAddTileService(
            ComponentName(context, services[index]),
            label,
            Icon.createWithResource(context, R.drawable.ic_stat_home),
            context.mainExecutor,
        ) { code -> result.success(code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED || code == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED) }
    }
}

abstract class QuickTileService(private val index: Int) : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        QuickTiles.listening.add(this)
        render()
    }

    override fun onStopListening() {
        QuickTiles.listening.remove(this)
        super.onStopListening()
    }

    fun render() {
        val tile = qsTile ?: return
        val state = QuickTiles.state(this, index)
        if (state == null) {
            tile.label = getString(R.string.quick_tile_unset)
            tile.state = Tile.STATE_INACTIVE
        } else {
            tile.label = state.first
            tile.state = when (state.second) {
                true -> Tile.STATE_ACTIVE
                false -> Tile.STATE_INACTIVE
                null -> Tile.STATE_INACTIVE
            }
        }
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_home)
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        if (QuickTiles.state(this, index) == null) {
            // Not set up yet: open the app to choose what it does.
            val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (Build.VERSION.SDK_INT >= 34) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(this, index, intent, PendingIntent.FLAG_IMMUTABLE),
                )
            } else {
                @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
                startActivityAndCollapse(intent)
            }
            return
        }
        // Only an unlocked phone switches things.
        if (isLocked) unlockAndRun { QuickTiles.click(this, index) } else QuickTiles.click(this, index)
    }
}

class QuickTile1 : QuickTileService(0)
class QuickTile2 : QuickTileService(1)
class QuickTile3 : QuickTileService(2)
