package com.carriez.flutter_hbb

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 安全加密组件单元测试
 */
@RunWith(AndroidJUnit4::class)
class SecurityEncryptionTest {
    
    private lateinit var context: Context
    private lateinit var encryption: SecurityEncryption
    
    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        encryption = SecurityEncryption(context)
    }
    
    @Test
    fun testEncryptDecrypt() {
        val original = "test sensitive data 12345"
        val encrypted = encryption.encrypt(original)
        val decrypted = encryption.decrypt(encrypted)
        
        assertNotNull("Encrypted should not be null", encrypted)
        assertNotNull("Decrypted should not be null", decrypted)
        assertEquals("Decrypted should equal original", original, decrypted)
    }
    
    @Test
    fun testEncryptEmptyString() {
        val original = ""
        val encrypted = encryption.encrypt(original)
        val decrypted = encryption.decrypt(encrypted)
        
        assertEquals("Empty string should remain empty", "", decrypted)
    }
    
    @Test
    fun testEncryptSpecialCharacters() {
        val original = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        val encrypted = encryption.encrypt(original)
        val decrypted = encryption.decrypt(encrypted)
        
        assertEquals("Special characters should be preserved", original, decrypted)
    }
    
    @Test
    fun testEncryptLongString() {
        val original = "A".repeat(1000)
        val encrypted = encryption.encrypt(original)
        val decrypted = encryption.decrypt(encrypted)
        
        assertEquals("Long string should be encrypted and decrypted correctly", original, decrypted)
    }
    
    @Test
    fun testEncryptDecryptDifferent() {
        val data1 = "data1"
        val data2 = "data2"
        
        val encrypted1 = encryption.encrypt(data1)
        val encrypted2 = encryption.encrypt(data2)
        
        assertNotEquals("Different data should produce different encrypted results", encrypted1, encrypted2)
        
        val decrypted1 = encryption.decrypt(encrypted1)
        val decrypted2 = encryption.decrypt(encrypted2)
        
        assertEquals(data1, decrypted1)
        assertEquals(data2, decrypted2)
    }
    
    @Test
    fun testEncryptedSharedPreferences() {
        val prefs = encryption.getEncryptedSharedPreferences("test_prefs")
        val key = "test_key"
        val value = "test_value"
        
        // 写入
        prefs.edit().putString(key, value).apply()
        
        // 读取
        val retrieved = prefs.getString(key, null)
        
        assertEquals("Value should be retrieved correctly", value, retrieved)
    }
    
    @Test(expected = Exception::class)
    fun testDecryptInvalidData() {
        encryption.decrypt("invalid encrypted data")
    }
}
