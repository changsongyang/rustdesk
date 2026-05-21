package com.carriez.flutter_hbb

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 自动重连组件单元测试
 */
@RunWith(AndroidJUnit4::class)
class AutoReconnectManagerTest {
    
    private lateinit var context: Context
    private lateinit var reconnectManager: AutoReconnectManager
    
    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        reconnectManager = AutoReconnectManager(context)
    }
    
    @Test
    fun testInitialization() {
        reconnectManager.initialize(
            onReconnectRequired = {},
            onReconnectSuccess = {},
            onReconnectFailed = {},
            onReconnectStateChanged = {}
        )
        
        // 初始化不应抛出异常
    }
    
    @Test
    fun testTriggerReconnect() {
        var reconnectRequiredCalled = false
        var reconnectSuccessCalled = false
        var reconnectFailedCalled = false
        var stateChangedCalled = false
        
        reconnectManager.initialize(
            onReconnectRequired = {
                reconnectRequiredCalled = true
            },
            onReconnectSuccess = {
                reconnectSuccessCalled = true
            },
            onReconnectFailed = {
                reconnectFailedCalled = true
            },
            onReconnectStateChanged = {
                stateChangedCalled = true
            }
        )
        
        // Mock 网络可用状态，测试触发重连
        reconnectManager.triggerReconnect()
        
        runBlocking {
            delay(500) // 等待一点时间
        }
        
        assertTrue("State changed should be called", stateChangedCalled)
    }
    
    @Test
    fun testCancelReconnect() {
        reconnectManager.initialize(
            onReconnectRequired = {},
            onReconnectSuccess = {},
            onReconnectFailed = {},
            onReconnectStateChanged = {}
        )
        
        // 触发重连
        reconnectManager.triggerReconnect()
        
        // 取消重连
        reconnectManager.cancelReconnect()
        
        // 取消不应抛出异常
    }
    
    @Test
    fun testMaxReconnectAttempts() {
        var attemptCount = 0
        
        reconnectManager.initialize(
            onReconnectRequired = {},
            onReconnectSuccess = {},
            onReconnectFailed = { attempts ->
                attemptCount = attempts
            },
            onReconnectStateChanged = {}
        )
        
        // 验证最大重试次数配置
        assertEquals("Default max attempts should be 5", 5, reconnectManager.maxAttempts)
    }
    
    @Test
    fun testExponentialBackoff() {
        // 测试指数退避时间
        val delays = listOf(2000L, 4000L, 8000L, 16000L, 32000L)
        
        delays.forEachIndexed { index, expectedDelay ->
            val actualDelay = reconnectManager.calculateDelay(index + 1)
            assertEquals("Delay at attempt ${index + 1} should be $expectedDelay", 
                expectedDelay, actualDelay)
        }
    }
}
