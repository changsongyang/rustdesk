#!/bin/bash

# RustDesk 工具链验证脚本
# 验证 Rust 工具链和 vcpkg 完整性

set -e

echo "=========================================="
echo "RustDesk 工具链验证"
echo "=========================================="
echo ""

SUCCESS_COUNT=0
FAILURE_COUNT=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_command() {
    local cmd=$1
    local name=$2
    
    echo -n "✓ 检查 ${name}..."
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>/dev/null | head -n 1 | cut -d' ' -f2)
        echo -e "${GREEN} 已安装 (版本: ${version:-未知})${NC}"
        ((SUCCESS_COUNT++))
        return 0
    else
        echo -e "${RED} 未安装${NC}"
        ((FAILURE_COUNT++))
        return 1
    fi
}

# 检查文件
check_file() {
    local file=$1
    local name=$2
    
    echo -n "✓ 检查 ${name}..."
    if [ -f "$file" ]; then
        echo -e "${GREEN} 存在${NC}"
        ((SUCCESS_COUNT++))
        return 0
    else
        echo -e "${RED} 不存在${NC}"
        ((FAILURE_COUNT++))
        return 1
    fi
}

# 检查目录
check_dir() {
    local dir=$1
    local name=$2
    
    echo -n "✓ 检查 ${name}..."
    if [ -d "$dir" ]; then
        echo -e "${GREEN} 存在${NC}"
        ((SUCCESS_COUNT++))
        return 0
    else
        echo -e "${RED} 不存在${NC}"
        ((FAILURE_COUNT++))
        return 1
    fi
}

# 检查 Rust 工具链
echo ""
echo "【Rust 工具链检查】"
check_command "rustc" "Rust 编译器"
check_command "cargo" "Cargo 包管理器"
check_command "rustfmt" "Rust 格式化工具"
check_command "clippy-driver" "Clippy 代码检查"

# 检查 rust-src
echo -n "✓ 检查 rust-src..."
if rustc --print sysroot | xargs -I{} ls {}/lib/rustlib/src/rust/Cargo.toml &> /dev/null; then
    echo -e "${GREEN} 已安装${NC}"
    ((SUCCESS_COUNT++))
else
    echo -e "${YELLOW} 未安装 (建议安装)${NC}"
    echo "   安装命令: rustup component add rust-src"
    ((SUCCESS_COUNT++))
fi

# 检查 vcpkg
echo ""
echo "【vcpkg 检查】"
if [ -n "$VCPKG_ROOT" ]; then
    check_dir "$VCPKG_ROOT" "VCPKG_ROOT 目录"
    check_file "$VCPKG_ROOT/vcpkg" "vcpkg 可执行文件"
else
    echo -e "${YELLOW}⚠️  VCPKG_ROOT 未设置${NC}"
    ((SUCCESS_COUNT++))
fi

# 检查构建工具
echo ""
echo "【构建工具检查】"
check_command "cmake" "CMake"
check_command "ninja" "Ninja"
check_command "pkg-config" "pkg-config"
check_command "git" "Git"

# 检查系统工具
echo ""
echo "【系统工具检查】"
check_command "python3" "Python 3"
check_command "pip3" "pip3"

# 检查可选工具
echo ""
echo "【可选工具检查】"
check_command "cargo-audit" "cargo-audit (安全扫描)"
check_command "cargo-outdated" "cargo-outdated (依赖更新检查)"

# 检查关键库文件
echo ""
echo "【关键库检查】"

# 检查 FFmpeg 相关
echo -n "✓ 检查 FFmpeg 库..."
if pkg-config --exists libavcodec 2>/dev/null || [ -f "/usr/lib/libavcodec.so" ]; then
    echo -e "${GREEN} 已安装${NC}"
    ((SUCCESS_COUNT++))
else
    echo -e "${YELLOW} 未安装 (将通过 vcpkg 安装)${NC}"
    ((SUCCESS_COUNT++))
fi

# 检查 GTK
echo -n "✓ 检查 GTK 库..."
if pkg-config --exists gtk+-3.0 2>/dev/null; then
    echo -e "${GREEN} 已安装${NC}"
    ((SUCCESS_COUNT++))
else
    echo -e "${RED} 未安装${NC}"
    ((FAILURE_COUNT++))
fi

# 输出总结
echo ""
echo "=========================================="
echo "验证总结"
echo "=========================================="
echo "通过: ${SUCCESS_COUNT}"
echo "失败: ${FAILURE_COUNT}"

if [ $FAILURE_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ 所有工具链验证通过!${NC}"
    echo ""
    echo "建议执行以下命令验证构建:"
    echo "  cargo check --features flutter"
    exit 0
else
    echo ""
    echo -e "${RED}❌ 存在未满足的依赖，请安装缺失的组件后再尝试构建${NC}"
    exit 1
fi
