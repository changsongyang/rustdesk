#!/bin/bash

# RustDesk 环境检测脚本
# 用于检测系统环境是否满足部署要求
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

check_os() {
    echo -e "${INFO} 检测操作系统...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="RedHat/CentOS"
        OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
        OS_ID="rhel"
    elif [ -f /etc/debian_version ]; then
        OS_NAME="Debian/Ubuntu"
        OS_VERSION=$(cat /etc/debian_version)
        OS_ID="debian"
    else
        OS_NAME="Unknown"
        OS_VERSION="Unknown"
        OS_ID="unknown"
    fi

    KERNEL_VERSION=$(uname -r)
    ARCHITECTURE=$(uname -m)

    echo "  操作系统: $OS_NAME $OS_VERSION"
    echo "  内核版本: $KERNEL_VERSION"
    echo "  架构: $ARCHITECTURE"

    SUPPORTED_OS=("ubuntu" "debian" "centos" "rhel" "fedora" "rocky" "alma")
    if [[ ! " ${SUPPORTED_OS[@]} " =~ " ${OS_ID} " ]]; then
        echo -e "${WARN} 不支持的操作系统: $OS_ID (可能可以运行但未经过测试)${NC}"
    fi
}

check_docker() {
    echo -e "\n${INFO} 检测 Docker...${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "  ${ERROR} Docker 未安装${NC}"
        return 1
    fi

    DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "  Docker 版本: $DOCKER_VERSION"

    if docker --version 2>/dev/null | grep -q "buildx"; then
        echo "  Docker Buildx: 已安装"
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        echo -e "  ${WARN} Docker Compose 未安装${NC}"
    else
        if docker compose version &> /dev/null 2>&1; then
            COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "v2")
        else
            COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        fi
        echo "  Docker Compose 版本: $COMPOSE_VERSION"
    fi

    if ! docker info &> /dev/null 2>&1; then
        echo -e "  ${ERROR} Docker 服务未运行或当前用户没有权限${NC}"
        return 1
    fi

    echo -e "  ${SUCCESS} Docker 状态: 运行正常${NC}"
}

