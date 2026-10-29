package org.opensmarthome.open_smart_home

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "Now playing" in the notification shade with play/pause and next, for
 * the house's speakers (Home Assistant media players), while the app runs.
 * The buttons go back to the app's Flutter part, which sends the command
 * over its own connection; nothing here talks to Home Assistant.
 */
object NowPlaying {
    private const val CHANNEL = "org.opensmarthome/nowplaying"
    private const val NOTIFICATION_CHANNEL = "now_playing"
    private const val NOTIFICATION_ID = 1002
    const val ACTION = "org.opensmarthome.NOW_PLAYING_ACTION"

    private var channel: MethodChannel? = null

    fun attach(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        show(
                            app,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("text") ?: "",
                            call.argument<Boolean>("playing") == true,
                            call.argument<String>("pause") ?: "Pause",
                            call.argument<String>("play") ?: "Play",
                            call.argument<String>("next") ?: "Next",
                            call.argument<String>("channel") ?: "Now playing",
                        )
                        result.success(null)
                    }
                    "hide" -> {
                        NotificationManagerCompat.from(app).cancel(NOTIFICATION_ID)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** A button was pressed: tell the app (if it is running). */
    fun press(context: Context, button: String) {
        val live = channel
        if (live != null) {
            live.invokeMethod("press", button)
        } else {
            // The app is gone: the notification is stale.
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        }
    }

    private fun show(
        context: Context,
        title: String,
        text: String,
        playing: Boolean,
        pause: String,
        play: String,
        next: String,
        channelName: String,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(NOTIFICATION_CHANNEL, channelName, NotificationManager.IMPORTANCE_LOW),
            )
        }
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_home)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (playing) pause else play,
                button(context, "play_pause"),
            )
            .addAction(android.R.drawable.ic_media_next, next, button(context, "next"))
            .build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // No permission to notify: nothing to show.
        }
    }

    private fun button(context: Context, name: String): PendingIntent {
        val intent = Intent(context, NowPlayingReceiver::class.java)
            .setAction(ACTION)
            .putExtra("button", name)
        return PendingIntent.getBroadcast(
            context,
            name.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/** Not exported: only this app's own notification reaches it. */
class NowPlayingReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != NowPlaying.ACTION) return
        NowPlaying.press(context, intent.getStringExtra("button") ?: return)
    }
}
