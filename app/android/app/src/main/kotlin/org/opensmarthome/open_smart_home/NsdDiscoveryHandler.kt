package org.opensmarthome.open_smart_home

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.net.Inet4Address

/**
 * Zeroconf discovery with Android's NsdManager. Listening with a service
 * type starts a search; each resolved service is sent as a map
 * (`status`, `name`, `port`, `addresses`, `txt`), a lost one as
 * `status: lost` with its name. Cancelling stops the search.
 */
class NsdDiscoveryHandler(context: Context) : EventChannel.StreamHandler {
    private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val main = Handler(Looper.getMainLooper())
    private var listener: NsdManager.DiscoveryListener? = null
    private var sink: EventChannel.EventSink? = null

    // Older Android resolves one service at a time.
    private val queue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val type = arguments as? String
        if (type == null) {
            events.error("bad_args", "service type expected", null)
            return
        }
        stop()
        sink = events
        val l = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                main.post { sink?.error("start_failed", "NsdManager error $errorCode", null) }
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}

            override fun onDiscoveryStarted(serviceType: String) {}

            override fun onDiscoveryStopped(serviceType: String) {}

            override fun onServiceFound(info: NsdServiceInfo) {
                main.post {
                    queue.addLast(info)
                    resolveNext()
                }
            }

            override fun onServiceLost(info: NsdServiceInfo) {
                main.post {
                    sink?.success(mapOf("status" to "lost", "name" to info.serviceName))
                }
            }
        }
        listener = l
        try {
            nsd.discoverServices(type, NsdManager.PROTOCOL_DNS_SD, l)
        } catch (e: RuntimeException) {
            listener = null
            events.error("start_failed", e.javaClass.simpleName, null)
        }
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        listener?.let {
            try {
                nsd.stopServiceDiscovery(it)
            } catch (_: RuntimeException) {
                // Already stopped or never started.
            }
        }
        listener = null
        sink = null
        queue.clear()
    }

    private fun resolveNext() {
        if (resolving || sink == null) return
        val info = queue.removeFirstOrNull() ?: return
        resolving = true
        @Suppress("DEPRECATION")
        nsd.resolveService(info, object : NsdManager.ResolveListener {
            override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {
                main.post {
                    resolving = false
                    resolveNext()
                }
            }

            override fun onServiceResolved(info: NsdServiceInfo) {
                main.post {
                    resolving = false
                    sink?.success(toMap(info))
                    resolveNext()
                }
            }
        })
    }

    private fun toMap(info: NsdServiceInfo): Map<String, Any?> {
        val hosts = if (Build.VERSION.SDK_INT >= 34) {
            info.hostAddresses
        } else {
            @Suppress("DEPRECATION")
            listOfNotNull(info.host)
        }
        return mapOf(
            "status" to "found",
            "name" to info.serviceName,
            "port" to info.port,
            "addresses" to hosts.filterIsInstance<Inet4Address>().mapNotNull { it.hostAddress },
            "txt" to info.attributes.mapValues { it.value },
        )
    }
}
