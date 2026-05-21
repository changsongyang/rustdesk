#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

show_help() {
    cat << EOF
RustDesk Rust/Cargo 镜像配置脚本

用法: $0 [镜像源]

可用镜像源:
    rsproxy      Rsproxy 镜像（推荐，默认）
    ustc         中科大镜像
    tuna         清华大学镜像
    aliyun       阿里云镜像
    tuna-git     清华大学 Git 索引方式
    auto         自动选择最优镜像（需先运行测速）

选项:
    -s, --show       显示当前配置
    -r, --reset      重置为默认源（crates.io）
    -t, --test       测试镜像源可用性
    -h, --help       显示帮助信息

示例:
    $0                  # 使用 Rsproxy 镜像
    $0 rsproxy          # 使用 Rsproxy 镜像
    $0 ustc             # 使用中科大镜像
    $0 --show           # 显示当前配置
    $0 --reset          # 重置为默认源

EOF
}

show_current_config() {
    local cargo_config="${HOME}/.cargo/config.toml"
    
    if [ -f "$cargo_config" ]; then
        echo -e "${BLUE}当前 Cargo 配置:${NC}"
        echo -e "${YELLOW}========================================${NC}"
        cat "$cargo_config"
        echo -e "${YELLOW}========================================${NC}"
    else
        echo -e "${RED}未找到 Cargo 配置文件: ${cargo_config}${NC}"
    fi
}

test_mirror() {
    local url=$1
    local name=$2
    
    echo -n "Testing ${name} (${url})... "
    
    if curl -I --connect-timeout 5 -m 10 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}Failed${NC}"
        return 1
    fi
}

configure_rustup_mirror() {
    local mirror=$1
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    
    case "$mirror" in
        rsproxy)
            export RUSTUP_DIST_SERVER="https://rsproxy.cn"
            export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
            ;;
        ustc)
            export RUSTUP_DIST_SERVER="https://mirrors.ustc.edu.cn/rust-static"
            export RUSTUP_UPDATE_ROOT="https://mirrors.ustc.edu.cn/rust-static"
            ;;
        tuna)
            export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
            export RUSTUP_UPDATE_ROOT="https://mirrors.tuna.tsinghua.edu.cn/rustup"
            ;;
        aliyun)
            export RUSTUP_DIST_SERVER="https://mirrors.aliyun.com/rustup"
            export RUSTUP_UPDATE_ROOT="https://mirrors.aliyun.com/rustup"
            ;;
        *)
            echo -e "${RED}未知的镜像源: ${mirror}${NC}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}已设置 Rustup 镜像源: ${mirror}${NC}"
}

configure_cargo_sparse() {
    local mirror=$1
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    local config_dir="${cargo_home}"
    local config_file="${config_dir}/config.toml"
    
    case "$mirror" in
        rsproxy)
            registry_url="sparse+https://rsproxy.cn/index/"
            ;;
        ustc)
            registry_url="sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
            ;;
        tuna)
            registry_url="sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"
            ;;
        aliyun)
            registry_url="sparse+https://mirrors.aliyun.com/crates.io-index/"
            ;;
        *)
            echo -e "${RED}未知的镜像源: ${mirror}${NC}"
            return 1
            ;;
    esac
    
    mkdir -p "$config_dir"
    
    cat > "$config_file" << EOF
[source.crates-io]
replace-with = 'mirror'

[source.mirror]
registry = "${registry_url}"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"

[source.tuna]
registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"

[source.aliyun]
registry = "sparse+https://mirrors.aliyun.com/crates.io-index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[net]
git-fetch-with-cli = true

[build]
jobs = 4

[term]
verbose = false
EOF
    
    echo -e "${GREEN}Cargo 配置已更新: ${config_file}${NC}"
    echo -e "${GREEN}使用稀疏索引: ${registry_url}${NC}"
}

