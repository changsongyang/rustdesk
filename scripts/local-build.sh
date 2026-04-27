#!/bin/bash
# RustDesk 本地构建脚本
# 此脚本用于在本地环境中构建 RustDesk，与 CI 环境保持一致

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 构建参数
BUILD_TYPE="release"
EXTRA_ARGS=""
SKIP_DEPENDENCIES=false
SKIP_ENV_CHECK=false

# 解析参数
usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --flutter          构建 Flutter UI (默认)"
    echo "  --release         构建 release 版本 (默认)"
    echo "  --debug           构建 debug 版本"
    echo "  --skip-deps       跳过依赖安装"
    echo "  --skip-env-check  跳过环境检查"
    echo "  --help            显示帮助信息"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --flutter)
            EXTRA_ARGS="$EXTRA_ARGS --flutter"
            shift
            ;;
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --skip-deps)
            SKIP_DEPENDENCIES=true
            shift
            ;;
        --skip-env-check)
            SKIP_ENV_CHECK=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            usage
            ;;
    esac
done

# 记录开始时间
START_TIME=$(date +%s)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RustDesk 本地构建脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}开始时间: $(date)${NC}"
echo -e "${BLUE}构建类型: $BUILD_TYPE${NC}"

# 1. 环境检查
if [ "$SKIP_ENV_CHECK" = false ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}1. 检查构建环境${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # 检查必需工具
    for cmd in rustc cargo flutter python3; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}[ERROR] $cmd 未安装${NC}"
            exit 1
        fi
        echo -e "${GREEN}[OK]${NC} $cmd: $(which $cmd)"
    done
    
    # 显示版本信息
    echo -e "${YELLOW}环境版本信息:${NC}"
    rustup -V
    cargo -V
    flutter --version 2>/dev/null || echo "Flutter 未安装或版本不可用"
    python3 --version
    
    # 检查 vcpkg
    if [ -z "$VCPKG_ROOT" ]; then
        echo -e "${RED}[ERROR] VCPKG_ROOT 环境变量未设置${NC}"
        echo -e "${YELLOW}请运行: export VCPKG_ROOT=\"\$HOME/vcpkg\"${NC}"
        exit 1
    fi
    echo -e "${GREEN}[OK]${NC} VCPKG_ROOT: $VCPKG_ROOT"
else
    echo -e "${YELLOW}跳过环境检查${NC}"
fi

# 2. 安装依赖
if [ "$SKIP_DEPENDENCIES" = false ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}2. 安装项目依赖${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    # 安装 Rust 依赖
    echo -e "${BLUE}安装 Rust 依赖...${NC}"
    cargo fetch || echo -e "${YELLOW}[WARN] cargo fetch 失败，继续构建...${NC}"
    
    # 安装 Flutter 依赖
    if command -v flutter &> /dev/null; then
        echo -e "${BLUE}安装 Flutter 依赖...${NC}"
        cd flutter && flutter pub get || echo -e "${YELLOW}[WARN] flutter pub get 失败，继续构建...${NC}"
        cd ..
    fi
    
    # 安装 vcpkg 依赖
    echo -e "${BLUE}安装 vcpkg 依赖...${NC}"
    if [ -f "vcpkg.json" ]; then
        "$VCPKG_ROOT/vcpkg install" || echo -e "${YELLOW}[WARN] vcpkg install 失败，继续构建...${NC}"
    fi
else
    echo -e "${YELLOW}跳过依赖安装${NC}"
fi

# 3. 生成内联资源
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}3. 生成内联资源${NC}"
echo -e "${YELLOW}========================================${NC}"
if [ -f "res/inline-sciter.py" ]; then
    echo -e "${BLUE}运行 inline-sciter.py...${NC}"
    python3 res/inline-sciter.py || echo -e "${YELLOW}[WARN] inline-sciter.py 失败，继续构建...${NC}"
else
    echo -e "${YELLOW}[INFO] inline-sciter.py 不存在，跳过${NC}"
fi

# 4. 执行构建
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}4. 执行构建${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}运行构建脚本...${NC}"

# 设置错误捕获
set -x
trap 'echo -e "${RED}构建失败！${NC}"; echo -e "${RED}错误位置: 行 $LINENO${NC}"; exit 1' ERR

# 执行构建
if [ -f "build.py" ]; then
    python3 build.py $EXTRA_ARGS || {
        echo -e "${RED}构建脚本执行失败！${NC}"
        echo -e "${YELLOW}诊断信息:${NC}"
        echo "磁盘空间:"
        df -h | grep -E '(Filesystem|/dev/)'
        echo ""
        echo "target 目录大小:"
        du -sh target 2>/dev/null || echo "target 目录不存在"
        exit 1
    }
else
    # 如果 build.py 不存在，尝试直接使用 cargo 构建
    echo -e "${YELLOW}[INFO] build.py 不存在，使用 cargo 直接构建${NC}"
    cargo build --$BUILD_TYPE || {
        echo -e "${RED}cargo build 失败！${NC}"
        exit 1
    }
fi

set +x

# 5. 验证构建结果
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}5. 验证构建结果${NC}"
echo -e "${YELLOW}========================================${NC}"

BUILD_SUCCESS=false

# 检查 macOS 构建产物
if [ -d "flutter/build/macos/Build/Products/Release" ]; then
    echo -e "${GREEN}[OK]${NC} macOS 构建产物目录存在"
    if [ -d "flutter/build/macos/Build/Products/Release/RustDesk.app" ]; then
        echo -e "${GREEN}[OK]${NC} RustDesk.app 存在"
        BUILD_SUCCESS=true
    fi
fi

# 检查 Cargo 构建产物
if [ -d "target/$BUILD_TYPE" ]; then
    echo -e "${GREEN}[OK]${NC} Cargo 目标目录存在: target/$BUILD_TYPE"
    if [ -f "target/$BUILD_TYPE/rustdesk" ] || [ -f "target/$BUILD_TYPE/rustdesk.exe" ]; then
        echo -e "${GREEN}[OK]${NC} RustDesk 可执行文件存在"
        BUILD_SUCCESS=true
    fi
fi

# 计算构建时间
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED_TIME / 60))
SECONDS=$((ELAPSED_TIME % 60))

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  构建完成${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}结束时间: $(date)${NC}"
echo -e "${BLUE}总耗时: ${MINUTES}分${SECONDS}秒${NC}"

if [ "$BUILD_SUCCESS" = true ]; then
    echo -e "${GREEN}构建状态: 成功${NC}"
    exit 0
else
    echo -e "${YELLOW}构建状态: 部分成功（请检查上述输出）${NC}"
    exit 0
fi
