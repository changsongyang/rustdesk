package com.carriez.flutter_hbb

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * 安全审计工具
 * 检查应用安全性，识别潜在的安全风险
 */
class SecurityAuditor(private val context: Context) {
    
    companion object {
        private const val TAG = "SecurityAuditor"

        private val HIGH_RISK_PERMISSIONS = mapOf(
            "android.permission.MANAGE_EXTERNAL_STORAGE" to R.string.permission_manage_external_storage,
            "android.permission.SYSTEM_ALERT_WINDOW" to R.string.permission_system_alert_window,
            "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" to R.string.permission_battery_optimization,
            "android.permission.READ_CONTACTS" to R.string.permission_read_contacts,
            "android.permission.READ_SMS" to R.string.permission_read_sms,
            "android.permission.CALL_PHONE" to R.string.permission_call_phone,
            "android.permission.READ_CALL_LOG" to R.string.permission_read_call_log
        )
    }
    
    data class SecurityAuditResult(
        val isSecure: Boolean,
        val issues: List<SecurityIssue>,
        val timestamp: Long = System.currentTimeMillis()
    )
    
    data class SecurityIssue(
        val type: SecurityIssueType,
        val description: String,
        val severity: Severity,
        val recommendation: String
    )
    
    enum class SecurityIssueType {
        HIGH_RISK_PERMISSION,
        NETWORK_SECURITY,
        INSECURE_DATA_STORAGE,
        DEBUG_MODE,
        CODE_OBFUSCATION,
        OUTDATED_SDK,
        INSECURE_COMMUNICATION
    }
    
    enum class Severity {
        LOW,
        MEDIUM,
        HIGH,
        CRITICAL
    }
    
    fun performSecurityAudit(): SecurityAuditResult {
        Log.i(TAG, context.getString(R.string.security_audit_started))

        val issues = mutableListOf<SecurityIssue>()

        checkPermissionUsage(issues)
        checkNetworkSecurity(issues)
        checkDataStorage(issues)
        checkCodeObfuscation(issues)
        checkSdkVersion(issues)

        val isSecure = issues.none { it.severity == Severity.HIGH || it.severity == Severity.CRITICAL }

        Log.i(TAG, context.getString(R.string.security_audit_completed, issues.size))

        return SecurityAuditResult(
            isSecure = isSecure,
            issues = issues
        )
    }
    
    private fun checkPermissionUsage(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, context.getString(R.string.checking_permissions))

        try {
            val packageInfo = context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_PERMISSIONS
            )

            val requestedPermissions = packageInfo.requestedPermissions ?: arrayOf()

            for (permission in requestedPermissions) {
                if (permission in HIGH_RISK_PERMISSIONS) {
                    val permName = context.getString(HIGH_RISK_PERMISSIONS[permission]!!)
                    issues.add(SecurityIssue(
                        type = SecurityIssueType.HIGH_RISK_PERMISSION,
                        description = context.getString(R.string.issue_high_risk_permission, permName),
                        severity = Severity.HIGH,
                        recommendation = context.getString(R.string.recommend_review_permission)
                    ))
                }
            }

