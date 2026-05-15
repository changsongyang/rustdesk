package com.carriez.flutter_hbb

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * 权限管理工具类
 * 实现动态权限申请机制和权限说明引导
 */
class PermissionManager(private val activity: Activity) {

    companion object {
        private const val TAG = "PermissionManager"

        const val REQUEST_CODE_CORE_PERMISSIONS = 1001
        const val REQUEST_CODE_AUDIO_PERMISSION = 1002
        const val REQUEST_CODE_STORAGE_PERMISSION = 1003
        const val REQUEST_CODE_OVERLAY_PERMISSION = 1004
        const val REQUEST_CODE_BATTERY_OPTIMIZATION = 1005
        const val REQUEST_CODE_MANAGE_STORAGE = 1006
    }

    data class PermissionGroup(
        val permissions: Array<String>,
        val title: String,
        val description: String,
        val required: Boolean
    )

    private val permissionGroups = mapOf(
        "audio" to PermissionGroup(
            permissions = arrayOf(Manifest.permission.RECORD_AUDIO),
            title = "录音权限",
            description = "用于远程会话中的音频传输，让您可以听到远程设备的声音",
            required = true
        ),
        "storage" to PermissionGroup(
            permissions = getStoragePermissions(),
            title = "存储权限",
            description = "用于文件传输功能，允许您在远程设备之间传输文件",
            required = false
        ),
        "overlay" to PermissionGroup(
            permissions = arrayOf(Manifest.permission.SYSTEM_ALERT_WINDOW),
            title = "悬浮窗权限",
            description = "用于显示远程会话控制窗口，方便您快速操作",
            required = false
        ),
        "battery" to PermissionGroup(
            permissions = arrayOf(Manifest.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS),
            title = "电池优化权限",
            description = "用于防止应用被系统电池优化限制，确保后台正常运行",
            required = false
        )
    )

