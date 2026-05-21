#!/bin/bash

# RustDesk 自动安装脚本
# 用于快速部署 RustDesk 服务器
# Author: RustDesk Team
# Version: 1.0.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
COMMON_DIR="$PARENT_DIR/common"

if [ -f "$COMMON_DIR/constants.sh" ]; then
    source "$COMMON_DIR/constants.sh"
fi

SILENT_MODE=false
FORCE_REINSTALL=false
SKIP_DEPENDENCIES=false
DEPLOY_MODE="docker"

usage() {
    cat << EOF
用法: $SCRIPT_NAME [选项]

选项:
    -s, --silent          静默模式 (非交互式)
    -f, --force           强制重新安装
    --skip-deps           跳过依赖检查
    -m, --mode MODE       部署模式: docker (默认) | kubernetes | source
    -h, --help            显示帮助信息
    -v, --version         显示版本信息

示例:
    $SCRIPT_NAME                    # 交互式安装
    $SCRIPT_NAME -s                 # 静默安装
    $SCRIPT_NAME -m kubernetes      # Kubernetes 部署

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--silent)
                SILENT_MODE=true
                shift
                ;;
            -f|--force)
                FORCE_REINSTALL=true
                shift
                ;;
            --skip-deps)
                SKIP_DEPENDENCIES=true
                shift
                ;;
            -m|--mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME v${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                echo -e "${ERROR} 未知选项: $1${NC}"
                usage
                exit 1
                ;;
        esac
    done
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${ERROR} 此脚本需要 root 权限运行${NC}"
        echo "请使用: sudo $SCRIPT_NAME"
        exit 1
    fi
}

install_docker() {
    echo -e "${INFO} 检查 Docker...${NC}"

    if command -v docker &> /dev/null; then
        if [ "$FORCE_REINSTALL" = true ]; then
            echo -e "${WARN} Docker 已安装，强制重新安装...${NC}"
        else
            echo -e "${SUCCESS} Docker 已安装${NC}"
            return 0
        fi
    fi

    echo -e "${INFO} 安装 Docker...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
    fi

    case "$OS_ID" in
        ubuntu|debian)
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | apt-key add -
            add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/$OS_ID $(lsb_release -cs) stable"
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        centos|rhel|rocky|alma)
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        fedora)
            dnf -y install dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        *)
            echo -e "${ERROR} 不支持的操作系统: $OS_ID${NC}"
            exit 1
            ;;
    esac

    systemctl start docker
    systemctl enable docker

    if command -v docker &> /dev/null; then
        echo -e "${SUCCESS} Docker 安装成功${NC}"
    else
        echo -e "${ERROR} Docker 安装失败${NC}"
        exit 1
    fi
}

install_docker_compose() {
    echo -e "${INFO} 检查 Docker Compose...${NC}"

    if docker compose version &> /dev/null 2>&1; then
        echo -e "${SUCCESS} Docker Compose 已安装${NC}"
        return 0
    fi

    if command -v docker-compose &> /dev/null; then
        echo -e "${SUCCESS} Docker Compose 已安装${NC}"
        return 0
    fi

    echo -e "${INFO} 安装 Docker Compose...${NC}"

    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    if command -v docker-compose &> /dev/null; then
        echo -e "${SUCCESS} Docker Compose 安装成功${NC}"
    else
        echo -e "${ERROR} Docker Compose 安装失败${NC}"
        exit 1
    fi
}

install_dependencies() {
    if [ "$SKIP_DEPENDENCIES" = true ]; then
        echo -e "${INFO} 跳过依赖检查${NC}"
        return 0
    fi

    echo -e "${INFO} 安装系统依赖...${NC}"

    case "$OS_ID" in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget git vim net-tools ca-certificates
            ;;
        centos|rhel|rocky|alma)
            yum install -y curl wget git vim net-tools ca-certificates
            ;;
        fedora)
            dnf install -y curl wget git vim net-tools ca-certificates
            ;;
    esac

    echo -e "${SUCCESS} 依赖安装完成${NC}"
}

