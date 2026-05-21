# Android 优化组件技术文档

## 概述

本文档描述了 RustDesk Android 应用的优化组件架构，包括安全加密、网络监测、自动重连和生物识别四大核心模块。

---

## 1. 安全加密组件 (SecurityEncryption)

### 1.1 功能概述
提供 AES-256-GCM 加密和解密功能，集成 Android Keystore 安全存储敏感数据。

### 1.2 类结构

```kotlin
class SecurityEncryption(context: Context) {
    // 属性
    private val keyStore: KeyStore        // Android Keystore 实例
    private val secureRandom: SecureRandom // 安全随机数生成器
    
    // 方法
    fun encrypt(data: String): String     // 加密字符串
    fun decrypt(data: String): String     // 解密字符串
    fun getEncryptedSharedPreferences(name: String): SharedPreferences // 获取加密的 SharedPreferences
}
```

### 1.3 使用示例

```kotlin
val encryption = SecurityEncryption(context)

// 加密数据
val encrypted = encryption.encrypt("sensitive data")

// 解密数据
val decrypted = encryption.decrypt(encrypted)

// 使用加密的 SharedPreferences
val prefs = encryption.getEncryptedSharedPreferences("secure_prefs")
prefs.edit().putString("token", encryptedToken).apply()
```

### 1.4 安全性说明

| 特性 | 实现方式 | 安全级别 |
|------|----------|----------|
| 加密算法 | AES-256-GCM | 军事级 |
| 密钥存储 | Android Keystore | 硬件安全 |
| 随机数 | SecureRandom | 密码学安全 |
| 认证标签 | GCM 128-bit | 完整性保护 |

---

## 2. 网络监测组件 (NetworkMonitor)

### 2.1 功能概述
实时监测网络状态变化，支持 Wi-Fi、移动数据、以太网等多种网络类型。

### 2.2 核心数据结构

```kotlin
data class NetworkState(
    val isConnected: Boolean,      // 是否连接
    val networkType: NetworkType,  // 网络类型
    val signalStrength: Int,       // 信号强度 (0-100)
    val isMetered: Boolean         // 是否计量网络
)

enum class NetworkType {
    NONE,       // 无网络
    WIFI,       // Wi-Fi
    CELLULAR,   // 移动数据
    ETHERNET    // 以太网
}
```

### 2.3 接口定义

```kotlin
interface NetworkListener {
    fun onNetworkStateChanged(state: NetworkState)
}

class NetworkMonitor(context: Context) {
    fun initialize()                          // 初始化监测
    fun getCurrentNetworkState(): NetworkState // 获取当前网络状态
    fun isNetworkAvailable(): Boolean          // 检查网络是否可用
    fun addNetworkListener(listener: NetworkListener) // 添加监听器
    fun removeNetworkListener(listener: NetworkListener) // 移除监听器
}
```

### 2.4 使用示例

```kotlin
val networkMonitor = NetworkMonitor(context)
networkMonitor.initialize()

networkMonitor.addNetworkListener(object : NetworkListener {
    override fun onNetworkStateChanged(state: NetworkState) {
        Log.d(TAG, "Network: ${state.isConnected}, Type: ${state.networkType}")
    }
})
```

---

## 3. 自动重连组件 (AutoReconnectManager)

### 3.1 功能概述
实现智能自动重连机制，支持指数退避策略，最多重试 5 次。

### 3.2 核心配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| maxAttempts | 5 | 最大重试次数 |
| initialDelayMs | 2000 | 初始延迟 (毫秒) |
| delayMultiplier | 2.0 | 延迟倍数 |

### 3.3 接口定义

```kotlin
class AutoReconnectManager(context: Context) {
    fun initialize(
        onReconnectRequired: () -> Unit,
        onReconnectSuccess: () -> Unit,
        onReconnectFailed: (attempts: Int) -> Unit,
        onReconnectStateChanged: (state: ReconnectState) -> Unit
    )
    
    fun triggerReconnect()     // 触发重连
    fun cancelReconnect()      // 取消重连
}

enum class ReconnectState {
    IDLE,           // 空闲
    CONNECTING,     // 连接中
    SUCCESS,        // 成功
    FAILED,         // 失败
    CANCELLED       // 已取消
}
```