    private fun getStoragePermissions(): Array<String> {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                arrayOf(
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO,
                    Manifest.permission.READ_MEDIA_AUDIO
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            else -> {
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                )
            }
        }
    }

    fun checkPermission(groupKey: String): Boolean {
        val group = permissionGroups[groupKey] ?: return false
        return group.permissions.all { permission ->
            checkSinglePermission(permission)
        }
    }

    private fun checkSinglePermission(permission: String): Boolean {
        return when (permission) {
            Manifest.permission.SYSTEM_ALERT_WINDOW -> {
                Settings.canDrawOverlays(activity)
            }
            Manifest.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS -> {
                val powerManager = activity.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                powerManager.isIgnoringBatteryOptimizations(activity.packageName)
            }
            Manifest.permission.MANAGE_EXTERNAL_STORAGE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Environment.isExternalStorageManager()
                } else {
                    true
                }
            }
            else -> {
                ContextCompat.checkSelfPermission(activity, permission) ==
                    PackageManager.PERMISSION_GRANTED
            }
        }
    }

    fun requestPermission(groupKey: String, callback: ((Boolean) -> Unit)? = null) {
        val group = permissionGroups[groupKey] ?: return

        if (checkPermission(groupKey)) {
            callback?.invoke(true)
            return
        }

        showPermissionRationaleDialog(group) {
            requestPermissionInternal(group, callback)
        }
    }

    private fun showPermissionRationaleDialog(
        group: PermissionGroup,
        onConfirm: () -> Unit
    ) {
        AlertDialog.Builder(activity)
            .setTitle(group.title)
            .setMessage(group.description)
            .setPositiveButton("授权") { dialog, _ ->
                dialog.dismiss()
                onConfirm()
            }
            .setNegativeButton("取消") { dialog, _ ->
                dialog.dismiss()
            }
            .setCancelable(false)
            .show()
    }

    private fun requestPermissionInternal(group: PermissionGroup, callback: ((Boolean) -> Unit)?) {
        when {
            group.permissions.contains(Manifest.permission.SYSTEM_ALERT_WINDOW) -> {
                requestOverlayPermission(callback)
            }
            group.permissions.contains(Manifest.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS) -> {
                requestBatteryOptimizationPermission(callback)
            }
            group.permissions.contains(Manifest.permission.MANAGE_EXTERNAL_STORAGE) -> {
                requestManageStoragePermission(callback)
            }
            else -> {
                ActivityCompat.requestPermissions(
                    activity,
                    group.permissions,
                    REQUEST_CODE_CORE_PERMISSIONS
                )
            }
        }
    }

    private fun requestOverlayPermission(callback: ((Boolean) -> Unit)?) {
        if (Settings.canDrawOverlays(activity)) {
            callback?.invoke(true)
            return
        }

        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${activity.packageName}")
        )
        activity.startActivityForResult(intent, REQUEST_CODE_OVERLAY_PERMISSION)
    }

    @SuppressLint("BatteryLife")
    private fun requestBatteryOptimizationPermission(callback: ((Boolean) -> Unit)?) {
        val powerManager = activity.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        if (powerManager.isIgnoringBatteryOptimizations(activity.packageName)) {
            callback?.invoke(true)
            return
        }

        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${activity.packageName}")
        }
        activity.startActivityForResult(intent, REQUEST_CODE_BATTERY_OPTIMIZATION)
    }

    private fun requestManageStoragePermission(callback: ((Boolean) -> Unit)?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) {
                callback?.invoke(true)
                return
            }

            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
            activity.startActivityForResult(intent, REQUEST_CODE_MANAGE_STORAGE)
        } else {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ),
                REQUEST_CODE_STORAGE_PERMISSION
            )
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
        callback: ((Boolean) -> Unit)?
    ) {
        when (requestCode) {
            REQUEST_CODE_CORE_PERMISSIONS,
            REQUEST_CODE_AUDIO_PERMISSION,
            REQUEST_CODE_STORAGE_PERMISSION -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                callback?.invoke(allGranted)

                if (!allGranted) {
                    Log.w(TAG, "部分权限被拒绝: ${permissions.joinToString()}")
                }
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, callback: ((Boolean) -> Unit)?) {
        when (requestCode) {
            REQUEST_CODE_OVERLAY_PERMISSION -> {
                val granted = Settings.canDrawOverlays(activity)
                callback?.invoke(granted)

                if (!granted) {
                    Log.w(TAG, "悬浮窗权限被拒绝")
                }
            }
            REQUEST_CODE_BATTERY_OPTIMIZATION -> {
                val powerManager = activity.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                val granted = powerManager.isIgnoringBatteryOptimizations(activity.packageName)
                callback?.invoke(granted)

                if (!granted) {
                    Log.w(TAG, "电池优化权限被拒绝")
                }
            }
            REQUEST_CODE_MANAGE_STORAGE -> {
                val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Environment.isExternalStorageManager()
                } else {
                    true
                }
                callback?.invoke(granted)

                if (!granted) {
                    Log.w(TAG, "文件管理权限被拒绝")
                }
            }
        }
    }

    fun requestCorePermissions(callback: ((Boolean) -> Unit)? = null) {
        val corePermissions = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            corePermissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (corePermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                activity,
                corePermissions.toTypedArray(),
                REQUEST_CODE_CORE_PERMISSIONS
            )
        } else {
            callback?.invoke(true)
        }
    }

    fun checkAllRequiredPermissions(): Boolean {
        return permissionGroups.filter { it.value.required }.all { (key, _) ->
            checkPermission(key)
        }
    }

    fun getMissingPermissions(): List<String> {
        return permissionGroups.filter { !checkPermission(it.key) }.keys.toList()
    }

    fun shouldShowRequestPermissionRationale(permission: String): Boolean {
        return ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
    }

    fun isBootReceiverEnabled(): Boolean {
        return try {
            val packageManager = activity.packageManager
            val componentName = android.content.ComponentName(activity, BootReceiver::class.java)
            packageManager.getComponentEnabledSetting(componentName) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } catch (e: Exception) {
            Log.e(TAG, "检查BootReceiver状态失败: ${e.message}")
            false
        }
    }

    fun enableBootReceiver(enable: Boolean) {
        try {
            val packageManager = activity.packageManager
            val componentName = android.content.ComponentName(activity, BootReceiver::class.java)

            val newState = if (enable) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }

            packageManager.setComponentEnabledSetting(
                componentName,
                newState,
                PackageManager.DONT_KILL_APP
            )

            Log.i(TAG, "BootReceiver已${if (enable) "启用" else "禁用"}")
        } catch (e: Exception) {
            Log.e(TAG, "设置BootReceiver状态失败: ${e.message}")
        }
    }

    fun getStoragePermissionGroup(): String {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> "manageAllFiles"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> "mediaOnly"
            else -> "legacy"
        }
    }
}