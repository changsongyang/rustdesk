# RustDesk Android应用混淆配置

# 优化配置
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# 优化算法
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*,!code/allocation/variable

# 保留注解
-keepattributes *Annotation*

# 保留调试信息
-keepattributes SourceFile,LineNumberTable

# 保留异常
-keepattributes Exceptions

# 保留泛型签名
-keepattributes Signature

# 保留内部类
-keepattributes InnerClasses

# 保留EnclosingMethod
-keepattributes EnclosingMethod

# 移除日志（发布版本）
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

# 保留应用核心类
-keep class com.carriez.flutter_hbb.** { *; }

# 保留Flutter相关类
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保留RustDesk核心功能类
-keep class com.rustdesk.** { *; }

# 保留FFI接口
-keep class ffi.** { *; }

# 保留Native方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留自定义View
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# 保留Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# 保留Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 保留枚举
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留R资源
-keep class **.R$* {
    *;
}

# 保留BuildConfig
-keep class com.carriez.flutter_hbb.BuildConfig { *; }

# 保留JavaScript接口
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# 保留WebView相关
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String);
}

# 保留OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# 保留Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# 保留Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# 保留Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# 保留协程
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# 警告处理
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# 安全加固
-repackageclasses 'a'
-allowaccessmodification
-mergeinterfacesaggressively

# 移除未使用的代码
-dontshrink
