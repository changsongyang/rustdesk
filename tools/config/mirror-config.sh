#!/bin/bash

declare -A CARGO_MIRRORS=(
    ["rsproxy"]="sparse+https://rsproxy.cn/index/"
    ["ustc"]="sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
    ["tuna"]="sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"
    ["aliyun"]="sparse+https://mirrors.aliyun.com/crates.io-index/"
)

declare -A CARGO_GIT_MIRRORS=(
    ["rsproxy"]="https://rsproxy.cn/crates.io-index"
    ["ustc"]="https://mirrors.ustc.edu.cn/crates.io-index"
    ["tuna"]="https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index"
    ["aliyun"]="https://mirrors.aliyun.com/git/crates.io-index"
)

declare -A DOCKER_MIRRORS=(
    ["aliyun"]="https://your-id.mirror.aliyuncs.com"
    ["tencent"]="https://mirror.ccs.tencentyun.com"
    ["daocloud"]="https://docker.m.daocloud.io"
    ["ustc"]="https://docker.mirrors.ustc.edu.cn"
    ["rainbond"]="https://docker.rainbond.cc"
)

declare -A GITHUB_MIRRORS=(
    ["fastgit"]="https://hub.fastgit.xyz/"
    ["ghproxy"]="https://ghproxy.com/"
    ["gitclone"]="https://gitclone.com/github.com/"
    ["ghpig"]="https://ghproxy.cn/"
)

declare -A FLUTTER_MIRRORS=(
    ["official"]="https://pub.flutter-io.cn"
    ["tuna"]="https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
)

RUSTUP_MIRRORS=(
    ["rsproxy"]="https://rsproxy.cn"
    ["ustc"]="https://mirrors.ustc.edu.cn/rust-static"
    ["tuna"]="https://mirrors.tuna.tsinghua.edu.cn/rustup"
    ["aliyun"]="https://mirrors.aliyun.com/rustup"
)

DEFAULT_CARGO_MIRROR="rsproxy"
DEFAULT_DOCKER_MIRROR="daocloud"
DEFAULT_GITHUB_MIRROR="fastgit"
DEFAULT_FLUTTER_MIRROR="official"

CARGO_CONFIG_DIR="${CARGO_HOME:-$HOME/.cargo}"
CARGO_CONFIG_FILE="${CARGO_CONFIG_DIR}/config.toml"

DOCKER_CONFIG_PATH=""
GIT_CONFIG_PATH="$HOME/.gitconfig"
SSH_CONFIG_PATH="$HOME/.ssh/config"

get_docker_config_path() {
    local os=$(uname -s)
    case "$os" in
        Linux*)
            DOCKER_CONFIG_PATH="/etc/docker/daemon.json"
            ;;
        Darwin*)
            DOCKER_CONFIG_PATH="$HOME/.docker/daemon.json"
            ;;
        MINGW*|CYGWIN*|MSYS*)
            DOCKER_CONFIG_PATH="$PROGRAMDATA/Docker/config/daemon.json"
            ;;
        *)
            DOCKER_CONFIG_PATH="/etc/docker/daemon.json"
            ;;
    esac
}

get_cargo_config() {
    local mirror=$1
    local use_sparse=${2:-true}
    
    local registry_url=""
    
    if [ "$use_sparse" = true ]; then
        registry_url="${CARGO_MIRRORS[$mirror]}"
    else
        registry_url="${CARGO_GIT_MIRRORS[$mirror]}"
    fi
    
    cat << EOF
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
}

get_docker_config() {
    local mirror=$1
    local custom_address="${2:-}"
    
    local mirrors="[]"
    
    case "$mirror" in
        aliyun)
            if [ -n "$custom_address" ]; then
                mirrors="[\"$custom_address\"]"
            else
                mirrors="[\"${DOCKER_MIRRORS[$mirror]}\"]"
            fi
            ;;
        tencent|daocloud|ustc|rainbond)
            mirrors="[\"${DOCKER_MIRRORS[$mirror]}\"]"
            ;;
        *)
            mirrors="[]"
            ;;
    esac
    
    cat << EOF
{
  "registry-mirrors": $mirrors,
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "features": {
    "buildkit": true
  }
}
EOF
}

get_git_config() {
    local mirror=$1
    
    local base_url="${GITHUB_MIRRORS[$mirror]}"
    
    cat << EOF
[url "https://hub.fastgit.xyz/"]
    insteadOf = https://github.com
    insteadOf = git@github.com:

[url "https://ghproxy.com/"]
    insteadOf = https://github.com
    insteadOf = git@github.com:

[http]
    postBuffer = 524288000
    timeout = 60

[https]
    postBuffer = 524288000
    timeout = 60

[pull]
    rebase = false

[core]
    autocrlf = input
    compression = 9
EOF
}

