#!/bin/bash
set -e

# RustDesk 构建环境验证脚本
# 用于 CI 环境中的快速验证

REQUIRED_RUST_VERSION="1.95"
ERROR_COUNT=0
WARNING_COUNT=0

echo "========================================"
echo "    RustDesk CI 环境验证脚本"
echo "========================================"
echo ""

# 检查 Rust 版本
echo "🔧 检查 Rust 版本..."
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version | awk '{print $2}')
    echo "   当前 Rust 版本: $RUST_VERSION"
    
    if [[ "$RUST_VERSION" == "$REQUIRED_RUST_VERSION"* ]]; then
        echo "   ✅ Rust 版本符合要求"
    else
        echo "   ❌ Rust 版本不满足要求: 需要 $REQUIRED_RUST_VERSION, 当前 $RUST_VERSION"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
else
    echo "   ❌ Rust 未安装"
    ERROR_COUNT=$((ERROR_COUNT + 1))
fi

echo ""

# 检查 Cargo
echo "🔧 检查 Cargo..."
if command -v cargo &> /dev/null; then
    CARGO_VERSION=$(cargo --version | awk '{print $2}')
    echo "   Cargo 版本: $CARGO_VERSION"
    echo "   ✅ Cargo 已安装"
else
    echo "   ❌ Cargo 未安装"
    ERROR_COUNT=$((ERROR_COUNT + 1))
fi

echo ""

# 检查 vcpkg
echo "🔧 检查 vcpkg..."
if [ -n "$VCPKG_ROOT" ]; then
    echo "   VCPKG_ROOT: $VCPKG_ROOT"
    if [ -d "$VCPKG_ROOT" ]; then
        echo "   ✅ vcpkg 目录存在"
    else
        echo "   ❌ vcpkg 目录不存在: $VCPKG_ROOT"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
else
    echo "   ⚠️  VCPKG_ROOT 未设置"
    WARNING_COUNT=$((WARNING_COUNT + 1))
fi

echo ""

# 检查系统工具
echo "🔧 检查系统工具..."
TOOLS=("git" "curl" "python3" "cmake" "ninja")

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "   ✅ $tool 已安装"
    else
        echo "   ❌ $tool 未安装"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
done

echo ""

# 检查磁盘空间
echo "🔧 检查磁盘空间..."
if command -v df &> /dev/null; then
    DISK_AVAIL=$(df -h / | tail -1 | awk '{print $4}')
    DISK_USE=$(df -h / | tail -1 | awk '{print $5}')
    echo "   可用空间: $DISK_AVAIL, 使用率: $DISK_USE"
    
    # 检查是否有至少 10GB 可用空间
    DISK_AVAIL_KB=$(df -k / | tail -1 | awk '{print $4}')
    if [ "$DISK_AVAIL_KB" -lt 10485760 ]; then
        echo "   ⚠️  磁盘空间不足，建议至少 10GB 可用空间"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    else
        echo "   ✅ 磁盘空间充足"
    fi
else
    echo "   ⚠️  无法检查磁盘空间"
    WARNING_COUNT=$((WARNING_COUNT + 1))
fi

echo ""

# 检查内存
echo "🔧 检查内存..."
if command -v free &> /dev/null; then
    MEM_AVAIL=$(free -h | grep Mem | awk '{print $7}')
    MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
    echo "   总内存: $MEM_TOTAL, 可用: $MEM_AVAIL"
else
    echo "   ⚠️  无法检查内存"
    WARNING_COUNT=$((WARNING_COUNT + 1))
fi

echo ""

# 输出结果
echo "========================================"
echo "                  验证结果"
echo "========================================"

if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
    echo "✅ 所有检查通过！"
    exit 0
elif [ "$ERROR_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -gt 0 ]; then
    echo "⚠️  检查通过，但有 $WARNING_COUNT 个警告"
    exit 0
else
    echo "❌ 发现 $ERROR_COUNT 个错误，构建环境未就绪"
    exit 1
fi