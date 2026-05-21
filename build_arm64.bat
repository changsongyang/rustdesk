@echo off
setlocal

set ANDROID_NDK_HOME=C:\Android\ndk\android-ndk-r28c
cd /d C:\Users\ycsit\Downloads\rustdesk\rustdesk

echo === Building Rust native library for Android arm64 ===
"C:\Program Files\Git\git-bash.exe" -c "export ANDROID_NDK_HOME=/c/Android/ndk/android-ndk-r28c && cargo ndk --platform 21 --target aarch64-linux-android build --release --features flutter,hwcodec"

if %ERRORLEVEL% EQU 0 (
    echo === Build successful ===
) else (
    echo === Build failed with error code %ERRORLEVEL% ===
)

pause
