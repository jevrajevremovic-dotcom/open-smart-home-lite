package org.opensmarthome.open_smart_home

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.util.UUID

/**
 * Listens to Bluetooth LE advertisements of the sensors the app reads
 * (BTHome, pvvx/ATC thermometers, SwitchBot, Govee) without connecting to
 * them. Each advertisement is sent as a map (`address`, `name`, `rssi`,
 * `serviceData` by UUID, `manufacturerData` by company id). Filtered by
 * those UUIDs and companies, so Android keeps scanning with the screen off.
 * Works with or without a screen (attached to the engine, not the activity).
 */
class BleScanHandler(private val context: Context) : EventChannel.StreamHandler {
    companion object {
        fun attach(context: Context, engine: FlutterEngine) {
            EventChannel(engine.dartExecutor.binaryMessenger, "org.opensmarthome/ble")
                .setStreamHandler(BleScanHandler(context.applicationContext))
        }

        /** The one permission scanning needs, by Android version. */
        val permission: String =
            if (Build.VERSION.SDK_INT >= 31) Manifest.permission.BLUETOOTH_SCAN
            else Manifest.permission.ACCESS_FINE_LOCATION

        fun hasPermission(context: Context): Boolean =
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

        private fun uuid16(short: Int): ParcelUuid =
            ParcelUuid(UUID.fromString(String.format("0000%04x-0000-1000-8000-00805f9b34fb", short)))

        /** BTHome, pvvx/ATC (Environmental Sensing), SwitchBot (old and new). */
        private val serviceUuids = listOf(0xFCD2, 0x181A, 0xFD3D, 0x0D00)

        /** Govee thermometers. */
        private val companies = listOf(0xEC88)
    }

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var callback: ScanCallback? = null

    @SuppressLint("MissingPermission")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
        if (adapter == null) {
            events.error("unsupported", "no Bluetooth", null)
            return
        }
        if (!adapter.isEnabled) {
            events.error("off", "Bluetooth is off", null)
            return
        }
        if (!hasPermission(context)) {
            events.error("permission", "scan permission missing", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            events.error("off", "no scanner", null)
            return
        }
        sink = events
        val filters = serviceUuids.map {
            ScanFilter.Builder().setServiceData(uuid16(it), ByteArray(0)).build()
        } + companies.map {
            ScanFilter.Builder().setManufacturerData(it, ByteArray(0)).build()
        }
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
            .build()
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val map = toMap(result)
                main.post { sink?.success(map) }
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                val maps = results.map { toMap(it) }
                main.post { maps.forEach { sink?.success(it) } }
            }

            override fun onScanFailed(errorCode: Int) {
                main.post { sink?.error("failed", "scan error $errorCode", null) }
            }
        }
        callback = cb
        try {
            scanner.startScan(filters, settings, cb)
        } catch (e: RuntimeException) {
            callback = null
            sink = null
            events.error("failed", e.javaClass.simpleName, null)
        }
    }

    override fun onCancel(arguments: Any?) = stop()

    @SuppressLint("MissingPermission")
    fun stop() {
        val cb = callback ?: return
        callback = null
        sink = null
        try {
            context.getSystemService(BluetoothManager::class.java)
                ?.adapter?.bluetoothLeScanner?.stopScan(cb)
        } catch (_: RuntimeException) {
            // Bluetooth already off.
        }
    }

    @SuppressLint("MissingPermission")
    private fun toMap(result: ScanResult): Map<String, Any?> {
        val record = result.scanRecord
        val manufacturer = mutableMapOf<Int, ByteArray>()
        record?.manufacturerSpecificData?.let { data ->
            for (i in 0 until data.size()) manufacturer[data.keyAt(i)] = data.valueAt(i)
        }
        return mapOf(
            "address" to result.device.address,
            "name" to record?.deviceName,
            "rssi" to result.rssi,
            "serviceData" to (record?.serviceData?.mapKeys { it.key.uuid.toString() } ?: emptyMap()),
            "manufacturerData" to manufacturer,
        )
    }
}
