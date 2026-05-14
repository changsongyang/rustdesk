#!/usr/bin/env bash
set -euo pipefail

MODE=${MODE:=release}

# 校验 MODE 参数
if [[ "$MODE" != "release" && "$MODE" != "debug" && "$MODE" != "profile" ]]; then
  echo "ERROR: Invalid MODE '$MODE'. Must be: release, debug, or profile"
  exit 1
fi

# 校验 NDK 环境变量
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ERROR: ANDROID_NDK_HOME is not set"
  exit 1
fi

# 使用现代 LLVM strip（兼容 NDK r22+）
STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
if [[ ! -x "$STRIP" ]]; then
  echo "ERROR: llvm-strip not found at $STRIP"
  exit 1
fi

echo "=== Stripping native libraries ==="
for arch_dir in arm64-v8a armeabi-v7a; do
  lib_dir="android/app/src/main/jniLibs/$arch_dir"
  if [[ -d "$lib_dir" ]]; then
    echo "Stripping $arch_dir..."
    "$STRIP" "$lib_dir"/* 2>/dev/null || true
  fi
done

echo "=== Building APK (split-per-abi) ==="
flutter build apk --split-per-abi --target-platform android-arm64,android-arm --"$MODE" --obfuscate --split-debug-info ./split-debug-info

echo "=== Building AppBundle ==="
flutter build appbundle --target-platform android-arm64,android-arm --"$MODE" --obfuscate --split-debug-info ./split-debug-info

echo "=== Build completed ==="