### 3.4 重连策略

| 重试次数 | 延迟时间 | 说明 |
|----------|----------|------|
| 第 1 次 | 2 秒 | 初始延迟 |
| 第 2 次 | 4 秒 | 2 × 2 |
| 第 3 次 | 8 秒 | 4 × 2 |
| 第 4 次 | 16 秒 | 8 × 2 |
| 第 5 次 | 32 秒 | 16 × 2 |

### 3.5 使用示例

```kotlin
val reconnectManager = AutoReconnectManager(context)
reconnectManager.initialize(
    onReconnectRequired = { /* 准备重连 */ },
    onReconnectSuccess = { /* 重连成功 */ },
    onReconnectFailed = { attempts -> /* 重连失败 */ },
    onReconnectStateChanged = { state -> /* 状态变化 */ }
)

// 触发重连
reconnectManager.triggerReconnect()
```

---

## 4. 生物识别组件 (BiometricAuthenticator)

### 4.1 功能概述
支持指纹和面部识别，集成 Android Biometric API。

### 4.2 生物识别类型

```kotlin
enum class BiometricType {
    NONE,           // 不支持
    FINGERPRINT,    // 指纹识别
    FACE,           // 面部识别
    IRIS,           // 虹膜识别
    STRONG,         // 强生物识别
    WEAK            // 弱生物识别
}
```

### 4.3 接口定义

```kotlin
interface AuthCallback {
    fun onSuccess()                          // 认证成功
    fun onError(errorCode: Int, errorMessage: String) // 认证错误
    fun onFailed()                           // 认证失败
}

class BiometricAuthenticator(context: Context) {
    fun canAuthenticate(): BiometricType         // 检查是否支持生物识别
    fun hasFingerprint(): Boolean                // 是否有指纹识别
    fun hasFaceRecognition(): Boolean           // 是否有面部识别
    fun authenticate(
        activity: FragmentActivity,
        title: String,
        subtitle: String,
        negativeButtonText: String,
        callback: AuthCallback
    )                                           // 执行生物识别认证
    fun getErrorMessage(errorCode: Int): String // 获取错误消息
}
```

### 4.4 使用示例

```kotlin
val biometric = BiometricAuthenticator(context)

if (biometric.canAuthenticate() != BiometricType.NONE) {
    biometric.authenticate(
        activity,
        title = "验证身份",
        subtitle = "使用指纹或面部识别",
        callback = object : AuthCallback {
            override fun onSuccess() { /* 成功 */ }
            override fun onError(code: Int, msg: String) { /* 错误 */ }
            override fun onFailed() { /* 失败 */ }
        }
    )
}
```

---

## 5. Flutter 方法通道集成

### 5.1 安全加密方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `encrypt_data` | `String` data | `String` encrypted | 加密字符串 |
| `decrypt_data` | `String` data | `String` decrypted | 解密字符串 |
| `set_secure_preference` | `Map<String, String>` {key, value} | `Boolean` | 设置加密偏好 |
| `get_secure_preference` | `String` key | `String?` value | 获取加密偏好 |

### 5.2 生物识别方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `check_biometric_available` | 无 | `String` type | 检查生物识别类型 |
| `has_fingerprint` | 无 | `Boolean` | 是否有指纹 |
| `has_face_recognition` | 无 | `Boolean` | 是否有面部识别 |
| `authenticate_biometric` | 无 | `Boolean` | 执行生物识别 |

### 5.3 网络状态方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `get_network_state` | 无 | `Map` state | 获取网络状态 |
| `is_network_available` | 无 | `Boolean` | 网络是否可用 |

### 5.4 自动重连方法

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `trigger_reconnect` | 无 | `Boolean` | 触发重连 |
| `cancel_reconnect` | 无 | `Boolean` | 取消重连 |

