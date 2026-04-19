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
            "android.permission.MANAGE_EXTERNAL_STORAGE" to "存储管理权限",
            "android.permission.SYSTEM_ALERT_WINDOW" to "悬浮窗权限",
            "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" to "电池优化权限",
            "android.permission.READ_CONTACTS" to "读取联系人权限",
            "android.permission.READ_SMS" to "读取短信权限",
            "android.permission.CALL_PHONE" to "拨打电话权限",
            "android.permission.READ_CALL_LOG" to "读取通话记录权限"
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
        Log.i(TAG, "开始安全审计...")
        
        val issues = mutableListOf<SecurityIssue>()
        
        // 检查权限使用
        checkPermissionUsage(issues)
        
        // 检查网络通信
        checkNetworkSecurity(issues)
        
        // 检查数据存储
        checkDataStorage(issues)
        
        // 检查代码混淆
        checkCodeObfuscation(issues)
        
        // 检查SDK版本
        checkSdkVersion(issues)
        
        val isSecure = issues.none { it.severity == Severity.HIGH || it.severity == Severity.CRITICAL }
        
        Log.i(TAG, "安全审计完成，发现 ${issues.size} 个问题")
        
        return SecurityAuditResult(
            isSecure = isSecure,
            issues = issues
        )
    }
    
    private fun checkPermissionUsage(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, "检查权限使用...")
        
        try {
            val packageInfo = context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_PERMISSIONS
            )
            
            val requestedPermissions = packageInfo.requestedPermissions ?: arrayOf()
            
            // 检查是否申请了高风险权限
            for (permission in requestedPermissions) {
                if (permission in HIGH_RISK_PERMISSIONS) {
                    issues.add(SecurityIssue(
                        type = SecurityIssueType.HIGH_RISK_PERMISSION,
                        description = "使用了高风险权限: ${HIGH_RISK_PERMISSIONS[permission]}",
                        severity = Severity.HIGH,
                        recommendation = "评估是否真的需要此权限，考虑使用替代方案或按需申请"
                    ))
                }
            }
            
            Log.d(TAG, "权限检查完成，发现 ${requestedPermissions.size} 个权限")
            
        } catch (e: Exception) {
            Log.e(TAG, "权限检查失败: ${e.message}")
        }
    }
    
    private fun checkNetworkSecurity(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, "检查网络通信安全...")
        
        try {
            // 检查网络安全配置
            val networkSecurityConfigId = context.resources.getIdentifier(
                "network_security_config",
                "xml",
                context.packageName
            )
            
            if (networkSecurityConfigId == 0) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.NETWORK_SECURITY,
                    description = "缺少网络安全配置",
                    severity = Severity.MEDIUM,
                    recommendation = "添加network_security_config.xml文件，强制使用HTTPS"
                ))
            } else {
                Log.d(TAG, "网络安全配置已存在")
            }
            
            // 检查是否允许明文传输
            val applicationInfo = context.applicationInfo
            val usesCleartextTraffic = applicationInfo.flags and ApplicationInfo.FLAG_USES_CLEARTEXT_TRAFFIC != 0
            
            if (usesCleartextTraffic) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.INSECURE_COMMUNICATION,
                    description = "应用允许明文HTTP传输",
                    severity = Severity.HIGH,
                    recommendation = "禁用明文传输，强制使用HTTPS"
                ))
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "网络通信检查失败: ${e.message}")
        }
    }
    
    private fun checkDataStorage(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, "检查数据存储安全...")
        
        try {
            // 检查SharedPreferences
            val prefsDir = File(context.filesDir.parent, "shared_prefs")
            if (prefsDir.exists() && prefsDir.isDirectory) {
                val prefsFiles = prefsDir.listFiles()
                prefsFiles?.forEach { file ->
                    if (file.name.endsWith(".xml")) {
                        val content = file.readText()
                        if (containsSensitiveData(content)) {
                            issues.add(SecurityIssue(
                                type = SecurityIssueType.INSECURE_DATA_STORAGE,
                                description = "检测到SharedPreferences中可能存储敏感数据: ${file.name}",
                                severity = Severity.MEDIUM,
                                recommendation = "使用Android Keystore加密存储敏感数据"
                            ))
                        }
                    }
                }
            }
            
            // 检查内部存储
            val filesDir = context.filesDir
            if (filesDir.exists() && filesDir.isDirectory) {
                val files = filesDir.listFiles()
                files?.forEach { file ->
                    if (file.isFile && file.name.contains("password", ignoreCase = true)) {
                        issues.add(SecurityIssue(
                            type = SecurityIssueType.INSECURE_DATA_STORAGE,
                            description = "检测到可能存储密码的文件: ${file.name}",
                            severity = Severity.HIGH,
                            recommendation = "使用Android Keystore加密存储密码"
                        ))
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "数据存储检查失败: ${e.message}")
        }
    }
    
    private fun containsSensitiveData(content: String): Boolean {
        val sensitiveKeywords = listOf("password", "token", "secret", "key", "auth", "credential")
        return sensitiveKeywords.any { keyword -> 
            content.contains(keyword, ignoreCase = true) 
        }
    }
    
    private fun checkCodeObfuscation(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, "检查代码混淆...")
        
        try {
            // 检查是否启用了代码混淆
            val isDebuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
            
            if (isDebuggable) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.DEBUG_MODE,
                    description = "应用处于调试模式",
                    severity = Severity.HIGH,
                    recommendation = "发布版本应禁用调试模式"
                ))
            }
            
            // 注意：代码混淆检查需要通过构建配置或反编译分析
            // 此处仅检查调试模式，实际的混淆状态需要通过其他方式验证
            
        } catch (e: Exception) {
            Log.e(TAG, "代码混淆检查失败: ${e.message}")
        }
    }
    

    
    private fun checkSdkVersion(issues: MutableList<SecurityIssue>) {
        Log.d(TAG, "检查SDK版本...")
        
        try {
            val targetSdkVersion = context.applicationInfo.targetSdkVersion
            
            // 检查目标SDK版本是否过旧
            if (targetSdkVersion < 30) { // Android 11
                issues.add(SecurityIssue(
                    type = SecurityIssueType.OUTDATED_SDK,
                    description = "目标SDK版本过旧: $targetSdkVersion",
                    severity = Severity.MEDIUM,
                    recommendation = "更新目标SDK版本到最新稳定版本"
                ))
            }
            
            // 检查编译SDK版本
            if (Build.VERSION.SDK_INT < 30) {
                issues.add(SecurityIssue(
                    type = SecurityIssueType.OUTDATED_SDK,
                    description = "编译SDK版本过旧: ${Build.VERSION.SDK_INT}",
                    severity = Severity.LOW,
                    recommendation = "更新编译SDK版本到最新稳定版本"
                ))
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "SDK版本检查失败: ${e.message}")
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
