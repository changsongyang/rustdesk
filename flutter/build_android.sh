#!/usr/bin/env bash
set -euo pipefail

MODE=${MODE:=release}
STRIP_LIBS=${STRIP_LIBS:=true}
OBFUSCATE=${OBFUSCATE:=true}

if [[ "$MODE" != "release" && "$MODE" != "debug" && "$MODE" != "profile" ]]; then
  echo "ERROR: Invalid MODE '$MODE'. Must be: release, debug, or profile"
  exit 1
fi

echo "=== RustDesk Android Build ==="
echo "Build Mode: $MODE"
echo "Strip Libraries: $STRIP_LIBS"
echo "Obfuscate: $OBFUSCATE"
echo ""

if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
  HOST_ARCH=$(uname -m)
  case "$HOST_ARCH" in
    x86_64)  HOST_TRIPLET="linux-x86_64" ;;
    aarch64) HOST_TRIPLET="linux-aarch64" ;;
    *)       HOST_TRIPLET="linux-x86_64" ;;
  esac
  STRIP="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TRIPLET/bin/llvm-strip"
  if [[ -x "$STRIP" ]] && [[ "$STRIP_LIBS" == "true" ]]; then
    echo "=== Stripping native libraries ==="
    for arch_dir in arm64-v8a armeabi-v7a x86_64 x86; do
      lib_dir="android/app/src/main/jniLibs/$arch_dir"
      if [[ -d "$lib_dir" ]]; then
        echo "Stripping $arch_dir..."
        find "$lib_dir" -name "*.so" -exec "$STRIP" {} \; 2>/dev/null || true
      fi
    done
    echo ""
  fi
else
  echo "WARNING: ANDROID_NDK_HOME not set, skipping library strip"
  echo ""
fi

DEBUG_INFO_DIR="split-debug-info"
if [[ "$OBFUSCATE" == "true" ]]; then
  rm -rf "$DEBUG_INFO_DIR"
  mkdir -p "$DEBUG_INFO_DIR"
fi

echo "=== Building APK (split-per-abi) ==="
if [[ "$OBFUSCATE" == "true" ]]; then
  flutter build apk --split-per-abi --target-platform android-arm64,android-arm,android-x64 --"$MODE" --obfuscate --split-debug-info "./$DEBUG_INFO_DIR"
else
  flutter build apk --split-per-abi --target-platform android-arm64,android-arm,android-x64 --"$MODE"
fi

echo ""
echo "=== Building AppBundle ==="
if [[ "$OBFUSCATE" == "true" ]]; then
  flutter build appbundle --target-platform android-arm64,android-arm --"$MODE" --obfuscate --split-debug-info "./$DEBUG_INFO_DIR"
else
  flutter build appbundle --target-platform android-arm64,android-arm --"$MODE"
fi

echo ""
echo "=== Build completed ==="
echo "APK files:"
find android/app/build/outputs/flutter-apk -name "*.apk" 2>/dev/null || true
echo ""
echo "AppBundle:"
find android/app/build/outputs/bundle -name "*.aab" 2>/dev/null || true