create_directories() {
    echo -e "${INFO} 创建目录结构...${NC}"

    mkdir -p "$PROJECT_HOME"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR"

    chmod -R 755 "$PROJECT_HOME"
    chown -R root:root "$PROJECT_HOME"

    echo -e "${SUCCESS} 目录创建完成${NC}"
}

generate_docker_compose() {
    echo -e "${INFO} 生成 Docker Compose 配置...${NC}"

    cat > "$PROJECT_HOME/docker-compose.yml" << EOF
version: '3.8'

services:
  hbbs:
    container_name: rustdesk-hbbs
    image: rustdesk/rustdesk-server:latest
    command: hbbs -k _
    ports:
      - "${HBBDS_PORT}:${HBBDS_PORT}"
      - "${HBBDS_TLS_PORT}:${HBBDS_TLS_PORT}"
      - "${NAT_TYPE_TEST_PORT}:${NAT_TYPE_TEST_PORT}"
    volumes:
      - ./data:/data
    environment:
      - RUST_LOG=info
    restart: unless-stopped
    network_mode: host
    healthcheck:
      test: ["CMD", "timeout", "1", "bash", "-c", "echo | nc localhost 21115"]
      interval: 30s
      timeout: 10s
      retries: 3

  hbbr:
    container_name: rustdesk-hbbr
    image: rustdesk/rustdesk-server:latest
    command: hbbr -k _
    ports:
      - "${RELAY_PORT}:${RELAY_PORT}"
    volumes:
      - ./data:/data
    environment:
      - RUST_LOG=info
    restart: unless-stopped
    network_mode: host
    depends_on:
      - hbbs
    healthcheck:
      test: ["CMD", "timeout", "1", "bash", "-c", "echo | nc localhost 21117"]
      interval: 30s
      timeout: 10s
      retries: 3

networks: {}
EOF

    echo -e "${SUCCESS} Docker Compose 配置已生成${NC}"
}

generate_env_file() {
    echo -e "${INFO} 生成环境配置文件...${NC}"

    cat > "$CONFIG_DIR/.env" << EOF
PROJECT_HOME=$PROJECT_HOME
DATA_DIR=$DATA_DIR
LOG_DIR=$LOG_DIR
CONFIG_DIR=$CONFIG_DIR
BACKUP_DIR=$BACKUP_DIR

HBBDS_PORT=$HBBDS_PORT
HBBDS_TLS_PORT=$HBBDS_TLS_PORT
RELAY_PORT=$RELAY_PORT
NAT_TYPE_TEST_PORT=$NAT_TYPE_TEST_PORT
STATUS_PORT=$STATUS_PORT

DOCKER_IMAGE=$DOCKER_IMAGE
ENABLE_TLS=$ENABLE_TLS
LOG_LEVEL=$LOG_LEVEL
EOF

    chmod 600 "$CONFIG_DIR/.env"
    echo -e "${SUCCESS} 环境配置文件已生成${NC}"
}

start_services() {
    echo -e "${INFO} 启动 RustDesk 服务...${NC}"

    cd "$PROJECT_HOME"

    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            docker-compose up -d
        else
            echo -e "${ERROR} Docker Compose 不可用${NC}"
            exit 1
        fi
    else
        docker compose up -d
    fi

    sleep 5

    check_service_status
}

check_service_status() {
    echo -e "${INFO} 检查服务状态...${NC}"

    sleep 10

    CONTAINER1=$(docker ps --filter "name=rustdesk-hbbs" --format "{{.Names}}")
    CONTAINER2=$(docker ps --filter "name=rustdesk-hbbr" --format "{{.Names}}")

    if [ -n "$CONTAINER1" ] && [ -n "$CONTAINER2" ]; then
        echo -e "${SUCCESS} RustDesk 服务启动成功${NC}"

        echo -e "\n${GREEN}服务状态:${NC}"
        docker ps --filter "name=rustdesk"

        echo -e "\n${GREEN}访问地址:${NC}"
        echo "  H BBS: ${HBBDS_PORT} (TCP)"
        echo "  H BBS TLS: ${HBBDS_TLS_PORT} (TCP)"
        echo "  Relay: ${RELAY_PORT} (TCP)"
        echo "  NAT Type Test: ${NAT_TYPE_TEST_PORT} (TCP)"

        echo -e "\n${CYAN}查看日志:${NC}"
        echo "  docker compose logs -f"
        echo "  docker logs rustdesk-hbbs -f"
        echo "  docker logs rustdesk-hbbr -f"

        echo -e "\n${CYAN}服务管理:${NC}"
        echo "  启动: cd $PROJECT_HOME && docker compose start"
        echo "  停止: cd $PROJECT_HOME && docker compose stop"
        echo "  重启: cd $PROJECT_HOME && docker compose restart"
    else
        echo -e "${ERROR} 服务启动失败，请检查日志${NC}"
        echo "查看日志: docker compose logs"
        exit 1
    fi
}