get_ssh_config() {
    cat << EOF
Host github.com
    HostName github.com
    User git
    Port 443
    ProxyCommand connect -H 127.0.0.1:7890 %h %p

Host ghproxy.com
    HostName ghproxy.com
    User git
    ProxyCommand connect -H 127.0.0.1:7890 %h %p
EOF
}

backup_file() {
    local file=$1
    
    if [ -f "$file" ]; then
        local backup_path="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup_path"
        echo "备份文件到: $backup_path"
        return 0
    fi
    
    return 1
}

apply_cargo_config() {
    local mirror=$1
    local use_sparse=${2:-true}
    
    mkdir -p "$CARGO_CONFIG_DIR"
    
    if [ -f "$CARGO_CONFIG_FILE" ]; then
        backup_file "$CARGO_CONFIG_FILE"
    fi
    
    get_cargo_config "$mirror" "$use_sparse" > "$CARGO_CONFIG_FILE"
    
    echo "Cargo 配置已更新: $CARGO_CONFIG_FILE"
    echo "使用镜像: ${CARGO_MIRRORS[$mirror]:-${CARGO_GIT_MIRRORS[$mirror]}}"
}

apply_docker_config() {
    local mirror=$1
    local custom_address="${2:-}"
    
    get_docker_config_path
    
    if [ -f "$DOCKER_CONFIG_PATH" ]; then
        backup_file "$DOCKER_CONFIG_PATH"
    fi
    
    mkdir -p "$(dirname "$DOCKER_CONFIG_PATH")"
    
    get_docker_config "$mirror" "$custom_address" > "$DOCKER_CONFIG_PATH"
    
    echo "Docker 配置已更新: $DOCKER_CONFIG_PATH"
    echo "使用镜像: ${DOCKER_MIRRORS[$mirror]}"
}

apply_git_config() {
    local mirror=$1
    
    if [ -f "$GIT_CONFIG_PATH" ]; then
        backup_file "$GIT_CONFIG_PATH"
    fi
    
    get_git_config "$mirror" > "$GIT_CONFIG_PATH"
    
    echo "Git 配置已更新: $GIT_CONFIG_PATH"
    echo "使用镜像: ${GITHUB_MIRRORS[$mirror]}"
}

apply_ssh_config() {
    if [ -f "$SSH_CONFIG_PATH" ]; then
        backup_file "$SSH_CONFIG_PATH"
    fi
    
    mkdir -p "$(dirname "$SSH_CONFIG_PATH")"
    
    get_ssh_config > "$SSH_CONFIG_PATH"
    chmod 600 "$SSH_CONFIG_PATH"
    
    echo "SSH 配置已更新: $SSH_CONFIG_PATH"
}

show_current_config() {
    echo "=========================================="
    echo "镜像配置状态"
    echo "=========================================="
    
    echo -e "\nCargo 配置:"
    if [ -f "$CARGO_CONFIG_FILE" ]; then
        echo "  状态: 已配置"
        grep "registry =" "$CARGO_CONFIG_FILE" | head -n 1
    else
        echo "  状态: 未配置"
    fi
    
    echo -e "\nDocker 配置:"
    get_docker_config_path
    if [ -f "$DOCKER_CONFIG_PATH" ]; then
        echo "  状态: 已配置"
        grep "registry-mirrors" "$DOCKER_CONFIG_PATH" || echo "  镜像: 未设置"
    else
        echo "  状态: 未配置"
    fi
    
    echo -e "\nGit 配置:"
    if [ -f "$GIT_CONFIG_PATH" ]; then
        echo "  状态: 已配置"
        grep "insteadOf" "$GIT_CONFIG_PATH" | head -n 1 || echo "  镜像: 未设置"
    else
        echo "  状态: 未配置"
    fi
    
    echo -e "\n=========================================="
}

reset_all_config() {
    echo "重置所有镜像配置..."
    
    if [ -f "$CARGO_CONFIG_FILE" ]; then
        backup_file "$CARGO_CONFIG_FILE"
        rm -f "$CARGO_CONFIG_FILE"
        echo "已删除 Cargo 配置"
    fi
    
    get_docker_config_path
    if [ -f "$DOCKER_CONFIG_PATH" ]; then
        backup_file "$DOCKER_CONFIG_PATH"
        rm -f "$DOCKER_CONFIG_PATH"
        echo "已删除 Docker 配置"
    fi
    
    if [ -f "$GIT_CONFIG_PATH" ]; then
        backup_file "$GIT_CONFIG_PATH"
        rm -f "$GIT_CONFIG_PATH"
        echo "已删除 Git 配置"
    fi
    
    echo "所有配置已重置"
}

export -f get_cargo_config
export -f get_docker_config
export -f get_git_config
export -f get_ssh_config
export -f backup_file
export -f apply_cargo_config
export -f apply_docker_config
export -f apply_git_config
export -f apply_ssh_config
export -f show_current_config
export -f reset_all_config
