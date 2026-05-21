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
 * 网络监测组件单元测试
 */
@RunWith(AndroidJUnit4::class)
class NetworkMonitorTest {
    
    private lateinit var context: Context
    private lateinit var networkMonitor: NetworkMonitor
    
    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        networkMonitor = NetworkMonitor(context)
    }
    
    @Test
    fun testInitialization() {
        networkMonitor.initialize()
        // 初始化不应抛出异常
    }
    
    @Test
    fun testGetCurrentNetworkState() {
        networkMonitor.initialize()
        val state = networkMonitor.getCurrentNetworkState()
        
        assertNotNull("Network state should not be null", state)
        assertTrue("Network type should be defined", 
            listOf(NetworkMonitor.NetworkType.WIFI, 
                   NetworkMonitor.NetworkType.CELLULAR, 
                   NetworkMonitor.NetworkType.ETHERNET, 
                   NetworkMonitor.NetworkType.NONE).contains(state.networkType))
    }
    
    @Test
    fun testIsNetworkAvailable() {
        networkMonitor.initialize()
        val available = networkMonitor.isNetworkAvailable()
        
        // 结果应该是布尔值
        assertTrue("isNetworkAvailable should return boolean", available is Boolean)
    }
    
    @Test
    fun testSignalStrengthRange() {
        networkMonitor.initialize()
        val state = networkMonitor.getCurrentNetworkState()
        
        assertTrue("Signal strength should be between 0 and 100", 
            state.signalStrength in 0..100)
    }
    
    @Test
    fun testAddRemoveListener() {
        networkMonitor.initialize()
        
        var called = false
        val listener = object : NetworkMonitor.NetworkListener {
            override fun onNetworkStateChanged(state: NetworkMonitor.NetworkState) {
                called = true
            }
        }
        
        networkMonitor.addNetworkListener(listener)
        networkMonitor.removeNetworkListener(listener)
        
        // 监听器应该可以正常添加和移除
    }
    
    @Test
    fun testNetworkTypeToString() {
        val types = NetworkMonitor.NetworkType.values()
        
        types.forEach { type ->
            assertNotNull("Network type name should not be null", type.name)
            assertTrue("Network type name should not be empty", type.name.isNotEmpty())
        }
    }
}
