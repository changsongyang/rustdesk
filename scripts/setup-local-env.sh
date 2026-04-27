#!/bin/bash
# RustDesk 本地环境配置脚本
# 此脚本用于配置本地开发环境，确保与CI环境一致

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 版本配置（与CI环境一致）
RUST_VERSION="1.95"
FLUTTER_VERSION="3.24.5"
FLUTTER_RUST_BRIDGE_VERSION="1.80.1"
VCPKG_COMMIT_ID="120deac3062162151622ca4860575a33844ba10b"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RustDesk 本地环境配置脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查操作系统
echo -e "${YELLOW}检查操作系统...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    OS="Windows"
else
    echo -e "${RED}不支持的操作系统: $OSTYPE${NC}"
    exit 1
fi
echo -e "${GREEN}检测到操作系统: $OS${NC}"

# 检查并安装 Rust
echo -e "${YELLOW}检查 Rust 安装...${NC}"
if command -v rustup &> /dev/null; then
    CURRENT_RUST_VERSION=$(rustc --version | grep -oP '\d+\.\d+' | head -1)
    echo -e "${GREEN}已安装 Rust: $(rustc --version)${NC}"
    
    # 检查是否需要切换到指定版本
    if [[ "$CURRENT_RUST_VERSION" != "$RUST_VERSION" ]]; then
        echo -e "${YELLOW}需要切换到 Rust $RUST_VERSION...${NC}"
        rustup install $RUST_VERSION
        rustup default $RUST_VERSION
    fi
else
    echo -e "${YELLOW}未检测到 Rust，正在安装...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    rustup install $RUST_VERSION
    rustup default $RUST_VERSION
fi

# 检查并安装 Flutter
echo -e "${YELLOW}检查 Flutter 安装...${NC}"
if command -v flutter &> /dev/null; then
    CURRENT_FLUTTER_VERSION=$(flutter --version | grep -oP 'Flutter \K[\d.]+' | head -1)
    echo -e "${GREEN}已安装 Flutter: $(flutter --version)${NC}"
    
    # 注意：Flutter版本检查可能不精确，这里只做提示
    if [[ "$CURRENT_FLUTTER_VERSION" != "$FLUTTER_VERSION" ]]; then
        echo -e "${YELLOW}建议使用 Flutter $FLUTTER_VERSION (当前: $CURRENT_FLUTTER_VERSION)${NC}"
    fi
else
    echo -e "${YELLOW}未检测到 Flutter，正在安装...${NC}"
    
    # 根据操作系统选择安装方式
    if [[ "$OS" == "macOS" ]]; then
        brew install flutter
    elif [[ "$OS" == "Linux" ]]; then
        git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
        export PATH="$HOME/flutter/bin:$PATH"
    elif [[ "$OS" == "Windows" ]]; then
        echo -e "${RED}Windows 请从 https://flutter.dev/docs/get-started/install/windows 下载 Flutter${NC}"
        exit 1
    fi
    
    flutter doctor
fi

# 检查并安装 Python
echo -e "${YELLOW}检查 Python 安装...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | grep -oP '\d+\.\d+' | head -1)
    echo -e "${GREEN}已安装 Python: $(python3 --version)${NC}"
    
    # 检查 Python 版本是否满足要求 (>=3.8)
    PYTHON_MAJOR=$(python3 --version | grep -oP '\d+' | head -1)
    if [[ "$PYTHON_MAJOR" -lt 3 ]]; then
        echo -e "${RED}需要 Python 3.x，当前版本不满足要求${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}未检测到 Python3，正在安装...${NC}"
    
    if [[ "$OS" == "macOS" ]]; then
        brew install python3
    elif [[ "$OS" == "Linux" ]]; then
        sudo apt-get update && sudo apt-get install -y python3 python3-pip
    elif [[ "$OS" == "Windows" ]]; then
        echo -e "${RED}Windows 请从 https://www.python.org/downloads/ 下载 Python${NC}"
        exit 1
    fi
fi

# 检查并安装 vcpkg
echo -e "${YELLOW}检查 vcpkg 安装...${NC}"
if [ -d "$HOME/vcpkg" ]; then
    echo -e "${GREEN}已安装 vcpkg${NC}"
    echo -e "${YELLOW}检查 vcpkg 版本...${NC}"
    cd "$HOME/vcpkg" && git fetch origin && git checkout $VCPKG_COMMIT_ID
else
    echo -e "${YELLOW}未检测到 vcpkg，正在安装...${NC}"
    cd "$HOME"
    git clone https://github.com/microsoft/vcpkg.git
    cd vcpkg
    git checkout $VCPKG_COMMIT_ID
    
    # 根据操作系统执行安装脚本
    if [[ "$OS" == "Windows" ]]; then
        ./bootstrap-vcpkg.bat
    else
        ./bootstrap-vcpkg.sh
    fi
fi

# 设置环境变量
echo -e "${YELLOW}配置环境变量...${NC}"
export VCPKG_ROOT="$HOME/vcpkg"
export VCPKG_INSTALL_ROOT="$HOME/vcpkg/installed"

# 添加到 shell 配置文件
SHELL_CONFIG=""
if [[ "$OS" == "macOS" ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$OS" == "Linux" ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [[ "$OS" == "Windows" ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
fi

# 添加环境变量到 shell 配置
if [ -n "$SHELL_CONFIG" ]; then
    echo "" >> "$SHELL_CONFIG"
    echo "# RustDesk 环境变量" >> "$SHELL_CONFIG"
    echo "export VCPKG_ROOT=\"$HOME/vcpkg\"" >> "$SHELL_CONFIG"
    echo "export VCPKG_INSTALL_ROOT=\"$HOME/vcpkg/installed\"" >> "$SHELL_CONFIG"
    echo -e "${GREEN}环境变量已添加到 $SHELL_CONFIG${NC}"
fi

# 验证安装
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  环境配置验证${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "${YELLOW}验证 Rust...${NC}"
rustc --version
cargo --version

echo -e "${YELLOW}验证 Flutter...${NC}"
flutter --version

echo -e "${YELLOW}验证 Python...${NC}"
python3 --version

echo -e "${YELLOW}验证 vcpkg...${NC}"
"$HOME/vcpkg/vcpkg" version

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  本地环境配置完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}下一步：${NC}"
echo -e "1. 运行 'source ~/.cargo/env' 加载环境变量"
echo -e "2. 运行 'vcpkg install' 安装项目依赖"
echo -e "3. 运行 './build.py --flutter' 构建项目"
