package com.carriez.flutter_hbb

import android.app.Activity
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.util.concurrent.Executor

/**
 * 生物识别认证管理器
 * 支持指纹和面部识别
 */
class BiometricAuthenticator(private val context: Context) {

    companion object {
        private const val TAG = "BiometricAuthenticator"
    }

    /**
     * 生物识别类型枚举
     */
    enum class BiometricType {
        NONE,
        FINGERPRINT,
        FACE,
        IRIS,
        STRONG,
        WEAK
    }

    /**
     * 认证结果回调
     */
    interface AuthCallback {
        fun onSuccess()
        fun onError(errorCode: Int, errorMessage: String)
        fun onFailed()
    }

    /**
     * 检查生物识别是否可用
     */
    fun canAuthenticate(): BiometricType {
        return try {
            val biometricManager = BiometricManager.from(context)
            
            when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
                BiometricManager.BIOMETRIC_SUCCESS -> {
                    Log.i(TAG, "Strong biometric authentication available")
                    BiometricType.STRONG
                }
                BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> {
                    Log.w(TAG, "No biometric hardware available")
                    BiometricType.NONE
                }
                BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> {
                    Log.w(TAG, "Biometric hardware unavailable")
                    BiometricType.NONE
                }
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
                    Log.w(TAG, "No biometric enrolled")
                    BiometricType.NONE
                }
                else -> {
                    Log.w(TAG, "Unknown biometric status")
                    BiometricType.NONE
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking biometric availability: ${e.message}")
            BiometricType.NONE
        }
    }

    /**
     * 检查是否有指纹识别
     */
    fun hasFingerprint(): Boolean {
        return try {
            val biometricManager = BiometricManager.from(context)
            biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK) == BiometricManager.BIOMETRIC_SUCCESS
        } catch (e: Exception) {
            Log.e(TAG, "Error checking fingerprint availability: ${e.message}")
            false
        }
    }

    /**
     * 检查是否有面部识别
     */
    fun hasFaceRecognition(): Boolean {
        // Android 10+ 支持面部识别
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val biometricManager = BiometricManager.from(context)
                biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
            } catch (e: Exception) {
                Log.e(TAG, "Error checking face recognition availability: ${e.message}")
                false
            }
        } else {
            false
        }
    }

    /**
     * 执行生物识别认证
     */
    fun authenticate(
        activity: Activity,
        title: String = "生物识别认证",
        subtitle: String = "验证您的身份",
        negativeButtonText: String = "取消",
        callback: AuthCallback
    ) {
        val executor: Executor = ContextCompat.getMainExecutor(context)

        val biometricPrompt = if (activity is FragmentActivity) {
            BiometricPrompt(activity, executor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    Log.i(TAG, "Biometric authentication succeeded")
                    callback.onSuccess()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Log.e(TAG, "Biometric authentication error: $errorCode - $errString")
                    callback.onError(errorCode, errString.toString())
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Log.w(TAG, "Biometric authentication failed")
                    callback.onFailed()
                }
            })
        } else {
            Log.e(TAG, "Activity is not a FragmentActivity, biometric authentication not supported")
            callback.onError(-1, "Biometric authentication not supported")
            return
        }

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setNegativeButtonText(negativeButtonText)
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setConfirmationRequired(false)
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    /**
     * 异步执行生物识别认证
     */
    fun authenticateAsync(
        activity: Activity,
        title: String = "生物识别认证",
        subtitle: String = "验证您的身份",
        negativeButtonText: String = "取消"
    ): BiometricAuthResult {
        var result = BiometricAuthResult(false, null, null)
        
        authenticate(activity, title, subtitle, negativeButtonText, object : AuthCallback {
            override fun onSuccess() {
                result = BiometricAuthResult(true, null, null)
            }

            override fun onError(errorCode: Int, errorMessage: String) {
                result = BiometricAuthResult(false, errorCode, errorMessage)
            }

            override fun onFailed() {
                result = BiometricAuthResult(false, -1, "Authentication failed")
            }
        })
        
        return result
    }

    /**
     * 生物识别认证结果数据类
     */
    data class BiometricAuthResult(
        val isSuccess: Boolean,
        val errorCode: Int?,
        val errorMessage: String?
    )

    /**
     * 获取设备支持的生物识别类型列表
     */
    fun getSupportedBiometricTypes(): List<BiometricType> {
        val types = mutableListOf<BiometricType>()
        
        if (hasFingerprint()) {
            types.add(BiometricType.FINGERPRINT)
        }
        
        if (hasFaceRecognition()) {
            types.add(BiometricType.FACE)
        }
        
        when (canAuthenticate()) {
            BiometricType.STRONG -> {
                if (!types.contains(BiometricType.STRONG)) {
                    types.add(BiometricType.STRONG)
                }
            }
            BiometricType.WEAK -> {
                if (!types.contains(BiometricType.WEAK)) {
                    types.add(BiometricType.WEAK)
                }
            }
            else -> {}
        }
        
        return types
    }

    /**
     * 检查生物识别是否已启用
     */
    fun isBiometricEnabled(): Boolean {
        return canAuthenticate() != BiometricType.NONE
    }

    /**
     * 获取错误代码对应的友好消息
     */
    fun getErrorMessage(errorCode: Int): String {
        return when (errorCode) {
            BiometricPrompt.ERROR_CANCELED -> "认证已取消"
            BiometricPrompt.ERROR_LOCKOUT -> "生物识别被锁定，请稍后再试"
            BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "生物识别被永久锁定，请使用备用方式验证"
            BiometricPrompt.ERROR_NEGATIVE_BUTTON -> "用户取消了认证"
            BiometricPrompt.ERROR_NO_BIOMETRICS -> "设备未设置生物识别"
            BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "设备未设置密码或指纹"
            BiometricPrompt.ERROR_TIMEOUT -> "认证超时"
            BiometricPrompt.ERROR_USER_CANCELED -> "用户取消了认证"
            BiometricPrompt.ERROR_VENDOR -> "供应商特定认证错误"
            else -> "认证失败，请重试"
        }
    }
}
