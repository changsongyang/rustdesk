#!/bin/bash

# RustDesk Rust 版本验证脚本
# 用于验证构建环境使用正确的 Rust 版本

set -e

echo "=========================================="
echo "RustDesk Rust 版本验证"
echo "=========================================="

# 读取 rust-toolchain.toml 中的版本
EXPECTED_VERSION=$(grep -A 1 '^\[toolchain\]' rust-toolchain.toml | grep 'channel' | cut -d'"' -f2)
EXPECTED_VERSION=${EXPECTED_VERSION:-"1.81"}

echo "期望的 Rust 版本: ${EXPECTED_VERSION}"
echo ""

# 检查 Rust 是否已安装
if ! command -v rustc &> /dev/null; then
    echo "❌ Rust 未安装"
    exit 1
fi

# 获取当前 Rust 版本
CURRENT_VERSION=$(rustc --version | grep -oP '\d+\.\d+\.\d+' | head -1)

echo "当前 Rust 版本: ${CURRENT_VERSION}"

# 比较版本
if [ "$CURRENT_VERSION" == "$EXPECTED_VERSION" ]; then
    echo ""
    echo "✅ Rust 版本匹配!"
    echo ""
    echo "=== Rust 工具链信息 ==="
    rustc --version
    cargo --version
    echo ""
    exit 0
else
    echo ""
    echo "❌ Rust 版本不匹配!"
    echo "期望: ${EXPECTED_VERSION}"
    echo "当前: ${CURRENT_VERSION}"
    echo ""
    echo "建议：运行以下命令安装正确版本"
    echo "  rustup install ${EXPECTED_VERSION}"
    echo "  rustup default ${EXPECTED_VERSION}"
    echo ""
    exit 1
fi
