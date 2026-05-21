#!/bin/bash
cd /c/Users/ycsit/Downloads/rustdesk/rustdesk
export ANDROID_NDK_HOME=/c/Android/ndk/android-ndk-r28c
cargo ndk --platform 21 --target aarch64-linux-android build --release --features flutter,hwcodec > /c/Users/ycsit/Downloads/rustdesk/rustdesk/build_log.txt 2>&1
echo "Exit code: $?" >> /c/Users/ycsit/Downloads/rustdesk/rustdesk/build_log.txt
