#!/bin/bash

# RustDesk 构建前依赖检查脚本
# 用于验证构建环境是否满足所有依赖要求

set -e

echo "=========================================="
echo "RustDesk 构建前依赖检查"
echo "=========================================="

# 检查状态
check_passed=0
check_failed=0

# 检查函数
check_command() {
    local cmd=$1
    local name=$2
    
    echo -n "✓ 检查 ${name}..."
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>/dev/null | head -n 1 | cut -d' ' -f2)
        echo " 已安装 (版本: ${version:-未知})"
        ((check_passed++))
    else
        echo " ❌ 未安装"
        echo "   建议安装命令: sudo apt-get install -y ${name}"
        ((check_failed++))
    fi
}

# 检查库函数
check_library() {
    local lib=$1
    local name=$2
    
    echo -n "✓ 检查 ${name}..."
    if ldconfig -p | grep -q "${lib}"; then
        echo " 已安装"
        ((check_passed++))
    else
        echo " ❌ 未安装"
        echo "   建议安装命令: sudo apt-get install -y ${lib}-dev"
        ((check_failed++))
    fi
}

# 检查工具链
echo ""
echo "【工具链检查】"
check_command "rustc" "Rust 编译器"
check_command "cargo" "Cargo 包管理器"
check_command "git" "Git 版本控制"
check_command "cmake" "CMake 构建工具"
check_command "ninja" "Ninja 构建系统"
check_command "pkg-config" "pkg-config"

# 检查系统库
echo ""
echo "【系统库检查】"
check_library "libgtk-3" "GTK 3"
check_library "libwebkit2gtk-4.0" "WebKit2 GTK"
check_library "libjavascriptcoregtk-4.0" "JavaScriptCore"
check_library "libcairo" "Cairo"
check_library "libpango" "Pango"
check_library "libgdk-pixbuf-2.0" "GDK Pixbuf"
check_library "libsoup-2.4" "libsoup"
check_library "librsvg-2.0" "librsvg"
check_library "libva" "VA-API"
check_library "libasound" "ALSA"
check_library "libpulse" "PulseAudio"
check_library "libdbus-1" "DBus"

# 检查 vcpkg
echo ""
echo "【vcpkg 检查】"
if [ -n "$VCPKG_ROOT" ] && [ -d "$VCPKG_ROOT" ]; then
    echo "✓ VCPKG_ROOT 设置正确: $VCPKG_ROOT"
    if [ -f "$VCPKG_ROOT/vcpkg" ]; then
        echo "✓ vcpkg 可执行文件存在"
        ((check_passed++))
    else
        echo "❌ vcpkg 可执行文件不存在"
        ((check_failed++))
    fi
else
    echo "⚠️ VCPKG_ROOT 未设置，将在构建时初始化"
    ((check_passed++))
fi

# 检查 FFmpeg
echo ""
echo "【FFmpeg 检查】"
if command -v ffmpeg &> /dev/null; then
    local ffmpeg_version=$(ffmpeg -version 2>&1 | head -n 1 | cut -d' ' -f3)
    echo "✓ FFmpeg 已安装 (版本: $ffmpeg_version)"
    ((check_passed++))
else
    echo "⚠️ FFmpeg 未安装，将通过 vcpkg 安装"
    ((check_passed++))
fi

# 输出总结
echo ""
echo "=========================================="
echo "检查完成"
echo "=========================================="
echo "通过: ${check_passed}"
echo "失败: ${check_failed}"

if [ $check_failed -eq 0 ]; then
    echo ""
    echo "✅ 所有依赖检查通过，可以开始构建"
    exit 0
else
    echo ""
    echo "❌ 存在未满足的依赖，请安装缺失的依赖后再尝试构建"
    exit 1
fi
