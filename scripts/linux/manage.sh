#!/bin/bash

# RustDesk 服务管理脚本
# 用于管理 RustDesk 服务的生命周期
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

usage() {
    cat << EOF
用法: $SCRIPT_NAME <命令> [选项]

命令:
    start           启动服务
    stop            停止服务
    restart         重启服务
    status          查看服务状态
    logs [服务]     查看日志 (可选: hbbs, hbbr, all)
    health          健康检查
    stats           连接统计
    config          配置管理
    update          更新服务
    cleanup         清理资源

选项:
    -h, --help      显示帮助信息
    -v, --version   显示版本信息

示例:
    $SCRIPT_NAME start              # 启动服务
    $SCRIPT_NAME status             # 查看状态
    $SCRIPT_NAME logs hbbs          # 查看 hbbs 日志
    $SCRIPT_NAME logs --follow      # 实时查看所有日志
    $SCRIPT_NAME health             # 健康检查
    $SCRIPT_NAME config show        # 显示当前配置

EOF
}

check_service_files() {
    if [ ! -d "$PROJECT_HOME" ]; then
        echo -e "${ERROR} 项目目录不存在: $PROJECT_HOME${NC}"
        echo "请先运行 install.sh 进行安装"
        exit 1
    fi

    if [ ! -f "$PROJECT_HOME/docker-compose.yml" ]; then
        echo -e "${ERROR} Docker Compose 文件不存在: $PROJECT_HOME/docker-compose.yml${NC}"
        echo "请先运行 install.sh 进行安装"
        exit 1
    fi
}

cmd_start() {
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

    sleep 3

    if cmd_status; then
        echo -e "${SUCCESS} 服务启动成功${NC}"
    else
        echo -e "${ERROR} 服务启动失败${NC}"
        exit 1
    fi
}

cmd_stop() {
    echo -e "${INFO} 停止 RustDesk 服务...${NC}"

    cd "$PROJECT_HOME"

    if ! docker compose version &> /dev/null 2>&1; then
        if command -v docker-compose &> /dev/null; then
            docker-compose down
        else
            echo -e "${ERROR} Docker Compose 不可用${NC}"
            exit 1
        fi
    else
        docker compose down
    fi

    echo -e "${SUCCESS} 服务已停止${NC}"
}

cmd_restart() {
    echo -e "${INFO} 重启 RustDesk 服务...${NC}"

    cmd_stop
    sleep 2
    cmd_start
}

cmd_status() {
    check_service_files

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}       RustDesk 服务状态${NC}"
    echo -e "${BLUE}========================================${NC}"

    local hbbs_status="停止"
    local hbbr_status="停止"
    local hbbs_running=false
    local hbbr_running=false

    if docker ps --filter "name=rustdesk-hbbs" --format "{{.Names}}" | grep -q "rustdesk-hbbs"; then
        hbbs_status="运行中"
        hbbs_running=true
    fi

    if docker ps --filter "name=rustdesk-hbbr" --format "{{.Names}}" | grep -q "rustdesk-hbbr"; then
        hbbr_status="运行中"
        hbbr_running=true
    fi

    echo -e "\n容器状态:"
    printf "  %-20s %s\n" "rustdesk-hbbs" "$hbbs_status"
    printf "  %-20s %s\n" "rustdesk-hbbr" "$hbbr_status"

    if [ "$hbbs_running" = true ] && [ "$hbbr_running" = true ]; then
        echo -e "\n${SUCCESS} 所有服务运行正常${NC}"

        echo -e "\n容器详情:"
        docker ps --filter "name=rustdesk" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

        echo -e "\n端口监听:"
        netstat -tuln 2>/dev/null | grep -E "(${HBBDS_PORT}|${HBBDS_TLS_PORT}|${RELAY_PORT}|${NAT_TYPE_TEST_PORT})" || \
        ss -tuln 2>/dev/null | grep -E "(${HBBDS_PORT}|${HBBDS_TLS_PORT}|${RELAY_PORT}|${NAT_TYPE_TEST_PORT})" || \
        echo "  (无法获取端口信息)"

        return 0
    else
        echo -e "\n${ERROR} 部分服务未运行${NC}"
        return 1
    fi
}