            Log.d(TAG, context.getString(R.string.permissions_check_completed, requestedPermissions.size))

        } catch (e: Exception) {
            Log.e(TAG, context.getString(R.string.security_audit_failed, e.message))
        }
    }
    
    private fun checkNetworkSecurity(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, context.getString(R.string.checking_network_security))

        try {
            val networkSecurityConfigId = context.resources.getIdentifier(
                "network_security_config",
                "xml",
                context.packageName
            )

            if (networkSecurityConfigId == 0) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.NETWORK_SECURITY,
                    description = context.getString(R.string.issue_missing_network_security),
                    severity = Severity.MEDIUM,
                    recommendation = context.getString(R.string.recommend_add_network_config)
                ))
            } else {
                Log.d(TAG, "Network security config exists")
            }

            val applicationInfo = context.applicationInfo
            val usesCleartextTraffic = applicationInfo.flags and ApplicationInfo.FLAG_USES_CLEARTEXT_TRAFFIC != 0

            if (usesCleartextTraffic) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.INSECURE_COMMUNICATION,
                    description = context.getString(R.string.issue_cleartext_traffic),
                    severity = Severity.HIGH,
                    recommendation = context.getString(R.string.recommend_disable_cleartext)
                ))
            }

        } catch (e: Exception) {
            Log.e(TAG, context.getString(R.string.security_audit_failed, e.message))
        }
    }

    private fun checkDataStorage(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, context.getString(R.string.checking_data_storage))

        try {
            val prefsDir = File(context.filesDir.parent, "shared_prefs")
            if (prefsDir.exists() && prefsDir.isDirectory) {
                val prefsFiles = prefsDir.listFiles()
                prefsFiles?.forEach { file ->
                    if (file.name.endsWith(".xml")) {
                        val content = file.readText()
                        if (containsSensitiveData(content)) {
                            issues.add(SecurityIssue(
                                type = SecurityIssueType.INSECURE_DATA_STORAGE,
                                description = context.getString(R.string.issue_sensitive_data_storage, file.name),
                                severity = Severity.MEDIUM,
                                recommendation = context.getString(R.string.recommend_use_keystore)
                            ))
                        }
                    }
                }
            }

            val filesDir = context.filesDir
            if (filesDir.exists() && filesDir.isDirectory) {
                val files = filesDir.listFiles()
                files?.forEach { file ->
                    if (file.isFile && file.name.contains("password", ignoreCase = true)) {
                        issues.add(SecurityIssue(
                            type = SecurityIssueType.INSECURE_DATA_STORAGE,
                            description = context.getString(R.string.issue_password_file, file.name),
                            severity = Severity.HIGH,
                            recommendation = context.getString(R.string.recommend_use_keystore)
                        ))
                    }
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, context.getString(R.string.security_audit_failed, e.message))
        }
    }

    private fun containsSensitiveData(content: String): Boolean {
        val sensitiveKeywords = listOf("password", "token", "secret", "key", "auth", "credential")
        return sensitiveKeywords.any { keyword ->
            content.contains(keyword, ignoreCase = true)
        }
    }

    private fun checkCodeObfuscation(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, context.getString(R.string.checking_code_obfuscation))

        try {
            val isDebuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

            if (isDebuggable) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.DEBUG_MODE,
                    description = context.getString(R.string.issue_debug_mode),
                    severity = Severity.HIGH,
                    recommendation = context.getString(R.string.recommend_disable_debug)
                ))
            }

        } catch (e: Exception) {
            Log.e(TAG, context.getString(R.string.security_audit_failed, e.message))
        }
    }



    private fun checkSdkVersion(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, context.getString(R.string.checking_sdk_version))

        try {
            val targetSdkVersion = context.applicationInfo.targetSdkVersion

            if (targetSdkVersion < 30) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.OUTDATED_SDK,
                    description = context.getString(R.string.issue_outdated_sdk, targetSdkVersion),
                    severity = Severity.MEDIUM,
                    recommendation = context.getString(R.string.recommend_update_sdk)
                ))
            }

            if (Build.VERSION.SDK_INT < 30) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.OUTDATED_SDK,
                    description = context.getString(R.string.issue_old_compile_sdk, Build.VERSION.SDK_INT),
                    severity = Severity.LOW,
                    recommendation = context.getString(R.string.recommend_update_sdk)
                ))
            }

        } catch (e: Exception) {
            Log.e(TAG, context.getString(R.string.security_audit_failed, e.message))
        }
    }
    
    fun generateSecurityReport(): String {
        val result = performSecurityAudit()
        
        val report = JSONObject().apply {
            put("isSecure", result.isSecure)
            put("timestamp", result.timestamp)
            put("packageName", context.packageName)
            
            val issuesArray = org.json.JSONArray()
            result.issues.forEach { issue ->
                issuesArray.put(JSONObject().apply {
                    put("type", issue.type.name)
                    put("description", issue.description)
                    put("severity", issue.severity.name)
                    put("recommendation", issue.recommendation)
                })
            }
            put("issues", issuesArray)
        }
        
        return report.toString(2)
    }
}
