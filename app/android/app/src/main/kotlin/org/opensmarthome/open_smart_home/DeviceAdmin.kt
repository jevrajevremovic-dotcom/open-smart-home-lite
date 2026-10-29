package org.opensmarthome.open_smart_home

import android.app.Activity
import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Device-owner admin for installer-managed wall panels. It does nothing
 * until an installer makes the app the device owner on a fresh device
 * (`adb shell dpm set-device-owner <package>/.KioskAdminReceiver`, see
 * docs/INSTALLER.md); a normal install never gets these powers.
 */
class KioskAdminReceiver : DeviceAdminReceiver()

/**
 * `org.opensmarthome/device`: model and Android version for the service
 * screen; with device-owner rights, a kiosk that cannot be left (lock task),
 * the screen kept on while powered, and the app as the home screen.
 */
class DeviceAdminHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val dpm =
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val admin = ComponentName(activity, KioskAdminReceiver::class.java)
    // Class names follow the code's namespace, not a brand's application id.
    private val homeAlias = ComponentName(
        activity,
        "${KioskAdminReceiver::class.java.`package`!!.name}.HomeAlias",
    )

    private val isOwner: Boolean
        get() = dpm.isDeviceOwnerApp(activity.packageName)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "info" -> result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "android" to Build.VERSION.RELEASE,
                        "sdk" to Build.VERSION.SDK_INT,
                        "package" to activity.packageName,
                        "deviceOwner" to isOwner,
                    ),
                )
                "lockTask" -> result.success(lockTask(call.argument<Boolean>("on") == true))
                "applyPolicies" -> result.success(applyPolicies())
                "release" -> result.success(release())
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("not_owner", e.message, null)
        }
    }

    /** Pins the kiosk (no home, recents or notifications); owner only. */
    private fun lockTask(on: Boolean): Boolean {
        if (!isOwner) return false
        if (on) {
            dpm.setLockTaskPackages(admin, arrayOf(activity.packageName))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // The clock and battery stay visible; nothing can be opened.
                dpm.setLockTaskFeatures(admin, DevicePolicyManager.LOCK_TASK_FEATURE_SYSTEM_INFO)
            }
            activity.startLockTask()
        } else {
            activity.stopLockTask()
        }
        return true
    }

    /** Screen on while powered, the app as home screen (so it starts after a reboot). */
    private fun applyPolicies(): Boolean {
        if (!isOwner) return false
        dpm.setGlobalSetting(
            admin,
            Settings.Global.STAY_ON_WHILE_PLUGGED_IN,
            (android.os.BatteryManager.BATTERY_PLUGGED_AC or
                android.os.BatteryManager.BATTERY_PLUGGED_USB or
                android.os.BatteryManager.BATTERY_PLUGGED_WIRELESS).toString(),
        )
        activity.packageManager.setComponentEnabledSetting(
            homeAlias,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        val home = IntentFilter(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addCategory(Intent.CATEGORY_DEFAULT)
        }
        dpm.addPersistentPreferredActivity(admin, home, homeAlias)
        return true
    }

    /** Hands the device back: normal home screen, no lock, no owner. */
    private fun release(): Boolean {
        if (!isOwner) return false
        try {
            activity.stopLockTask()
        } catch (_: IllegalStateException) {
            // Was not locked.
        }
        dpm.clearPackagePersistentPreferredActivities(admin, activity.packageName)
        dpm.setLockTaskPackages(admin, emptyArray())
        activity.packageManager.setComponentEnabledSetting(
            homeAlias,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
        @Suppress("DEPRECATION")
        dpm.clearDeviceOwnerApp(activity.packageName)
        return true
    }
}