cmd_logs() {
    local service="${1:-all}"
    local follow_flag=""
    local lines_flag="--tail=100"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--follow)
                follow_flag="-f"
                shift
                ;;
            --tail)
                lines_flag="--tail=$2"
                shift 2
                ;;
            *)
                service="$1"
                shift
                ;;
        esac
    done

    check_service_files

    cd "$PROJECT_HOME"

    case "$service" in
        hbbs)
            echo -e "${INFO} 查看 hbbs 日志...${NC}"
            docker logs $lines_flag $follow_flag rustdesk-hbbs 2>&1
            ;;
        hbbr)
            echo -e "${INFO} 查看 hbbr 日志...${NC}"
            docker logs $lines_flag $follow_flag rustdesk-hbbr 2>&1
            ;;
        all)
            echo -e "${INFO} 查看所有服务日志...${NC}"
            if ! docker compose version &> /dev/null 2>&1; then
                if command -v docker-compose &> /dev/null; then
                    docker-compose logs $lines_flag $follow_flag
                fi
            else
                docker compose logs $lines_flag $follow_flag
            fi
            ;;
        *)
            echo -e "${ERROR} 未知服务: $service${NC}"
            echo "可用服务: hbbs, hbbr, all"
            exit 1
            ;;
    esac
}

cmd_health() {
    echo -e "${INFO} 执行健康检查...${NC}"

    local overall_health=true

    echo -e "\n${BLUE}=== 容器健康检查 ===${NC}"

    for container in rustdesk-hbbs rustdesk-hbbr; do
        if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container" 2>/dev/null || echo "unknown")

            echo -e "\n$container:"
            echo "  状态: $status"
            echo "  健康: $health"
            echo "  启动时间: $uptime"

            if [ "$status" != "running" ]; then
                overall_health=false
            fi
        else
            echo -e "\n$container: ${RED}未运行${NC}"
            overall_health=false
        fi
    done

    echo -e "\n${BLUE}=== 端口可用性检查 ===${NC}"

    local ports=("$HBBDS_PORT" "$HBBDS_TLS_PORT" "$RELAY_PORT" "$NAT_TYPE_TEST_PORT")
    local port_names=("HBBDS" "HBBDS_TLS" "RELAY" "NAT_TEST")

    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"

        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "  $port ($name): ${GREEN}监听中${NC}"
        elif ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "  $port ($name): ${GREEN}监听中${NC}"
        else
            echo -e "  $port ($name): ${RED}未监听${NC}"
            overall_health=false
        fi
    done

    echo -e "\n${BLUE}=== 资源使用情况 ===${NC}"

    for container in rustdesk-hbbs rustdesk-hbbr; do
        if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            echo -e "\n$container:"
            docker stats --no-stream --format "  CPU: {{.CPUPerc}}  内存: {{.MemUsage}}  网络: {{.NetIO}}" "$container"
        fi
    done

    if [ "$overall_health" = true ]; then
        echo -e "\n${SUCCESS} 健康检查: 全部通过${NC}"
        return 0
    else
        echo -e "\n${ERROR} 健康检查: 部分失败${NC}"
        return 1
    fi
}

cmd_stats() {
    echo -e "${INFO} 获取连接统计...${NC}"

    echo -e "\n${BLUE}=== Docker 统计 ===${NC}"

    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $(docker ps --filter "name=rustdesk" --format "{{.Names}}")

    echo -e "\n${BLUE}=== 连接统计 ===${NC}"

    if command -v ss &> /dev/null; then
        echo -e "\n活动连接:"
        ss -tn | grep -E "(${HBBDS_PORT}|${HBBDS_TLS_PORT}|${RELAY_PORT}|${NAT_TYPE_TEST_PORT})" | wc -l
        echo "  总连接数"

        echo -e "\n按端口统计:"
        for port in $HBBDS_PORT $HBBDS_TLS_PORT $RELAY_PORT $NAT_TYPE_TEST_PORT; do
            count=$(ss -tn | grep ":$port " | wc -l)
            echo "  端口 $port: $count 连接"
        done
    fi

    echo -e "\n${BLUE}=== 容器资源限制 ===${NC}"

    for container in rustdesk-hbbs rustdesk-hbbr; do
        if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
            echo -e "\n$container:"
            docker inspect --format='  内存限制: {{.HostConfig.Memory}}  CPU限制: {{.HostConfig.CpuQuota}}' "$container" 2>/dev/null || echo "  (无限制)"
        fi
    done
}

