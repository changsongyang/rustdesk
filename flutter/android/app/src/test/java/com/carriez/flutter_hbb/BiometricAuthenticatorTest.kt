package com.carriez.flutter_hbb

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 生物识别组件单元测试
 */
@RunWith(AndroidJUnit4::class)
class BiometricAuthenticatorTest {
    
    private lateinit var context: Context
    private lateinit var biometricAuthenticator: BiometricAuthenticator
    
    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        biometricAuthenticator = BiometricAuthenticator(context)
    }
    
    @Test
    fun testCanAuthenticate() {
        val result = biometricAuthenticator.canAuthenticate()
        
        assertNotNull("Biometric type should not be null", result)
        // 结果应该是有效的枚举值
        assertTrue("Result should be a valid BiometricType", 
            listOf(
                BiometricAuthenticator.BiometricType.NONE,
                BiometricAuthenticator.BiometricType.FINGERPRINT,
                BiometricAuthenticator.BiometricType.FACE,
                BiometricAuthenticator.BiometricType.IRIS,
                BiometricAuthenticator.BiometricType.STRONG,
                BiometricAuthenticator.BiometricType.WEAK
            ).contains(result))
    }
    
    @Test
    fun testHasFingerprint() {
        val result = biometricAuthenticator.hasFingerprint()
        
        assertTrue("hasFingerprint should return boolean", result is Boolean)
    }
    
    @Test
    fun testHasFaceRecognition() {
        val result = biometricAuthenticator.hasFaceRecognition()
        
        assertTrue("hasFaceRecognition should return boolean", result is Boolean)
    }
    
    @Test
    fun testGetSupportedBiometricTypes() {
        val types = biometricAuthenticator.getSupportedBiometricTypes()
        
        assertNotNull("Supported types should not be null", types)
        assertTrue("Supported types should be a list", types is List<*>)
    }
    
    @Test
    fun testIsBiometricEnabled() {
        val result = biometricAuthenticator.isBiometricEnabled()
        
        assertTrue("isBiometricEnabled should return boolean", result is Boolean)
    }
    
    @Test
    fun testGetErrorMessage() {
        // 测试几种常见错误代码
        val errorMessages = listOf(
            Pair(BiometricPrompt.ERROR_CANCELED, "认证已取消"),
            Pair(BiometricPrompt.ERROR_LOCKOUT, "生物识别被锁定，请稍后再试"),
            Pair(BiometricPrompt.ERROR_NEGATIVE_BUTTON, "用户取消了认证")
        )
        
        errorMessages.forEach { (code, expectedMessage) ->
            val message = biometricAuthenticator.getErrorMessage(code)
            assertEquals("Error message for code $code should match", 
                expectedMessage, message)
        }
    }
    
    @Test
    fun testGetErrorMessageForUnknownCode() {
        val message = biometricAuthenticator.getErrorMessage(999)
        
        assertNotNull("Error message should not be null", message)
        assertTrue("Error message should not be empty", message.isNotEmpty())
    }
}
