package com.carriez.flutter_hbb

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.nio.charset.Charset
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * 安全加密相关异常
 */
sealed class SecurityException(message: String, cause: Throwable? = null) : java.lang.SecurityException(message, cause) {
    class InitializationException(message: String, cause: Throwable? = null) : SecurityException(message, cause)
    class KeyGenerationException(message: String, cause: Throwable? = null) : SecurityException(message, cause)
    class EncryptionException(message: String, cause: Throwable? = null) : SecurityException(message, cause)
    class DecryptionException(message: String, cause: Throwable? = null) : SecurityException(message, cause)
    class InvalidDataException(message: String, cause: Throwable? = null) : SecurityException(message, cause)
}

/**
 * 安全加密工具类
 * 实现 AES-256 加密和 Android Keystore 集成
 */
class SecurityEncryption(private val context: Context) {

    companion object {
        private const val TAG = "SecurityEncryption"
        private const val KEYSTORE_ALIAS = "rustdesk_encryption_key"
        private const val AES_GCM_IV_LENGTH = 12
        private const val AES_GCM_TAG_LENGTH = 128
        
        // 最大重试次数
        private const val MAX_RETRY_COUNT = 3
    }

    private val keyStore: KeyStore by lazy {
        try {
            KeyStore.getInstance("AndroidKeyStore").apply {
                load(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize KeyStore: ${e.message}", e)
            throw SecurityException.InitializationException("KeyStore initialization failed", e)
        }
    }

    private val secureRandom: SecureRandom by lazy {
        SecureRandom()
    }

    /**
     * 获取或创建加密的 SharedPreferences
     * 
     * @param name SharedPreferences 名称
     * @return 加密的 SharedPreferences 实例
     * @throws SecurityException.InitializationException 初始化失败
     * @throws SecurityException.KeyGenerationException 密钥生成失败
     */
    fun getEncryptedSharedPreferences(name: String): SharedPreferences {
        require(name.isNotEmpty()) { "SharedPreferences name cannot be empty" }
        
        return retryWithBackoff(MAX_RETRY_COUNT) { attempt ->
            try {
                Log.d(TAG, "Creating encrypted SharedPreferences: $name (attempt $attempt)")
                
                val masterKey = MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()

                val prefs = EncryptedSharedPreferences.create(
                    context,
                    name,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                )
                
                Log.i(TAG, "Encrypted SharedPreferences created successfully: $name")
                prefs
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create encrypted SharedPreferences (attempt $attempt): ${e.message}", e)
                if (attempt >= MAX_RETRY_COUNT) {
                    throw SecurityException.KeyGenerationException("Failed to create encrypted SharedPreferences after $MAX_RETRY_COUNT attempts", e)
                }
                throw e // 让 retryWithBackoff 处理重试
            }
        }
    }
    
    /**
     * 带指数退避的重试机制
     */
    private inline fun <T> retryWithBackoff(maxRetries: Int, action: (attempt: Int) -> T): T {
        var lastException: Exception? = null
        
        for (attempt in 1..maxRetries) {
            try {
                return action(attempt)
            } catch (e: Exception) {
                lastException = e
                if (attempt < maxRetries) {
                    val delay = Math.pow(2.0, attempt.toDouble()).toLong() * 100 // 指数退避
                    Log.w(TAG, "Operation failed, retrying in ${delay}ms (attempt $attempt/$maxRetries)")
                    Thread.sleep(delay)
                }
            }
        }
        
        throw lastException ?: RuntimeException("Unknown error")
    }

    /**
     * 初始化 AES-256 密钥
     * 
     * @return AES-256 密钥
     * @throws SecurityException.KeyGenerationException 密钥生成失败
     */
    private fun getOrCreateAesKey(): SecretKey {
        return try {
            // 尝试从 KeyStore 获取密钥
            val existingKey = keyStore.getKey(KEYSTORE_ALIAS, null) as? SecretKey
            if (existingKey != null) {
                Log.d(TAG, "Found existing encryption key")
                existingKey
            } else {
                Log.i(TAG, "No existing key found, generating new one")
                generateNewAesKey()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get existing key: ${e.message}", e)
            try {
                generateNewAesKey()
            } catch (keyEx: Exception) {
                throw SecurityException.KeyGenerationException("Failed to create AES key", keyEx)
            }
        }
    }

    /**
     * 生成新的 AES-256 密钥并存储到 KeyStore
     * 
     * @return 新生成的 AES-256 密钥
     * @throws SecurityException.KeyGenerationException 密钥生成失败
     */
    private fun generateNewAesKey(): SecretKey {
        return try {
            Log.d(TAG, "Generating new AES-256 key")
            
            val keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore"
            )

            val keyGenParameterSpec = KeyGenParameterSpec.Builder(
                KEYSTORE_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setKeySize(256)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(false)
                .setRandomizedEncryptionRequired(true)
                .build()

            keyGenerator.init(keyGenParameterSpec)
            val key = keyGenerator.generateKey()
            
            Log.i(TAG, "AES-256 key generated successfully")
            key
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate AES key: ${e.message}", e)
            throw SecurityException.KeyGenerationException("Key generation failed", e)
        }
    }

    /**
     * AES-256-GCM 加密
     * 
     * @param data 待加密的字符串
     * @return Base64 编码的加密数据
     * @throws SecurityException.EncryptionException 加密失败
     * @throws IllegalArgumentException 输入数据为空
     */
    fun encrypt(data: String): String {
        require(data.isNotEmpty()) { "Data to encrypt cannot be empty" }
        
        return try {
            Log.d(TAG, "Encrypting data (length: ${data.length})")
            
            val key = getOrCreateAesKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            
            // 生成随机 IV
            val iv = ByteArray(AES_GCM_IV_LENGTH)
            secureRandom.nextBytes(iv)
            
            val gcmSpec = GCMParameterSpec(AES_GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec)
            
            val encryptedBytes = cipher.doFinal(data.toByteArray(Charset.forName("UTF-8")))
            
            // 将 IV 和加密数据组合：IV + 密文
            val combined = ByteArray(iv.size + encryptedBytes.size)
            System.arraycopy(iv, 0, combined, 0, iv.size)
            System.arraycopy(encryptedBytes, 0, combined, iv.size, encryptedBytes.size)
            
            val result = Base64.encodeToString(combined, Base64.DEFAULT)
            Log.i(TAG, "Encryption completed successfully")
            result
        } catch (e: SecurityException) {
            throw e // 重新抛出已分类的异常
        } catch (e: Exception) {
            Log.e(TAG, "Encryption failed: ${e.message}", e)
            throw SecurityException.EncryptionException("Encryption failed", e)
        }
    }

    /**
     * AES-256-GCM 解密
     * 
     * @param encryptedData Base64 编码的加密数据
     * @return 解密后的字符串
     * @throws SecurityException.DecryptionException 解密失败
     * @throws SecurityException.InvalidDataException 数据格式无效
     * @throws IllegalArgumentException 输入数据为空
     */
    fun decrypt(encryptedData: String): String {
        require(encryptedData.isNotEmpty()) { "Encrypted data cannot be empty" }
        
        return try {
            Log.d(TAG, "Decrypting data (length: ${encryptedData.length})")
            
            val key = getOrCreateAesKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            
            // 解码 Base64
            val combined = try {
                Base64.decode(encryptedData, Base64.DEFAULT)
            } catch (e: Exception) {
                throw SecurityException.InvalidDataException("Invalid Base64 data", e)
            }
            
            // 验证数据长度
            if (combined.size < AES_GCM_IV_LENGTH) {
                throw SecurityException.InvalidDataException("Encrypted data too short")
            }
            
            // 分离 IV 和密文
            val iv = ByteArray(AES_GCM_IV_LENGTH)
            val encryptedBytes = ByteArray(combined.size - AES_GCM_IV_LENGTH)
            System.arraycopy(combined, 0, iv, 0, iv.size)
            System.arraycopy(combined, iv.size, encryptedBytes, 0, encryptedBytes.size)
            
            val gcmSpec = GCMParameterSpec(AES_GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec)
            
            val decryptedBytes = cipher.doFinal(encryptedBytes)
            val result = String(decryptedBytes, Charset.forName("UTF-8"))
            
            Log.i(TAG, "Decryption completed successfully")
            result
        } catch (e: SecurityException) {
            throw e // 重新抛出已分类的异常
        } catch (e: javax.crypto.BadPaddingException) {
            Log.e(TAG, "Decryption failed: Invalid padding or authentication tag", e)
            throw SecurityException.DecryptionException("Invalid authentication tag or corrupted data", e)
        } catch (e: Exception) {
            Log.e(TAG, "Decryption failed: ${e.message}", e)
            throw SecurityException.DecryptionException("Decryption failed", e)
        }
    }

    /**
     * 加密字节数组
     * 
     * @param data 待加密的字节数组
     * @return 加密后的数据（包含 IV）
     * @throws SecurityException.EncryptionException 加密失败
     * @throws IllegalArgumentException 输入数据为空
     */
    fun encryptBytes(data: ByteArray): ByteArray {
        require(data.isNotEmpty()) { "Data to encrypt cannot be empty" }
        
        return try {
            Log.d(TAG, "Encrypting byte array (length: ${data.size})")
            
            val key = getOrCreateAesKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            
            val iv = ByteArray(AES_GCM_IV_LENGTH)
            secureRandom.nextBytes(iv)
            
            val gcmSpec = GCMParameterSpec(AES_GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.ENCRYPT_MODE, key, gcmSpec)
            
            val encryptedBytes = cipher.doFinal(data)
            
            val combined = ByteArray(iv.size + encryptedBytes.size)
            System.arraycopy(iv, 0, combined, 0, iv.size)
            System.arraycopy(encryptedBytes, 0, combined, iv.size, encryptedBytes.size)
            
            Log.i(TAG, "Byte array encryption completed successfully")
            combined
        } catch (e: SecurityException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Byte array encryption failed: ${e.message}", e)
            throw SecurityException.EncryptionException("Encryption failed", e)
        }
    }

    /**
     * 解密字节数组
     * 
     * @param encryptedData 加密的数据（包含 IV）
     * @return 解密后的字节数组
     * @throws SecurityException.DecryptionException 解密失败
     * @throws SecurityException.InvalidDataException 数据格式无效
     * @throws IllegalArgumentException 输入数据为空
     */
    fun decryptBytes(encryptedData: ByteArray): ByteArray {
        require(encryptedData.isNotEmpty()) { "Encrypted data cannot be empty" }
        
        return try {
            Log.d(TAG, "Decrypting byte array (length: ${encryptedData.size})")
            
            // 验证数据长度
            if (encryptedData.size < AES_GCM_IV_LENGTH) {
                throw SecurityException.InvalidDataException("Encrypted data too short")
            }
            
            val key = getOrCreateAesKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            
            val iv = ByteArray(AES_GCM_IV_LENGTH)
            val encryptedBytes = ByteArray(encryptedData.size - AES_GCM_IV_LENGTH)
            System.arraycopy(encryptedData, 0, iv, 0, iv.size)
            System.arraycopy(encryptedData, iv.size, encryptedBytes, 0, encryptedBytes.size)
            
            val gcmSpec = GCMParameterSpec(AES_GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, gcmSpec)
            
            val result = cipher.doFinal(encryptedBytes)
            Log.i(TAG, "Byte array decryption completed successfully")
            result
        } catch (e: SecurityException) {
            throw e
        } catch (e: javax.crypto.BadPaddingException) {
            Log.e(TAG, "Decryption failed: Invalid padding or authentication tag", e)
            throw SecurityException.DecryptionException("Invalid authentication tag or corrupted data", e)
        } catch (e: Exception) {
            Log.e(TAG, "Byte array decryption failed: ${e.message}", e)
            throw SecurityException.DecryptionException("Decryption failed", e)
        }
    }

    /**
     * 检查加密是否可用
     */
    fun isEncryptionAvailable(): Boolean {
        return try {
            getOrCreateAesKey()
            true
        } catch (e: Exception) {
            Log.w(TAG, "Encryption not available: ${e.message}")
            false
        }
    }

    /**
     * 清除所有加密密钥
     */
    fun clearKeys() {
        try {
            keyStore.deleteEntry(KEYSTORE_ALIAS)
            Log.i(TAG, "Encryption keys cleared")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear keys: ${e.message}")
        }
    }
}
