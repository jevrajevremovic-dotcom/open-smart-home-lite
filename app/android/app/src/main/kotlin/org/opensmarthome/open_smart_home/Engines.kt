package org.opensmarthome.open_smart_home

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * One Flutter engine for the whole process, created by whoever needs it
 * first: the screen, or the connection service when the app was closed
 * (or the phone restarted). Then the app keeps its connection to Home
 * Assistant, and receives its messages, without a screen.
 */
object Engines {
    const val MAIN = "main"

    fun ensure(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(MAIN)?.let { return it }
        val engine = FlutterEngine(context.applicationContext)
        // Before Dart starts, so the app can ask for queued tile taps.
        QuickTiles.attach(context, engine)
        Speech.attach(context, engine)
        NowPlaying.attach(context, engine)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(MAIN, engine)
        return engine
    }

    fun destroy() {
        val cache = FlutterEngineCache.getInstance()
        cache.get(MAIN)?.destroy()
        cache.remove(MAIN)
    }
}
