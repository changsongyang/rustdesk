package com.carriez.flutter_hbb

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * 网络状态监测服务
 * 实现网络状态实时监测和通知
 */
class NetworkMonitor(private val context: Context) {

    companion object {
        private const val TAG = "NetworkMonitor"
    }

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var listeners = mutableListOf<NetworkListener>()
    private var currentNetworkState = NetworkState()
    
    private val wifiManager: android.net.wifi.WifiManager by lazy {
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
    }

    /**
     * 网络状态数据类
     */
    data class NetworkState(
        val isConnected: Boolean = false,
        val networkType: NetworkType = NetworkType.NONE,
        val isMetered: Boolean = false,
        val signalStrength: Int = 0
    )

    /**
     * 网络类型枚举
     */
    enum class NetworkType {
        NONE,
        WIFI,
        CELLULAR,
        ETHERNET,
        BLUETOOTH,
        VPN,
        OTHER
    }

    /**
     * 网络状态监听器接口
     */
    interface NetworkListener {
        fun onNetworkStateChanged(state: NetworkState)
    }

    /**
     * 初始化网络监测
     */
    fun initialize() {
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        // 获取初始网络状态
        currentNetworkState = getCurrentNetworkState()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            registerNetworkCallback()
        }
        
        Log.i(TAG, "Network monitor initialized. Current state: $currentNetworkState")
    }

    /**
     * 注册网络状态监听器
     */
    fun addNetworkListener(listener: NetworkListener) {
        listeners.add(listener)
        // 立即通知当前状态
        listener.onNetworkStateChanged(currentNetworkState)
    }

    /**
     * 移除网络状态监听器
     */
    fun removeNetworkListener(listener: NetworkListener) {
        listeners.remove(listener)
    }

    /**
     * 获取当前网络状态
     */
    fun getCurrentNetworkState(): NetworkState {
        return try {
            val activeNetwork = connectivityManager?.activeNetwork
            val capabilities = connectivityManager?.getNetworkCapabilities(activeNetwork)
            
            if (activeNetwork == null || capabilities == null) {
                NetworkState(isConnected = false, networkType = NetworkType.NONE)
            } else {
                val isConnected = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                
                val networkType = when {
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> NetworkType.WIFI
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> NetworkType.CELLULAR
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> NetworkType.ETHERNET
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> NetworkType.BLUETOOTH
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> NetworkType.VPN
                    else -> NetworkType.OTHER
                }
                
                val isMetered = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED).not()
                
                NetworkState(
                    isConnected = isConnected,
                    networkType = networkType,
                    isMetered = isMetered,
                    signalStrength = getSignalStrength(networkType)
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get current network state: ${e.message}")
            NetworkState(isConnected = false, networkType = NetworkType.NONE)
        }
    }

    /**
     * 获取信号强度 (0-100)
     */
    private fun getSignalStrength(networkType: NetworkType): Int {
        return try {
            when (networkType) {
                NetworkType.WIFI -> {
                    val info = wifiManager.connectionInfo
                    val rssi = info.rssi
                    // RSSI 转换为百分比 (通常范围 -100 到 0)
                    val percentage = ((rssi + 100) * 100) / 100
                    percentage.coerceIn(0, 100)
                }
                NetworkType.CELLULAR -> {
                    // 返回默认值，实际实现需要 TelephonyManager
                    50
                }
                else -> 100
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get signal strength: ${e.message}")
            50
        }
    }

    /**
     * 检查是否连接到网络
     */
    fun isConnected(): Boolean {
        return currentNetworkState.isConnected
    }

    /**
     * 检查是否使用移动数据
     */
    fun isUsingCellular(): Boolean {
        return currentNetworkState.networkType == NetworkType.CELLULAR
    }

    /**
     * 检查网络是否计费（移动数据）
     */
    fun isMetered(): Boolean {
        return currentNetworkState.isMetered
    }

    /**
     * 注册网络回调（API 24+）
     */
    @RequiresApi(Build.VERSION_CODES.N)
    private fun registerNetworkCallback() {
        val networkRequest = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.d(TAG, "Network available")
                updateNetworkState()
            }

            override fun onLost(network: Network) {
                Log.d(TAG, "Network lost")
                updateNetworkState()
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                Log.d(TAG, "Network capabilities changed")
                updateNetworkState()
            }

            override fun onLinkPropertiesChanged(network: Network, linkProperties: android.net.LinkProperties) {
                Log.d(TAG, "Link properties changed")
                updateNetworkState()
            }
        }

        connectivityManager?.registerNetworkCallback(networkRequest, networkCallback!!)
    }

    /**
     * 更新网络状态并通知监听器
     */
    private fun updateNetworkState() {
        val newState = getCurrentNetworkState()
        
        if (newState != currentNetworkState) {
            Log.i(TAG, "Network state changed: $currentNetworkState -> $newState")
            currentNetworkState = newState
            
            // 通知所有监听器
            listeners.forEach { listener ->
                try {
                    listener.onNetworkStateChanged(currentNetworkState)
                } catch (e: Exception) {
                    Log.e(TAG, "Error notifying listener: ${e.message}")
                }
            }
        }
    }

    /**
     * 释放资源
     */
    fun release() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            networkCallback?.let {
                connectivityManager?.unregisterNetworkCallback(it)
            }
        }
        listeners.clear()
        Log.i(TAG, "Network monitor released")
    }

    /**
     * 获取网络类型名称
     */
    fun getNetworkTypeName(): String {
        return when (currentNetworkState.networkType) {
            NetworkType.NONE -> "None"
            NetworkType.WIFI -> "Wi-Fi"
            NetworkType.CELLULAR -> "Cellular"
            NetworkType.ETHERNET -> "Ethernet"
            NetworkType.BLUETOOTH -> "Bluetooth"
            NetworkType.VPN -> "VPN"
            NetworkType.OTHER -> "Other"
        }
    }
}
