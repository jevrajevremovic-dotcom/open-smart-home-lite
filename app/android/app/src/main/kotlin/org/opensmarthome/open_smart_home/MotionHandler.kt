package org.opensmarthome.open_smart_home

import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import kotlin.math.abs

/**
 * Wake-on-approach for the kiosk: the front camera looks for movement.
 *
 * Each frame (about two per second, at low resolution) is reduced to a
 * 16×12 grid of average brightness and compared with the previous grid;
 * enough changed cells means movement, and the stream sends `true`.
 * Frames are analysed in memory and dropped at once: nothing is stored,
 * shown or sent anywhere. The camera runs only while Dart listens (the
 * kiosk is idle), and Android shows its camera indicator meanwhile.
 */
class MotionHandler(private val activity: FragmentActivity) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null

    @Volatile
    private var sink: EventChannel.EventSink? = null

    private val cols = 16
    private val rows = 12
    private var previous: IntArray? = null
    private var lastFrame = 0L
    private var lastMotion = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            events.error("permission", "camera permission missing", null)
            return
        }
        sink = events
        previous = null
        val future = ProcessCameraProvider.getInstance(activity)
        future.addListener({
            val cameraProvider = try {
                future.get()
            } catch (e: Exception) {
                fail("unavailable", "camera unavailable")
                return@addListener
            }
            if (sink == null) return@addListener
            provider = cameraProvider
            val selector = when {
                cameraProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA) ->
                    CameraSelector.DEFAULT_FRONT_CAMERA
                cameraProvider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA) ->
                    CameraSelector.DEFAULT_BACK_CAMERA
                else -> {
                    fail("unavailable", "no camera")
                    return@addListener
                }
            }
            val use = ImageAnalysis.Builder()
                .setResolutionSelector(
                    ResolutionSelector.Builder()
                        .setResolutionStrategy(
                            ResolutionStrategy(
                                Size(320, 240),
                                ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                            ),
                        )
                        .build(),
                )
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            use.setAnalyzer(executor) { image ->
                try {
                    analyse(image)
                } finally {
                    image.close()
                }
            }
            analysis = use
            try {
                cameraProvider.unbind(use)
                cameraProvider.bindToLifecycle(activity, selector, use)
            } catch (e: Exception) {
                fail("unavailable", "camera busy")
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        sink = null
        val use = analysis
        analysis = null
        if (use != null) {
            use.clearAnalyzer()
            provider?.unbind(use)
        }
        previous = null
    }

    fun dispose() {
        stop()
        executor.shutdown()
    }

    private fun fail(code: String, message: String) {
        val target = sink
        main.post { target?.error(code, message, null) }
        stop()
    }

    private fun analyse(image: androidx.camera.core.ImageProxy) {
        val now = System.currentTimeMillis()
        if (now - lastFrame < 400) return
        lastFrame = now
        // Brightness (Y) plane only.
        val plane = image.planes[0]
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val width = image.width
        val height = image.height
        val grid = IntArray(cols * rows)
        val stepX = maxOf(1, width / (cols * 4))
        val stepY = maxOf(1, height / (rows * 4))
        val counts = IntArray(cols * rows)
        var y = 0
        while (y < height) {
            val cy = minOf(rows - 1, y * rows / height)
            var x = 0
            while (x < width) {
                val cx = minOf(cols - 1, x * cols / width)
                val v = buffer.get(y * rowStride + x * pixelStride).toInt() and 0xFF
                grid[cy * cols + cx] += v
                counts[cy * cols + cx]++
                x += stepX
            }
            y += stepY
        }
        for (i in grid.indices) grid[i] = if (counts[i] == 0) 0 else grid[i] / counts[i]
        val before = previous
        previous = grid
        if (before == null) return
        // Overall brightness change (lights switched, clouds) shifts every
        // cell alike: compare cells relative to the frame average.
        val shift = (grid.sum() - before.sum()) / grid.size
        var changed = 0
        for (i in grid.indices) {
            if (abs(grid[i] - before[i] - shift) > 18) changed++
        }
        if (changed >= grid.size / 12 && now - lastMotion > 1500) {
            lastMotion = now
            val target = sink
            main.post { if (sink === target) target?.success(true) }
        }
    }
}