cmd_config() {
    local action="${1:-show}"

    case "$action" in
        show)
            echo -e "${INFO} 显示当前配置...${NC}"

            echo -e "\n${BLUE}=== 项目配置 ===${NC}"
            echo "项目目录: $PROJECT_HOME"
            echo "数据目录: $DATA_DIR"
            echo "日志目录: $LOG_DIR"
            echo "配置目录: $CONFIG_DIR"
            echo "备份目录: $BACKUP_DIR"

            echo -e "\n${BLUE}=== 服务端口 ===${NC}"
            echo "HBBDS 端口: $HBBDS_PORT"
            echo "HBBDS TLS 端口: $HBBDS_TLS_PORT"
            echo "Relay 端口: $RELAY_PORT"
            echo "NAT Type Test 端口: $NAT_TYPE_TEST_PORT"
            echo "Status 端口: $STATUS_PORT"

            echo -e "\n${BLUE}=== Docker Compose 配置 ===${NC}"
            if [ -f "$PROJECT_HOME/docker-compose.yml" ]; then
                cat "$PROJECT_HOME/docker-compose.yml"
            else
                echo -e "${ERROR} 配置文件不存在${NC}"
            fi
            ;;
        edit)
            echo -e "${INFO} 编辑配置...${NC}"

            if [ -n "$EDITOR" ]; then
                $EDITOR "$PROJECT_HOME/docker-compose.yml"
            else
                echo "请手动编辑: $PROJECT_HOME/docker-compose.yml"
            fi
            ;;
        reload)
            echo -e "${INFO} 重载配置...${NC}"
            cmd_restart
            ;;
        backup-config)
            echo -e "${INFO} 备份配置...${NC}"

            local backup_file="$BACKUP_DIR/config_$(date +%Y%m%d_%H%M%S).tar.gz"

            mkdir -p "$BACKUP_DIR"
            tar -czf "$backup_file" -C "$PROJECT_HOME" docker-compose.yml 2>/dev/null || true

            if [ -f "$backup_file" ]; then
                echo -e "${SUCCESS} 配置已备份到: $backup_file${NC}"
            else
                echo -e "${ERROR} 备份失败${NC}"
            fi
            ;;
        *)
            echo -e "${ERROR} 未知配置操作: $action${NC}"
            echo "可用操作: show, edit, reload, backup-config"
            exit 1
            ;;
    esac
}

cmd_update() {
    echo -e "${INFO} 更新 RustDesk 服务...${NC}"

    read -p "确定要更新服务吗? 这将重启所有容器. (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${INFO} 更新已取消${NC}"
        return 0
    fi

    cd "$PROJECT_HOME"

    echo -e "${INFO} 拉取最新镜像...${NC}"

    docker pull rustdesk/rustdesk-server:latest

    echo -e "${INFO} 重启服务...${NC}"
    cmd_restart

    echo -e "${SUCCESS} 更新完成${NC}"
}

cmd_cleanup() {
    echo -e "${INFO} 清理资源...${NC}"

    echo -e "\n${YELLOW}注意: 这将清理未使用的 Docker 资源${NC}"
    read -p "确定要继续吗? (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${INFO} 清理已取消${NC}"
        return 0
    fi

    echo -e "${INFO} 清理未使用的镜像...${NC}"
    docker image prune -f

    echo -e "${INFO} 清理未使用的卷...${NC}"
    docker volume prune -f

    echo -e "${INFO} 清理未使用的网络...${NC}"
    docker network prune -f

    echo -e "${INFO} 清理构建缓存...${NC}"
    docker builder prune -f

    echo -e "${SUCCESS} 清理完成${NC}"
}

main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        health)
            cmd_health "$@"
            ;;
        stats)
            cmd_stats "$@"
            ;;
        config)
            cmd_config "$@"
            ;;
        update)
            cmd_update "$@"
            ;;
        cleanup)
            cmd_cleanup "$@"
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
            echo -e "${ERROR} 未知命令: $command${NC}"
            usage
            exit 1
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
