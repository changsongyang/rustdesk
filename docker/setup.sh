#!/bin/bash
# RustDesk Docker Quick Start Script
# RustDesk Docker 快速启动脚本

set -e

# 颜色定义 / Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本目录 / Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 日志函数 / Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示横幅 / Show banner
show_banner() {
    echo -e "${GREEN}"
    cat << "EOF"
    ____           ____        _      ____                         _
   |  _ \ _ __ ___| __ )  ___ | |_   / ___|  _ __   ___  _ __ ___ | |__   ___ _ __
   | |_) | '__/ _ \  _ \ / _ \| __| | |  _  | '__| / _ \| '_ ` _ \| '_ \ / _ \ '__|
   |  _ <| | | (_) | |_) | (_) | |_  | |_| | | |  | (_) | | | | | | |_) |  __/ |
   |_| \_\_|  \___/|____/ \___/ \__|  \____| |_|   \___/|_| |_| |_|_.__/ \___|_|

    Docker Deployment Script v1.0
EOF
    echo -e "${NC}"
}

# 检查依赖 / Check dependencies
check_dependencies() {
    log_info "检查依赖... / Checking dependencies..."

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装 / Docker is not installed"
        exit 1
    fi

    # 检查 Docker Compose
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装 / Docker Compose is not installed"
        exit 1
    fi

    log_success "所有依赖已安装 / All dependencies are installed"
}

# 创建目录结构 / Create directory structure
create_directories() {
    log_info "创建目录结构... / Creating directory structure..."

    cd "$SCRIPT_DIR"

    # 创建必要的目录
    mkdir -p data/hbbs data/hbbr
    mkdir -p config/hbbs config/hbbr
    mkdir -p logs/hbbs logs/hbbr logs/nginx
    mkdir -p nginx certs backups

    log_success "目录结构已创建 / Directory structure created"
}

# 配置文件 / Configure environment
configure_environment() {
    log_info "配置环境变量... / Configuring environment variables..."

    cd "$SCRIPT_DIR"

    # 复制环境变量文件
    if [ ! -f .env ]; then
        cp .env.example .env
        log_success "环境变量文件已创建 / Environment file created"
        log_warning "请编辑 .env 文件配置您的环境 / Please edit .env file to configure your environment"
    else
        log_warning ".env 文件已存在，跳过 / .env file already exists, skipping"
    fi
}

# 拉取镜像 / Pull images
pull_images() {
    log_info "拉取 Docker 镜像... / Pulling Docker images..."

    docker pull rustdesk/rustdesk-server:latest || log_warning "拉取失败，将使用本地镜像 / Pull failed, will use local image"

    log_success "镜像准备完成 / Images ready"
}

# 启动服务 / Start services
start_services() {
    log_info "启动 Docker 服务... / Starting Docker services..."

    cd "$SCRIPT_DIR"

    # 使用 docker compose 或 docker-compose
    if docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi

    log_success "服务已启动 / Services started"
}

# 停止服务 / Stop services
stop_services() {
    log_info "停止 Docker 服务... / Stopping Docker services..."

    cd "$SCRIPT_DIR"

    if docker compose version &> /dev/null; then
        docker compose down
    else
        docker-compose down
    fi

    log_success "服务已停止 / Services stopped"
}

# 查看状态 / View status
view_status() {
    cd "$SCRIPT_DIR"

    if docker compose version &> /dev/null; then
        docker compose ps
    else
        docker-compose ps
    fi
}

# 查看日志 / View logs
view_logs() {
    SERVICE=$1

    cd "$SCRIPT_DIR"

    if [ -z "$SERVICE" ]; then
        if docker compose version &> /dev/null; then
            docker compose logs -f
        else
            docker-compose logs -f
        fi
    else
        if docker compose version &> /dev/null; then
            docker compose logs -f "$SERVICE"
        else
            docker-compose logs -f "$SERVICE"
        fi
    fi
}

# 重启服务 / Restart services
restart_services() {
    log_info "重启 Docker 服务... / Restarting Docker services..."

    cd "$SCRIPT_DIR"

    if docker compose version &> /dev/null; then
        docker compose restart
    else
        docker-compose restart
    fi

    log_success "服务已重启 / Services restarted"
}

# 清理环境 / Cleanup environment
cleanup_environment() {
    log_warning "清理 Docker 环境... / Cleaning up Docker environment..."

    cd "$SCRIPT_DIR"

    if docker compose version &> /dev/null; then
        docker compose down -v
    else
        docker-compose down -v
    fi

    log_success "环境已清理 / Environment cleaned"
}

# 显示帮助 / Show help
show_help() {
    show_banner
    cat << EOF
使用说明 / Usage:
    $0 [command]

命令 / Commands:
    start       启动所有服务 / Start all services
    stop        停止所有服务 / Stop all services
    restart     重启所有服务 / Restart all services
    status      查看服务状态 / View service status
    logs [svc]  查看日志 (可选服务名) / View logs (optional service name)
    cleanup     清理所有数据 / Clean up all data
    help        显示此帮助 / Show this help

示例 / Examples:
    $0 start              # 启动服务 / Start services
    $0 logs hbbs          # 查看 hbbs 日志 / View hbbs logs
    $0 restart            # 重启服务 / Restart services
    $0 cleanup            # 清理环境 / Cleanup environment

EOF
}

# 主函数 / Main function
main() {
    COMMAND=${1:-help}

    case "$COMMAND" in
        start)
            show_banner
            check_dependencies
            create_directories
            configure_environment
            pull_images
            start_services
            echo ""
            log_success "RustDesk Docker 服务已启动 / RustDesk Docker services started"
            echo ""
            echo "访问地址 / Access:"
            echo "  hbbs: http://localhost:21115"
            echo "  hbbr: http://localhost:21116"
            echo ""
            echo "查看日志 / View logs: $0 logs"
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            view_status
            ;;
        logs)
            view_logs "$2"
            ;;
        cleanup)
            cleanup_environment
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $COMMAND / Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数 / Execute main function
main "$@"
