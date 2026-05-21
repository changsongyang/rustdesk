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
RustDesk Docker 镜像加速配置脚本

用法: $0 [镜像源] [选项]

可用镜像源:
    aliyun          阿里云镜像加速器（推荐）
    tencent         腾讯云镜像加速器
    daocloud        DaoCloud 镜像
    ustc            中科大镜像
    rainbond        Rainbond 镜像
    custom          自定义镜像地址

选项:
    -a, --address     设置自定义镜像地址
    -s, --show        显示当前配置
    -r, --reset       重置为默认源（Docker Hub）
    -t, --test        测试镜像源可用性
    -p, --platform    指定平台 (linux/windows/macos)
    -h, --help       显示帮助信息

示例:
    $0 aliyun              # 使用阿里云镜像
    $0 tencent             # 使用腾讯云镜像
    $0 custom -a https://custom.mirror.com  # 使用自定义镜像
    $0 --show              # 显示当前配置
    $0 --reset             # 重置为默认源
    $0 -p windows          # Windows 平台配置

注意事项:
    - 需要管理员/root 权限来修改 Docker 配置
    - 修改配置后需要重启 Docker 服务
    - Windows 平台需要使用管理员权限运行

EOF
}

get_docker_config_path() {
    local os=$(uname -s)
    
    case "$os" in
        Linux*)
            echo "/etc/docker/daemon.json"
            ;;
        Darwin*)
            echo "$HOME/.docker/daemon.json"
            ;;
        MINGW*|CYGWIN*|MSYS*)
            if [ -d "$PROGRAMFILES/Docker/Docker" ]; then
                echo "$PROGRAMDATA/Docker/config/daemon.json"
            else
                echo "$HOME/.docker/daemon.json"
            fi
            ;;
        *)
            echo "/etc/docker/daemon.json"
            ;;
    esac
}

get_docker_config_backup_path() {
    local config_path=$(get_docker_config_path)
    echo "${config_path}.backup.$(date +%Y%m%d_%H%M%S)"
}

show_current_config() {
    local config_path=$(get_docker_config_path)
    
    echo -e "${BLUE}Docker 配置路径: ${config_path}${NC}"
    
    if [ -f "$config_path" ]; then
        echo -e "\n${BLUE}当前 daemon.json 配置:${NC}"
        echo -e "${YELLOW}========================================${NC}"
        cat "$config_path" | python3 -m json.tool 2>/dev/null || cat "$config_path"
        echo -e "${YELLOW}========================================${NC}"
        
        if command -v docker &> /dev/null; then
            echo -e "\n${BLUE}Docker 当前配置的镜像源:${NC}"
            docker info 2>/dev/null | grep -A 10 "Registry Mirrors" || echo "未找到镜像源配置"
        fi
    else
        echo -e "${YELLOW}配置文件不存在${NC}"
    fi
}

test_docker_mirror() {
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

test_all_docker_mirrors() {
    echo -e "${BLUE}测试 Docker 镜像源可用性:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    test_docker_mirror "https://docker.rainbond.cc" "Rainbond"
    test_docker_mirror "https://docker.m.daocloud.io" "DaoCloud"
    test_docker_mirror "https://docker.mirrors.ustc.edu.cn" "中科大"
    test_docker_mirror "https://registry.docker-cn.com" "Docker Hub CN"
    
    echo ""
    
    if command -v docker &> /dev/null; then
        echo -e "${BLUE}测试 Docker 基本功能:${NC}"
        if docker info > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Docker 服务运行正常${NC}"
        else
            echo -e "${RED}✗ Docker 服务未运行或配置有问题${NC}"
        fi
    else
        echo -e "${YELLOW}Docker 未安装，跳过测试${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
}

backup_docker_config() {
    local config_path=$(get_docker_config_path)
    local backup_path=$(get_docker_config_backup_path)
    
    if [ -f "$config_path" ]; then
        cp "$config_path" "$backup_path"
        echo -e "${GREEN}已备份当前配置到: ${backup_path}${NC}"
    fi
}

create_docker_config() {
    local mirror=$1
    local custom_address="${2:-}"
    local config_path=$(get_docker_config_path)
    local config_dir=$(dirname "$config_path")
    
    local mirrors=()
    
    case "$mirror" in
        aliyun)
            if [ -z "$custom_address" ]; then
                echo -e "${YELLOW}请访问 https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors 获取您的阿里云镜像加速器地址${NC}"
                echo -e "${YELLOW}或者使用 --address 参数指定地址${NC}"
                return 1
            fi
            mirrors=("$custom_address")
            ;;
        tencent)
            mirrors=("https://mirror.ccs.tencentyun.com")
            ;;
        daocloud)
            mirrors=("https://docker.m.daocloud.io")
            ;;
        ustc)
            mirrors=("https://docker.mirrors.ustc.edu.cn")
            ;;
        rainbond)
            mirrors=("https://docker.rainbond.cc")
            ;;
        custom)
            if [ -z "$custom_address" ]; then
                echo -e "${RED}错误: 使用 custom 镜像源时需要提供 --address 参数${NC}"
                return 1
            fi
            mirrors=("$custom_address")
            ;;
        *)
            mirrors=()
            ;;
    esac
    
    mkdir -p "$config_dir"
    
    local os=$(uname -s)
    local config_json=""
    
    case "$os" in
        Linux*)
            config_json=$(cat << EOF
{
  "registry-mirrors": $(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .),
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
)
            ;;
        Darwin*)
            config_json=$(cat << EOF
{
  "registry-mirrors": $(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .),
  "features": {
    "buildkit": true
  }
}
EOF
)
            ;;
        MINGW*|CYGWIN*|MSYS*)
            config_json=$(cat << EOF
{
  "registry-mirrors": $(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .),
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
EOF
)
            ;;
        *)
            config_json=$(cat << EOF
{
  "registry-mirrors": $(printf '%s\n' "${mirrors[@]}" | jq -R . | jq -s .)
}
EOF
)
            ;;
    esac
    
    echo "$config_json" > "$config_path"
    
    echo -e "${GREEN}Docker 配置已更新: ${config_path}${NC}"
    echo -e "${GREEN}镜像源: ${mirrors[*]}${NC}"
}