check_kubernetes() {
    echo -e "\n${INFO} 检测 Kubernetes...${NC}"

    if ! command -v kubectl &> /dev/null; then
        echo "  kubectl 未安装 (可选)"
        return 0
    fi

    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "  kubectl 版本: $KUBECTL_VERSION"

    if command -v minikube &> /dev/null; then
        MINIKUBE_VERSION=$(minikube version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo "  Minikube 版本: $MINIKUBE_VERSION"
    fi

    if command -v helm &> /dev/null; then
        HELM_VERSION=$(helm version --short 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo "  Helm 版本: $HELM_VERSION"
    fi

    if kubectl cluster-info &> /dev/null 2>&1; then
        echo -e "  ${SUCCESS} Kubernetes 集群: 已连接${NC}"
    else
        echo -e "  ${WARN} Kubernetes 集群: 未连接或不可用${NC}"
    fi
}

check_ports() {
    echo -e "\n${INFO} 检测端口可用性...${NC}"

    PORTS=(21115 21116 21117 21118 21119 21120)
    PORT_NAMES=("HBBDS" "HBBDS_TLS" "RELAY" "NAT_TEST" "STATUS" "HEALTH")

    for i in "${!PORTS[@]}"; do
        PORT=${PORTS[$i]}
        NAME=${PORT_NAMES[$i]}

        if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
            echo -e "  端口 $PORT ($NAME): ${RED}已被占用${NC}"
        elif ss -tuln 2>/dev/null | grep -q ":$PORT "; then
            echo -e "  端口 $PORT ($NAME): ${RED}已被占用${NC}"
        else
            echo -e "  端口 $PORT ($NAME): ${GREEN}可用${NC}"
        fi
    done
}

check_system_resources() {
    echo -e "\n${INFO} 检测系统资源...${NC}"

    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    AVAILABLE_MEM=$(free -g | awk '/^Mem:/{print $7}')
    echo "  总内存: ${TOTAL_MEM}GB"
    echo "  可用内存: ${AVAILABLE_MEM}GB"

    if [ "$TOTAL_MEM" -lt "$MIN_MEMORY_GB" ]; then
        echo -e "  ${ERROR} 内存不足 (要求: ${MIN_MEMORY_GB}GB)${NC}"
    else
        echo -e "  ${SUCCESS} 内存检查: 通过${NC}"
    fi

    CPU_CORES=$(nproc)
    echo "  CPU 核心数: $CPU_CORES"

    if [ "$CPU_CORES" -lt "$MIN_CPU_CORES" ]; then
        echo -e "  ${ERROR} CPU 核心数不足 (要求: ${MIN_CPU_CORES})${NC}"
    else
        echo -e "  ${SUCCESS} CPU 检查: 通过${NC}"
    fi

    DISK_TOTAL=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    echo "  可用磁盘空间: ${DISK_TOTAL}GB"

    if [ "$DISK_TOTAL" -lt "$MIN_DISK_SPACE_GB" ]; then
        echo -e "  ${ERROR} 磁盘空间不足 (要求: ${MIN_DISK_SPACE_GB}GB)${NC}"
    else
        echo -e "  ${SUCCESS} 磁盘检查: 通过${NC}"
    fi
}

check_network() {
    echo -e "\n${INFO} 检测网络连通性...${NC}"

    echo -n "  GitHub: "
    if curl -s --connect-timeout 5 https://github.com > /dev/null 2>&1; then
        echo -e "${GREEN}可达${NC}"
    else
        echo -e "${RED}不可达${NC}"
    fi

    echo -n "  Docker Hub: "
    if curl -s --connect-timeout 5 https://hub.docker.com > /dev/null 2>&1; then
        echo -e "${GREEN}可达${NC}"
    else
        echo -e "${RED}不可达${NC}"
    fi

    echo -n "  RustDesk 下载: "
    if curl -s --connect-timeout 5 https://github.com/rustdesk/rustdesk/releases > /dev/null 2>&1; then
        echo -e "${GREEN}可达${NC}"
    else
        echo -e "${RED}不可达${NC}"
    fi

    echo -n "  DNS 解析: "
    if nslookup github.com > /dev/null 2>&1 || host github.com > /dev/null 2>&1; then
        echo -e "${GREEN}正常${NC}"
    else
        echo -e "${RED}异常${NC}"
    fi
}

check_dependencies() {
    echo -e "\n${INFO} 检测依赖项...${NC}"

    DEPS=("curl" "wget" "git" "tar" "gzip" "openssl")
    OPTIONAL_DEPS=("jq" "htop" "sysstat")

    echo "  必需依赖:"
    for dep in "${DEPS[@]}"; do
        if command -v "$dep" &> /dev/null; then
            VERSION=$($dep --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            echo -e "    $dep: ${GREEN}$VERSION${NC}"
        else
            echo -e "    $dep: ${RED}未安装${NC}"
        fi
    done

    echo "  可选依赖:"
    for dep in "${OPTIONAL_DEPS[@]}"; do
        if command -v "$dep" &> /dev/null; then
            echo -e "    $dep: ${GREEN}已安装${NC}"
        else
            echo -e "    $dep: ${YELLOW}未安装${NC}"
        fi
    done
}

check_firewall() {
    echo -e "\n${INFO} 检测防火墙...${NC}"

    if systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "  Firewalld: 运行中"
        echo -e "  ${WARN} 需要开放以下端口:${NC}"
        echo "    firewall-cmd --permanent --add-port=21115-21120/tcp"
        echo "    firewall-cmd --reload"
    elif systemctl is-active --quiet ufw 2>/dev/null; then
        echo "  UFW: 运行中"
        echo -e "  ${WARN} 需要开放以下端口:${NC}"
        echo "    ufw allow 21115:21120/tcp"
    elif iptables -L -n > /dev/null 2>&1; then
        echo "  iptables: 配置中"
    else
        echo "  防火墙: 未检测到或未激活"
    fi
}

check_selinux() {
    echo -e "\n${INFO} 检测 SELinux...${NC}"

    if command -v getenforce &> /dev/null; then
        STATUS=$(getenforce 2>/dev/null)
        echo "  SELinux 状态: $STATUS"

        if [ "$STATUS" = "Enforcing" ]; then
            echo -e "  ${WARN} SELinux 已启用，可能需要配置策略${NC}"
        fi
    else
        echo "  SELinux: 未安装或不可用"
    fi
}

check_user_permissions() {
    echo -e "\n${INFO} 检测用户权限...${NC}"

    CURRENT_USER=$(whoami)
    echo "  当前用户: $CURRENT_USER"

    if [ "$CURRENT_USER" = "root" ]; then
        echo -e "  ${SUCCESS} 运行于 root 用户${NC}"
    else
        echo "  用户组: $(groups)"
        if groups | grep -q docker; then
            echo -e "  ${SUCCESS} 用户已在 docker 组${NC}"
        else
            echo -e "  ${WARN} 用户不在 docker 组，可能需要 sudo${NC}"
        fi
    fi
}

print_summary() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}         环境检测报告汇总${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "\n${GREEN}✓ 操作系统:${NC} $OS_NAME $OS_VERSION ($ARCHITECTURE)"
    echo -e "${GREEN}✓ 系统资源:${NC} CPU: $CPU_CORES 核, 内存: ${TOTAL_MEM}GB, 磁盘: ${DISK_TOTAL}GB"
    echo -e "${GREEN}✓ Docker 版本:${NC} $DOCKER_VERSION"

    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker Compose:${NC} 可用"
    fi

    echo -e "\n${YELLOW}注意事项:${NC}"
    echo "  1. 确保所有必需端口未被占用"
    echo "  2. 如使用防火墙，请开放 21115-21120/tcp"
    echo "  3. 建议使用非 root 用户运行 Docker"
    echo "  4. 确保网络可以访问 Docker Hub 和 GitHub"

    echo -e "\n${CYAN}下一步:${NC}"
    echo "  运行 ./install.sh 开始安装部署"
}

main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   RustDesk 环境检测脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}========================================${NC}"

    check_os
    check_docker
    check_kubernetes
    check_ports
    check_system_resources
    check_network
    check_dependencies
    check_firewall
    check_selinux
    check_user_permissions

    print_summary

    echo ""
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