### 5.5 回调事件

| 事件名 | 参数 | 说明 |
|--------|------|------|
| `on_network_state_changed` | `Map` state | 网络状态变化 |
| `on_reconnect_success` | 无 | 重连成功 |
| `on_reconnect_failed` | `Int` attempts | 重连失败 |
| `on_reconnect_state` | `String` state | 重连状态变化 |
| `on_biometric_success` | 无 | 生物识别成功 |
| `on_biometric_error` | `Map` {code, message} | 生物识别错误 |
| `on_biometric_failed` | 无 | 生物识别失败 |

---

## 6. 依赖配置

### 6.1 build.gradle 依赖

```gradle
dependencies {
    // 安全加密
    implementation "androidx.security:security-crypto:1.1.0-alpha05"
    
    // 生物识别
    implementation "androidx.biometric:biometric:1.1.0"
    
    // 协程
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

### 6.2 AndroidManifest.xml 权限

```xml
<!-- 网络权限 -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- 生物识别权限 -->
<uses-permission android:name="android.permission.USE_BIOMETRIC" />

<!-- 后台服务权限 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

---

## 7. 架构设计

### 7.1 组件关系图

```
┌─────────────────────────────────────────────────────────┐
│                      MainActivity                       │
│  ┌──────────────────┐  ┌─────────────────────────────┐  │
│  │ SecurityEncryption│  │      MethodChannel          │  │
│  │  - AES-256-GCM   │  │  ↔ Flutter UI               │  │
│  │  - Keystore      │  └─────────────────────────────┘  │
│  └────────┬─────────┘                                    │
┌───────────┴─────────────────────────────────────────────┐
│                    NetworkMonitor                       │
│  ┌───────────────────────────────────────────────────┐  │
│  │  - 网络状态监测                                    │  │
│  │  - 信号强度检测                                    │  │
│  │  - 监听器模式                                      │  │
│  └────────────┬──────────────────────────────────────┘  │
┌───────────────┴─────────────────────────────────────────┐
│                  AutoReconnectManager                   │
│  ┌───────────────────────────────────────────────────┐  │
│  │  - 指数退避策略                                    │  │
│  │  - 最多5次重试                                     │  │
│  │  - 协程异步执行                                    │  │
│  └───────────────────────────────────────────────────┘  │
┌─────────────────────────────────────────────────────────┐
│                   BiometricAuthenticator                │
│  ┌───────────────────────────────────────────────────┐  │
│  │  - 指纹识别支持                                    │  │
│  │  - 面部识别支持                                    │  │
│  │  - Android Biometric API                          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 7.2 数据流

```
用户操作 → Flutter UI → MethodChannel → Android 组件
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    ▼                         ▼                         ▼
            SecurityEncryption         NetworkMonitor          BiometricAuthenticator
                    │                         │                         │
                    ▼                         ▼                         ▼
              Android Keystore        ConnectivityManager      BiometricManager
                                              │
                                              ▼
                                      AutoReconnectManager
                                              │
                                              ▼
                                         网络重连