restart_docker_service() {
    local os=$(uname -s)
    
    echo -e "${BLUE}重启 Docker 服务...${NC}"
    
    case "$os" in
        Linux*)
            if command -v systemctl &> /dev/null; then
                sudo systemctl restart docker
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Docker 服务已重启${NC}"
                else
                    echo -e "${RED}✗ Docker 服务重启失败${NC}"
                    return 1
                fi
            elif command -v service &> /dev/null; then
                sudo service docker restart
                echo -e "${GREEN}✓ Docker 服务已重启${NC}"
            else
                echo -e "${YELLOW}无法自动重启 Docker，请手动重启${NC}"
            fi
            ;;
        Darwin*)
            if command -v docker &> /dev/null; then
                echo -e "${YELLOW}请手动重启 Docker Desktop${NC}"
                osascript -e 'tell app "Docker Desktop" to quit' 2>/dev/null || true
                sleep 2
                open -a Docker 2>/dev/null || echo -e "${YELLOW}请手动启动 Docker Desktop${NC}"
            fi
            ;;
        MINGW*|CYGWIN*|MSYS*)
            echo -e "${YELLOW}请手动重启 Docker Desktop${NC}"
            ;;
        *)
            echo -e "${YELLOW}未知操作系统，请手动重启 Docker${NC}"
            ;;
    esac
}

reset_docker_config() {
    local config_path=$(get_docker_config_path)
    
    if [ -f "$config_path" ]; then
        backup_docker_config
        rm -f "$config_path"
        echo -e "${GREEN}已删除 Docker 配置文件${NC}"
        
        if command -v docker &> /dev/null; then
            restart_docker_service
        fi
    else
        echo -e "${YELLOW}Docker 配置文件不存在，无需重置${NC}"
    fi
}

verify_config() {
    echo -e "\n${BLUE}验证配置是否生效:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    sleep 2
    
    if command -v docker &> /dev/null; then
        if docker info > /dev/null 2>&1; then
            local mirrors=$(docker info 2>/dev/null | grep -A 5 "Registry Mirrors" || echo "未配置")
            if [ "$mirrors" != "未配置" ]; then
                echo -e "${GREEN}✓ 镜像源配置成功:${NC}"
                echo "$mirrors"
            else
                echo -e "${YELLOW}⚠ 镜像源配置可能未生效，请检查 Docker 服务状态${NC}"
            fi
        else
            echo -e "${RED}✗ Docker 服务未运行${NC}"
        fi
    else
        echo -e "${YELLOW}Docker 未安装或未运行${NC}"
    fi
    
    echo -e "${YELLOW}========================================${NC}"
}

main() {
    local mirror=""
    local custom_address=""
    local platform=""
    local show_config=false
    local reset_config=false
    local test_mode=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--show)
                show_config=true
                shift
                ;;
            -r|--reset)
                reset_config=true
                shift
                ;;
            -t|--test)
                test_mode=true
                shift
                ;;
            -a|--address)
                custom_address="$2"
                shift 2
                ;;
            -p|--platform)
                platform="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            aliyun|tencent|daocloud|ustc|rainbond|custom)
                mirror="$1"
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ "$show_config" = true ]; then
        show_current_config
        exit 0
    fi
    
    if [ "$reset_config" = true ]; then
        reset_docker_config
        exit 0
    fi
    
    if [ "$test_mode" = true ]; then
        test_all_docker_mirrors
        exit 0
    fi
    
    if [ -z "$mirror" ]; then
        echo -e "${RED}错误: 未指定镜像源${NC}"
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}配置 Docker 镜像加速: ${mirror}${NC}"
    
    if [ "$mirror" != "custom" ] && [ "$mirror" != "aliyun" ]; then
        backup_docker_config
    fi
    
    create_docker_config "$mirror" "$custom_address"
    
    echo ""
    echo -e "${YELLOW}注意: 配置已写入，但需要重启 Docker 服务才能生效${NC}"
    
    read -p "是否立即重启 Docker 服务? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_docker_service
        sleep 3
        verify_config
    else
        echo -e "${YELLOW}请稍后手动重启 Docker 服务以使配置生效${NC}"
        echo -e "${BLUE}Linux: sudo systemctl restart docker${NC}"
        echo -e "${BLUE}macOS: 重启 Docker Desktop${NC}"
        echo -e "${BLUE}Windows: 重启 Docker Desktop${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓ 配置完成！${NC}"
}

main "$@"
