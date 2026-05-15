# RustDesk Android应用混淆配置
# 版本: v1.4.6-1-优化版
# 目标: 高强度代码混淆，同时保留必要的FFI接口

# ==================== 基础优化配置 ====================
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose
-allowaccessmodification
-mergeinterfacesaggressively

# 优化算法配置
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*

# ==================== 保留注解和必要信息 ====================
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes RuntimeVisibleAnnotations

# ==================== 日志移除（发布版本） ====================
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int println(...);
}

# ==================== Flutter核心类（必须保留） ====================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.engine.** { *; }
-keep class io.flutter.plugin.** { *; }

# ==================== FFI接口保护（仅保留必要的） ====================
# 仅保留带有 @Keep 注解的类和方法，而不是保留整个包
-keep @androidx.annotation.Keep class * {*;}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep *;
}

# FFI Native方法保护
-keepclasseswithmembernames class * {
    native <methods>;
}

# ==================== 基本组件保护 ====================
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# ==================== Parcelable保护 ====================
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ==================== Serializable保护 ====================
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
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

# ==================== 网络安全库保护 ====================
# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# Protobuf
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# ==================== Kotlin保护 ====================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# 协程保护
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ==================== Rustls平台验证器保护 ====================
-keep class rustls.** { *; }
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**

# ==================== 权限库保护 ====================
-keep class com.hjq.permissions.** { *; }

# ==================== 反射保护 ====================
-keep class java.lang.reflect.** { *; }

# ==================== 警告处理 ====================
-dontwarn javax.annotation.**
-dontwarn org.slf4j.**
-dontwarn org.apache.**

# ==================== 自定义混淆字典 ====================
-obfuscationdictionary proguard-dictionary.txt
-classobfuscationdictionary proguard-dictionary.txt
-packageobfuscationdictionary proguard-dictionary.txt