verify_installation() {
    echo -e "${INFO} 验证安装...${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${ERROR} Docker 未安装${NC}"
        return 1
    fi

    if ! docker ps &> /dev/null 2>&1; then
        echo -e "${ERROR} Docker 服务未运行${NC}"
        return 1
    fi

    if [ ! -f "$PROJECT_HOME/docker-compose.yml" ]; then
        echo -e "${ERROR} Docker Compose 配置文件不存在${NC}"
        return 1
    fi

    NETSTAT_OUTPUT=$(netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null || true)
    if ! echo "$NETSTAT_OUTPUT" | grep -q ":${HBBDS_PORT}"; then
        echo -e "${WARN} 端口 ${HBBDS_PORT} 未监听${NC}"
    fi

    echo -e "${SUCCESS} 安装验证通过${NC}"
    return 0
}

print_next_steps() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}         安装完成！${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "\n${GREEN}下一步操作:${NC}"
    echo "  1. 获取公钥:"
    echo "     docker logs rustdesk-hbbs 2>&1 | grep 'public key'"
    echo ""
    echo "  2. 配置 RustDesk 客户端:"
    echo "     - 打开 RustDesk 客户端"
    echo "     - 设置 ID 服务器为您的服务器地址"
    echo "     - 填入上面获取的公钥"
    echo ""
    echo "  3. 管理服务:"
    echo "     cd $PROJECT_HOME"
    echo "     ./manage.sh status    # 查看状态"
    echo "     ./manage.sh logs      # 查看日志"
    echo "     ./manage.sh restart   # 重启服务"
    echo ""
    echo "  4. 备份配置:"
    echo "     ./backup.sh create    # 创建备份"
    echo "     ./backup.sh list      # 查看备份"
    echo ""

    echo -e "${YELLOW}故障排查:${NC}"
    echo "  - 查看日志: docker compose logs"
    echo "  - 检查端口: netstat -tuln | grep 211"
    echo "  - 检查防火墙: firewall-cmd --list-ports"
    echo "  - 重启 Docker: systemctl restart docker"
    echo ""
}

main() {
    parse_arguments "$@"

    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   RustDesk 自动安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}========================================${NC}"

    if [ "$SILENT_MODE" = false ]; then
        echo -e "\n${YELLOW}即将开始安装 RustDesk 服务器${NC}"
        echo "部署模式: $DEPLOY_MODE"
        echo ""
        read -p "是否继续? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${INFO} 安装已取消${NC}"
            exit 0
        fi
    fi

    check_root

    if [ "$DEPLOY_MODE" = "docker" ]; then
        install_dependencies
        install_docker
        install_docker_compose
        create_directories
        generate_docker_compose
        generate_env_file
        start_services
        verify_installation
        print_next_steps
    elif [ "$DEPLOY_MODE" = "kubernetes" ]; then
        echo -e "${INFO} Kubernetes 部署模式 (待实现)${NC}"
        echo "请参考 docs/kubernetes.md 或使用 Helm:"
        echo "helm repo add rustdesk https://rustdesk.com/helm"
        echo "helm install rustdesk rustdesk/rustdesk"
    elif [ "$DEPLOY_MODE" = "source" ]; then
        echo -e "${INFO} 源码编译部署模式 (待实现)${NC}"
        echo "请参考 docs/compile.md"
    else
        echo -e "${ERROR} 不支持的部署模式: $DEPLOY_MODE${NC}"
        exit 1
    fi

    echo -e "\n${SUCCESS} 安装完成！${NC}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
