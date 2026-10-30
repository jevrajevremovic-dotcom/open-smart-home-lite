package org.opensmarthome.open_smart_home

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * Writes one value to a Bluetooth LE device's characteristic (a SwitchBot
 * Bot's press, a Curtain's position): connects, finds the characteristic,
 * writes, disconnects. `write(address, service, characteristic, value)`
 * answers `true`, or an error (`permission`, `off`, `timeout`, `failed`).
 */
class BleGattHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        fun attach(context: Context, engine: FlutterEngine) {
            MethodChannel(engine.dartExecutor.binaryMessenger, "org.opensmarthome/ble_gatt")
                .setMethodCallHandler(BleGattHandler(context.applicationContext))
        }

        private const val TIMEOUT_MS = 15_000L
    }

    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "write") {
            result.notImplemented()
            return
        }
        val address = call.argument<String>("address")
        val service = call.argument<String>("service")
        val characteristic = call.argument<String>("characteristic")
        val value = call.argument<ByteArray>("value")
        if (address == null || service == null || characteristic == null || value == null) {
            result.error("failed", "missing arguments", null)
            return
        }
        write(address, UUID.fromString(service), UUID.fromString(characteristic), value, result)
    }

    @SuppressLint("MissingPermission")
    private fun write(
        address: String,
        service: UUID,
        characteristic: UUID,
        value: ByteArray,
        result: MethodChannel.Result,
    ) {
        if (!BleScanHandler.hasPermission(context)) {
            result.error("permission", "Bluetooth permission missing", null)
            return
        }
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("off", "Bluetooth is off", null)
            return
        }
        val device = try {
            adapter.getRemoteDevice(address)
        } catch (e: IllegalArgumentException) {
            result.error("failed", "bad address", null)
            return
        }
        var answered = false
        var gatt: BluetoothGatt? = null
        fun finish(error: String?) {
            main.post {
                if (answered) return@post
                answered = true
                try {
                    gatt?.disconnect()
                    gatt?.close()
                } catch (_: RuntimeException) {
                }
                if (error == null) result.success(true) else result.error(error, error, null)
            }
        }
        main.postDelayed({ finish("timeout") }, TIMEOUT_MS)
        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                when {
                    newState == BluetoothProfile.STATE_CONNECTED -> g.discoverServices()
                    newState == BluetoothProfile.STATE_DISCONNECTED -> finish("failed")
                }
            }

            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                val c = g.getService(service)?.getCharacteristic(characteristic)
                if (c == null) {
                    finish("failed")
                    return
                }
                val ok = if (Build.VERSION.SDK_INT >= 33) {
                    g.writeCharacteristic(
                        c,
                        value,
                        BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
                    ) == BluetoothGatt.GATT_SUCCESS
                } else {
                    @Suppress("DEPRECATION")
                    c.value = value
                    @Suppress("DEPRECATION")
                    g.writeCharacteristic(c)
                }
                if (!ok) finish("failed")
            }

            override fun onCharacteristicWrite(
                g: BluetoothGatt,
                c: BluetoothGattCharacteristic,
                status: Int,
            ) {
                finish(if (status == BluetoothGatt.GATT_SUCCESS) null else "failed")
            }
        }
        gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
    }
}
