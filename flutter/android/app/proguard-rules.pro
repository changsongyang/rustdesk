# RustDesk Android应用混淆配置
# 版本: v1.4.6-1
# 目标: 高强度代码混淆与网络安全加固

# ==================== 基础优化配置 ====================
-optimizationpasses 7
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose
-repackageclasses 'a'
-allowaccessmodification
-mergeinterfacesaggressively

# 优化算法配置
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*,!code/allocation/variable,!code/removal/advanced,!code/removal/simplify

# ==================== 变量重命名优化 ====================
# ProGuard 会自动处理变量重命名，不需要额外指令

# ==================== 代码结构变换 ====================
# ProGuard 标准优化，不需要额外的结构变换指令

# ==================== 保留注解 ====================
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeVisibleDefaultAnnotations

# ==================== 日志移除（发布版本） ====================
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int println(...);
}
-assumenosideeffects class android.os.Build {
    public static String VERSION;
}
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}
-assumenosideeffects class java.io.PrintWriter {
    public void print(...);
    public void println(...);
}

# ==================== 应用核心类保护 ====================
# Flutter核心类（必须保留）
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.engine.** { *; }
-keep class io.flutter.plugin.** { *; }

# RustDesk核心类（必须保留）
-keep class com.rustdesk.** { *; }
-keep class com.carriez.flutter_hbb.** { *; }
-keep class com.carriez.flutter_hbb.MainApplication { *; }
-keep class com.carriez.flutter_hbb.MainActivity { *; }
-keep class com.carriez.flutter_hbb.BootReceiver { *; }
-keep class com.carriez.flutter_hbb.PermissionManager { *; }
-keep class com.carriez.flutter_hbb.SecurityAuditor { *; }
-keep class com.carriez.flutter_hbb.MainService { *; }
-keep class com.carriez.flutter_hbb.InputService { *; }
-keep class com.carriez.flutter_hbb.FloatingWindowService { *; }

# FFI接口保护
-keep class ffi.** { *; }
-keep class net.rubicon.** { *; }

# ==================== Native方法保护 ====================
-keepclasseswithmembernames class * {
    native <methods>;
    public <methods>;
    private <methods>;
}
-keepclasseswithmembernames class * {
    public <methods>;
}

# ==================== View和UI组件保护 ====================
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference
-keep public class * extends android.view.View
-keep public class * extends android.widget.RemoteViews {
    public <init>(...);
}

# ==================== Parcelable保护 ====================
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ==================== Serializable保护 ====================
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ==================== 枚举保护 ====================
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ==================== R资源保护 ====================
-keepclassmembers class **.R$* {
    public static <fields>;
}
-keep class **.R { *; }

# ==================== BuildConfig保护 ====================
-keep class com.carriez.flutter_hbb.BuildConfig { *; }

# ==================== JavaScript接口保护 ====================
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# ==================== WebView保护 ====================
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String);
}

# ==================== 网络安全库保护 ====================
# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn okio.ByteString
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-keepattributes Exceptions

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers class * implements com.google.gson.JsonSerializer {
    public <methods>;
}
-keepclassmembers class * implements com.google.gson.JsonDeserializer {
    public <methods>;
}

# Protobuf
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# ==================== Kotlin保护 ====================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-keepclassmembers class kotlin.jvm.internal.Reflection { *; }

# 协程保护
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# ==================== 网络安全加固 ====================
# 防止SSL中间人攻击
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-keep class org.conscrypt.** { *; }
-keep class org.bouncycastle.** { *; }
-keep class org.openjsse.** { *; }

# ==================== 反射和动态代码保护 ====================
-keep class java.lang.reflect.** { *; }
-keep class java.lang.Class { *; }
-keep class java.lang.ClassLoader { *; }
-keepclassmembers class java.lang.ClassLoader {
    <fields>;
    <methods>;
}

# ==================== 安全审计相关类保护 ====================
-keep class com.carriez.flutter_hbb.SecurityAuditor$* { *; }
-keep class com.carriez.flutter_hbb.PermissionManager$* { *; }

# ==================== 警告处理 ====================
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.**
-dontwarn sun.misc.**
-dontwarn org.slf4j.**
-dontwarn org.apache.**

# ==================== 最终安全检查 ====================
# 确保不删除某些关键类
-keep class * extends java.lang.Enum {
    <fields>;
}
-keepclassmembers enum * {
    <fields>;
}

# 防止代码优化移除关键初始化
-keepclassmembers class * {
    static <clinit>();
    static <init>();
}

# ==================== 自定义混淆字典 ====================
-obfuscationdictionary proguard-dictionary.txt
-classobfuscationdictionary proguard-dictionary.txt
-packageobfuscationdictionary proguard-dictionary.txt

# ==================== 最终配置 ====================
# 移除调试信息（已在编译时禁用）
# 不添加任何可能泄露信息的内容