```

---

## 8. 安全最佳实践

### 8.1 加密最佳实践

1. **使用 Android Keystore** 存储密钥，避免明文存储
2. **使用 SecureRandom** 生成随机数，确保密码学安全
3. **使用 GCM 模式** 进行加密，提供完整性保护
4. **定期轮换密钥**，降低密钥泄露风险

### 8.2 网络安全最佳实践

1. **使用 HTTPS** 进行网络通信
2. **验证证书**，防止中间人攻击
3. **添加请求超时**，避免资源浪费
4. **实现重连机制**，提升连接稳定性

### 8.3 生物识别安全最佳实践

1. **使用 STRONG 认证级别**，确保安全性
2. **处理错误情况**，提供友好的错误提示
3. **提供备用验证方式**，当生物识别失败时使用
4. **不在日志中记录敏感信息**

---

## 9. 故障排除

### 9.1 加密解密失败

| 错误原因 | 解决方案 |
|----------|----------|
| 密钥不存在 | 确保应用已初始化，密钥已创建 |
| 数据损坏 | 检查数据完整性，重新获取数据 |
| API 版本不兼容 | 确保 minSdkVersion ≥ 23 |

### 9.2 网络监测不工作

| 错误原因 | 解决方案 |
|----------|----------|
| 权限未授予 | 检查 ACCESS_NETWORK_STATE 权限 |
| 设备无网络 | 检查设备网络连接 |
| API 版本不兼容 | 确保 minSdkVersion ≥ 24 |

### 9.3 生物识别失败

| 错误原因 | 解决方案 |
|----------|----------|
| 无硬件支持 | 检查设备是否支持生物识别 |
| 未注册指纹/面部 | 引导用户在系统设置中注册 |
| 认证被锁定 | 等待一段时间后重试或使用备用方式 |

---

## 附录：API 兼容性

| API 等级 | 支持特性 | 说明 |
|----------|----------|------|
| 22 | 基础功能 | 最小支持版本 |
| 23 | Android Keystore | 安全存储 |
| 24 | NetworkCallback | 网络监测 |
| 28 | Biometric API | 生物识别 |
| 31 | Android 12 权限 | 新权限模型 |

---

## 10. CI/CD 代码质量检查

### 10.1 检查机制概述

项目集成了自动化代码质量检查机制，在 CI/CD 流程中自动执行代码规范和静态分析检查。

### 10.2 检查项目

| 检查类型 | 工具 | 触发条件 | 错误级别 |
|----------|------|----------|----------|
| Rust 代码格式 | `cargo fmt` | Rust 文件变更 | 阻断 |
| Rust 静态分析 | `cargo clippy` | Rust 文件变更 | 阻断 |
| Flutter 代码格式 | `flutter format` | Flutter 文件变更 | 阻断 |
| Flutter 静态分析 | `flutter analyze` | Flutter 文件变更 | 阻断 |

### 10.3 条件构建

CI/CD 流程根据文件变更智能触发相关构建：

| 变更路径 | 触发构建 |
|----------|----------|
| `src/**`, `libs/**`, `Cargo.toml`, `Cargo.lock` | Rust 相关构建 |
| `flutter/**` | Flutter 相关构建 |
| `flutter/android/**` | Android 构建 |
| `flutter/ios/**` | iOS 构建 |
| `flutter/windows/**`, `src/platform/windows/**` | Windows 构建 |
| `flutter/macos/**`, `src/platform/darwin/**` | macOS 构建 |
| `flutter/linux/**`, `src/platform/linux/**` | Linux 构建 |
| `**.md`, `**.txt` | 跳过所有构建 |

### 10.4 缓存优化

为提升 CI/CD 效率，项目使用 GitHub Actions 缓存机制：

| 缓存项 | 缓存路径 | 缓存键 |
|--------|----------|--------|
| Rust 依赖 | `~/.cargo/registry`, `~/.cargo/git`, `target` | `${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}` |
| Flutter 依赖 | `~/.pub-cache`, `flutter/.dart_tool` | `${{ runner.os }}-flutter-${{ hashFiles('flutter/pubspec.lock') }}` |

### 10.5 检查流程

```
代码提交 → GitHub Actions → detect-changes → 条件判断
                                               │
          ┌─────────────────────────────────────┼─────────────────────────────────────┐
          ▼                                     ▼                                     ▼
    code-quality job                     platform build jobs                     documentation skip
          │                                     │
          ├─ cargo fmt --check               ├─ Windows build
          ├─ cargo clippy                   ├─ Android build
          ├─ flutter format --check         ├─ macOS build
          └─ flutter analyze                └─ Linux build
```

### 10.6 最佳实践

1. **提交前检查**：在提交代码前运行本地检查确保符合规范
2. **增量变更**：尽量保持提交内容集中，减少不必要的构建
3. **缓存利用**：依赖变更会触发缓存失效，尽量减少不必要的依赖更新
4. **错误修复**：CI 失败时优先修复代码质量问题