configure_cargo_git() {
    local mirror=$1
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    local config_dir="${cargo_home}"
    local config_file="${config_dir}/config.toml"
    
    case "$mirror" in
        rsproxy)
            registry_url="https://rsproxy.cn/crates.io-index"
            ;;
        ustc)
            registry_url="https://mirrors.ustc.edu.cn/crates.io-index"
            ;;
        tuna)
            registry_url="https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index"
            ;;
        aliyun)
            registry_url="https://mirrors.aliyun.com/git/crates.io-index"
            ;;
        *)
            echo -e "${RED}未知的镜像源: ${mirror}${NC}"
            return 1
            ;;
    esac
    
    mkdir -p "$config_dir"
    
    cat > "$config_file" << EOF
[source.crates-io]
replace-with = 'mirror'

[source.mirror]
registry = "${registry_url}"

[net]
git-fetch-with-cli = true

[build]
jobs = 4

[term]
verbose = false
EOF
    
    echo -e "${GREEN}Cargo 配置已更新: ${config_file}${NC}"
    echo -e "${GREEN}使用 Git 索引: ${registry_url}${NC}"
}

reset_config() {
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    local config_file="${cargo_home}/config.toml"
    
    if [ -f "$config_file" ]; then
        rm -f "$config_file"
        echo -e "${GREEN}已删除 Cargo 配置文件${NC}"
    else
        echo -e "${YELLOW}Cargo 配置文件不存在，无需重置${NC}"
    fi
    
    unset RUSTUP_DIST_SERVER
    unset RUSTUP_UPDATE_ROOT
    unset CARGO_REGISTRIES_CRATES_IO_PROTOCOL
    
    echo -e "${GREEN}已重置环境变量${NC}"
}

test_all_mirrors() {
    echo -e "${BLUE}测试 Cargo 镜像源可用性:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    test_mirror "https://rsproxy.cn/index/" "Rsproxy"
    test_mirror "https://mirrors.ustc.edu.cn/crates.io-index/" "中科大"
    test_mirror "https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/" "清华大学"
    test_mirror "https://mirrors.aliyun.com/crates.io-index/" "阿里云"
    
    echo ""
    
    local cargo_home="${CARGO_HOME:-$HOME/.cargo}"
    if command -v cargo &> /dev/null; then
        echo -e "${BLUE}测试 Cargo 下载（测试包：clap）:${NC}"
        cd /tmp
        rm -rf cargo_test 2>/dev/null || true
        mkdir cargo_test && cd cargo_test
        if timeout 60 cargo new test_project > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Cargo 工作正常${NC}"
        else
            echo -e "${RED}✗ Cargo 配置可能有问题${NC}"
        fi
        cd /tmp
        rm -rf cargo_test 2>/dev/null || true
    else
        echo -e "${YELLOW}Cargo 未安装，跳过测试${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
}

main() {
    local mirror="${1:-rsproxy}"
    local use_sparse=true
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--show)
                show_current_config
                exit 0
                ;;
            -r|--reset)
                reset_config
                exit 0
                ;;
            -t|--test)
                test_all_mirrors
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -sparse|--sparse)
                use_sparse=true
                shift
                ;;
            -git|--git)
                use_sparse=false
                shift
                ;;
            rsproxy|ustc|tuna|aliyun|tuna-git|auto)
                mirror="$1"
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项或镜像源 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$mirror" = "auto" ]; then
        echo -e "${BLUE}自动选择最优镜像源...${NC}"
        if [ -f "/tmp/mirror_test_results.txt" ]; then
            mirror=$(sort -t'|' -k2 -n /tmp/mirror_test_results.txt | head -n 1 | cut -d'|' -f1)
            echo -e "${GREEN}选择: ${mirror}${NC}"
        else
            echo -e "${YELLOW}未找到测速结果，使用默认镜像 rsproxy${NC}"
            mirror="rsproxy"
        fi
    fi
    
    if [ "$mirror" = "tuna-git" ]; then
        use_sparse=false
        mirror="tuna"
    fi
    
    echo -e "${BLUE}配置 Rust/Cargo 镜像源: ${mirror}${NC}"
    
    configure_rustup_mirror "$mirror"
    
    if [ "$use_sparse" = true ]; then
        configure_cargo_sparse "$mirror"
    else
        configure_cargo_git "$mirror"
    fi
    
    echo ""
    echo -e "${GREEN}✓ 配置完成！${NC}"
    echo ""
    echo -e "${BLUE}测试配置是否生效:${NC}"
    test_all_mirrors
}

main "$@"
