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
 * type (or a list of them) starts a search; each resolved service is sent
 * as a map (`status`, `type`, `name`, `port`, `addresses`, `txt`), a lost
 * one as `status: lost` with its type and name. Cancelling stops it.
 */
class NsdDiscoveryHandler(context: Context) : EventChannel.StreamHandler {
    private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val main = Handler(Looper.getMainLooper())
    private val listeners = mutableListOf<NsdManager.DiscoveryListener>()
    private var sink: EventChannel.EventSink? = null

    // Older Android resolves one service at a time.
    private val queue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val types = when (arguments) {
            is String -> listOf(arguments)
            is List<*> -> arguments.filterIsInstance<String>()
            else -> emptyList()
        }
        if (types.isEmpty()) {
            events.error("bad_args", "service type expected", null)
            return
        }
        stop()
        sink = events
        for (type in types) {
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
                        sink?.success(
                            mapOf(
                                "status" to "lost",
                                "type" to type,
                                "name" to info.serviceName,
                            ),
                        )
                    }
                }
            }
            try {
                nsd.discoverServices(type, NsdManager.PROTOCOL_DNS_SD, l)
                listeners.add(l)
            } catch (e: RuntimeException) {
                events.error("start_failed", e.javaClass.simpleName, null)
            }
        }
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        for (l in listeners) {
            try {
                nsd.stopServiceDiscovery(l)
            } catch (_: RuntimeException) {
                // Already stopped or never started.
            }
        }
        listeners.clear()
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
            "type" to info.serviceType.trim('.').removeSuffix(".local"),
            "name" to info.serviceName,
            "port" to info.port,
            "addresses" to hosts.filterIsInstance<Inet4Address>().mapNotNull { it.hostAddress },
            "txt" to info.attributes.mapValues { it.value },
        )
    }
}
