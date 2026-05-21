package com.carriez.flutter_hbb

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * 自动重连管理器
 * 实现网络断开后的自动重连机制
 */
class AutoReconnectManager(context: Context) {

    companion object {
        private const val TAG = "AutoReconnectManager"
        private const val MAX_RECONNECT_ATTEMPTS = 5
        private const val INITIAL_RECONNECT_DELAY_MS = 2000L
        private const val MAX_RECONNECT_DELAY_MS = 30000L
    }

    private val networkMonitor: NetworkMonitor = NetworkMonitor(context)
    private val coroutineScope = CoroutineScope(Dispatchers.IO)
    private val reconnectMutex = Mutex()
    private var isReconnecting = false
    private var reconnectAttempts = 0
    private var onReconnectRequired: (() -> Unit)? = null
    private var onReconnectSuccess: (() -> Unit)? = null
    private var onReconnectFailed: ((Int) -> Unit)? = null
    private var onReconnectStateChanged: ((ReconnectState) -> Unit)? = null

    /**
     * 重连状态枚举
     */
    enum class ReconnectState {
        IDLE,
        WAITING_FOR_NETWORK,
        RECONNECTING,
        SUCCESS,
        FAILED
    }

    /**
     * 初始化自动重连管理器
     */
    fun initialize(
        onReconnectRequired: () -> Unit,
        onReconnectSuccess: () -> Unit,
        onReconnectFailed: (Int) -> Unit,
        onReconnectStateChanged: (ReconnectState) -> Unit
    ) {
        this.onReconnectRequired = onReconnectRequired
        this.onReconnectSuccess = onReconnectSuccess
        this.onReconnectFailed = onReconnectFailed
        this.onReconnectStateChanged = onReconnectStateChanged

        networkMonitor.initialize()
        networkMonitor.addNetworkListener(object : NetworkMonitor.NetworkListener {
            override fun onNetworkStateChanged(state: NetworkMonitor.NetworkState) {
                handleNetworkStateChange(state)
            }
        })

        Log.i(TAG, "AutoReconnectManager initialized")
    }

    /**
     * 处理网络状态变化
     */
    private fun handleNetworkStateChange(state: NetworkMonitor.NetworkState) {
        Log.d(TAG, "Network state changed: connected=${state.isConnected}, type=${state.networkType}")

        if (state.isConnected && isReconnecting) {
            // 网络恢复，开始重连
            startReconnectSequence()
        } else if (!state.isConnected) {
            // 网络断开，重置状态
            resetReconnectState()
            notifyStateChanged(ReconnectState.WAITING_FOR_NETWORK)
        }
    }

    /**
     * 开始重连序列
     */
    private fun startReconnectSequence() {
        coroutineScope.launch {
            reconnectMutex.withLock {
                if (!isReconnecting) {
                    return@withLock
                }

                val delayMs = calculateReconnectDelay(reconnectAttempts)
                Log.i(TAG, "Attempting reconnect #${reconnectAttempts + 1} in ${delayMs}ms")

                notifyStateChanged(ReconnectState.RECONNECTING)

                delay(delayMs)

                try {
                    onReconnectRequired?.invoke()
                    // 假设重连成功，如果需要确认可以添加回调
                    reconnectAttempts = 0
                    isReconnecting = false
                    notifyStateChanged(ReconnectState.SUCCESS)
                    onReconnectSuccess?.invoke()
                    Log.i(TAG, "Reconnect successful")
                } catch (e: Exception) {
                    handleReconnectFailure()
                }
            }
        }
    }

    /**
     * 处理重连失败
     */
    private fun handleReconnectFailure() {
        reconnectAttempts++
        
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            // 达到最大重连次数
            isReconnecting = false
            notifyStateChanged(ReconnectState.FAILED)
            onReconnectFailed?.invoke(reconnectAttempts)
            Log.e(TAG, "Reconnect failed after $MAX_RECONNECT_ATTEMPTS attempts")
        } else {
            // 继续尝试下一次重连
            Log.w(TAG, "Reconnect attempt #$reconnectAttempts failed, will retry")
            startReconnectSequence()
        }
    }

    /**
     * 计算重连延迟（指数退避）
     */
    private fun calculateReconnectDelay(attempt: Int): Long {
        // 指数退避：2^attempt * 初始延迟，最大不超过 MAX_RECONNECT_DELAY_MS
        val delayMs = INITIAL_RECONNECT_DELAY_MS * (1 shl attempt)
        return minOf(delayMs, MAX_RECONNECT_DELAY_MS)
    }

    /**
     * 触发重连流程
     */
    fun triggerReconnect() {
        if (isReconnecting) {
            Log.w(TAG, "Already reconnecting, ignoring trigger")
            return
        }

        isReconnecting = true
        reconnectAttempts = 0

        val currentState = networkMonitor.getCurrentNetworkState()
        if (currentState.isConnected) {
            // 网络已连接，立即开始重连
            startReconnectSequence()
        } else {
            // 等待网络恢复
            notifyStateChanged(ReconnectState.WAITING_FOR_NETWORK)
            Log.i(TAG, "Waiting for network connection...")
        }
    }

    /**
     * 重置重连状态
     */
    fun resetReconnectState() {
        isReconnecting = false
        reconnectAttempts = 0
        notifyStateChanged(ReconnectState.IDLE)
    }

    /**
     * 获取当前重连状态
     */
    fun getReconnectState(): ReconnectState {
        return if (!isReconnecting) {
            ReconnectState.IDLE
        } else {
            when (networkMonitor.isConnected()) {
                true -> ReconnectState.RECONNECTING
                false -> ReconnectState.WAITING_FOR_NETWORK
            }
        }
    }

    /**
     * 获取剩余重连尝试次数
     */
    fun getRemainingAttempts(): Int {
        return MAX_RECONNECT_ATTEMPTS - reconnectAttempts
    }

    /**
     * 获取当前重连延迟（毫秒）
     */
    fun getCurrentReconnectDelay(): Long {
        return calculateReconnectDelay(reconnectAttempts)
    }

    /**
     * 通知状态变化
     */
    private fun notifyStateChanged(state: ReconnectState) {
        coroutineScope.launch(Dispatchers.Main) {
            onReconnectStateChanged?.invoke(state)
        }
    }

    /**
     * 释放资源
     */
    fun release() {
        resetReconnectState()
        networkMonitor.release()
        Log.i(TAG, "AutoReconnectManager released")
    }

    /**
     * 检查是否正在重连
     */
    fun isReconnecting(): Boolean {
        return isReconnecting
    }

    /**
     * 强制停止重连
     */
    fun stopReconnect() {
        resetReconnectState()
        Log.i(TAG, "Reconnect stopped")
    }
}
