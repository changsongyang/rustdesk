#!/bin/bash
# RustDesk 环境一致性检查脚本
# 此脚本用于验证本地环境与CI环境的一致性

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# CI环境版本配置
CI_RUST_VERSION="1.95"
CI_FLUTTER_VERSION="3.24.5"
CI_VCPKG_COMMIT_ID="120deac3062162151622ca4860575a33844ba10b"

# 检查结果计数
PASS_COUNT=0
FAIL_COUNT=0

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RustDesk 环境一致性检查${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查函数
check_version() {
    local name=$1
    local expected=$2
    local actual=$3
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}[PASS]${NC} $name: $actual (预期: $expected)"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name: $actual (预期: $expected)"
        ((FAIL_COUNT++))
        return 1
    fi
}

check_command() {
    local name=$1
    local cmd=$2
    
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}[PASS]${NC} $name 已安装"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name 未安装"
        ((FAIL_COUNT++))
        return 1
    fi
}

check_directory() {
    local name=$1
    local path=$2
    
    if [ -d "$path" ]; then
        echo -e "${GREEN}[PASS]${NC} $name 目录存在: $path"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name 目录不存在: $path"
        ((FAIL_COUNT++))
        return 1
    fi
}

check_file() {
    local name=$1
    local path=$2
    
    if [ -f "$path" ]; then
        echo -e "${GREEN}[PASS]${NC} $name 文件存在: $path"
        ((PASS_COUNT++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name 文件不存在: $path"
        ((FAIL_COUNT++))
        return 1
    fi
}

# 1. 检查必需工具
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}1. 检查必需工具${NC}"
echo -e "${YELLOW}========================================${NC}"

check_command "Rust" "rustc"
check_command "Cargo" "cargo"
check_command "Flutter" "flutter"
check_command "Python3" "python3"

# 2. 检查版本一致性
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}2. 检查版本一致性${NC}"
echo -e "${YELLOW}========================================${NC}"

if command -v rustc &> /dev/null; then
    LOCAL_RUST_VERSION=$(rustc --version | grep -oP '\d+\.\d+' | head -1)
    check_version "Rust 版本" "$CI_RUST_VERSION" "$LOCAL_RUST_VERSION"
fi

if command -v flutter &> /dev/null; then
    LOCAL_FLUTTER_VERSION=$(flutter --version | grep -oP 'Flutter \K[\d.]+' | head -1)
    # Flutter版本检查（允许小版本差异）
    FLUTTER_MAJOR_MINOR=$(echo $LOCAL_FLUTTER_VERSION | cut -d. -f1,2)
    CI_FLUTTER_MAJOR_MINOR=$(echo $CI_FLUTTER_VERSION | cut -d. -f1,2)
    if [[ "$FLUTTER_MAJOR_MINOR" == "$CI_FLUTTER_MAJOR_MINOR" ]]; then
        echo -e "${GREEN}[PASS]${NC} Flutter 版本: $LOCAL_FLUTTER_VERSION (预期: $CI_FLUTTER_VERSION) - 主版本一致"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} Flutter 版本: $LOCAL_FLUTTER_VERSION (预期: $CI_FLUTTER_VERSION) - 主版本不一致"
        ((FAIL_COUNT++))
    fi
fi

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    if [[ "$PYTHON_MAJOR" -ge 3 ]]; then
        echo -e "${GREEN}[PASS]${NC} Python 版本: $PYTHON_VERSION (满足 Python 3.x 要求)"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} Python 版本: $PYTHON_VERSION (需要 Python 3.x)"
        ((FAIL_COUNT++))
    fi
fi

# 3. 检查vcpkg
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}3. 检查 vcpkg${NC}"
echo -e "${YELLOW}========================================${NC}"

if [ -n "$VCPKG_ROOT" ]; then
    check_directory "VCPKG_ROOT" "$VCPKG_ROOT"
    
    if [ -d "$VCPKG_ROOT/.git" ]; then
        cd "$VCPKG_ROOT"
        VCPKG_CURRENT_COMMIT=$(git rev-parse HEAD)
        if [[ "$VCPKG_CURRENT_COMMIT" == "$CI_VCPKG_COMMIT_ID" ]]; then
            echo -e "${GREEN}[PASS]${NC} vcpkg 提交ID: $VCPKG_CURRENT_COMMIT (预期: $CI_VCPKG_COMMIT_ID)"
            ((PASS_COUNT++))
        else
            echo -e "${YELLOW}[WARN]${NC} vcpkg 提交ID: $VCPKG_CURRENT_COMMIT (预期: $CI_VCPKG_COMMIT_ID)"
            echo -e "${YELLOW}      建议运行 'git checkout $CI_VCPKG_COMMIT_ID' 切换到正确版本${NC}"
            ((PASS_COUNT++))
        fi
    fi
else
    echo -e "${YELLOW}[WARN]${NC} VCPKG_ROOT 环境变量未设置"
    echo -e "${YELLOW}      建议设置: export VCPKG_ROOT=\"\$HOME/vcpkg\"${NC}"
fi

# 4. 检查项目依赖
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}4. 检查项目依赖${NC}"
echo -e "${YELLOW}========================================${NC}"

check_file "vcpkg.json" "vcpkg.json"
check_file "Cargo.toml" "Cargo.toml"
check_file "flutter/pubspec.yaml" "flutter/pubspec.yaml"

# 5. 检查关键配置文件
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}5. 检查关键配置文件${NC}"
echo -e "${YELLOW}========================================${NC}"

check_directory ".github/workflows" ".github/workflows"
check_directory "res/vcpkg" "res/vcpkg"
check_file "build.py" "build.py"

# 6. 检查构建输出目录
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}6. 检查构建目录${NC}"
echo -e "${YELLOW}========================================${NC}"

if [ -d "flutter/build" ]; then
    echo -e "${GREEN}[INFO]${NC} Flutter 构建目录存在: flutter/build"
else
    echo -e "${YELLOW}[INFO]${NC} Flutter 构建目录不存在（首次构建前正常）"
fi

if [ -d "target" ]; then
    echo -e "${GREEN}[INFO]${NC} Cargo 目标目录存在: target"
else
    echo -e "${YELLOW}[INFO]${NC} Cargo 目标目录不存在（首次构建前正常）"
fi

# 总结
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  检查结果总结${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "通过: ${GREEN}$PASS_COUNT${NC}"
echo -e "失败: ${RED}$FAIL_COUNT${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  所有检查通过！环境配置正确${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  存在 $FAIL_COUNT 个问题，请检查上述失败项${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
