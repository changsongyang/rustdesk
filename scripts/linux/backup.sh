#!/bin/bash

# RustDesk 备份恢复脚本
# 用于备份和恢复 RustDesk 配置和数据
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

BACKUP_NAME_PREFIX="rustdesk-backup"
BACKUP_ENCRYPTION_KEY=""

usage() {
    cat << EOF
用法: $SCRIPT_NAME <命令> [选项]

命令:
    create [名称]     创建备份 (可选指定名称)
    list             列出所有备份
    verify [备份]    验证备份完整性
    restore [备份]   恢复备份
    delete [备份]    删除备份
    schedule         设置定时备份任务
    cleanup          清理过期备份
    remote-setup     配置远程备份
    remote-backup    立即执行远程备份
    remote-list      列出远程备份

选项:
    --encrypt        加密备份
    --compress TYPE  压缩类型: gzip (默认), bzip2, xz
    --retention DAYS 备份保留天数 (默认: 30)
    -h, --help       显示帮助信息
    -v, --version    显示版本信息

示例:
    $SCRIPT_NAME create                    # 创建备份
    $SCRIPT_NAME create my-backup          # 创建名为 my-backup 的备份
    $SCRIPT_NAME list                      # 列出备份
    $SCRIPT_NAME verify backup_20240101   # 验证备份
    $SCRIPT_NAME restore backup_20240101   # 恢复备份
    $SCRIPT_NAME cleanup                    # 清理过期备份
    $SCRIPT_NAME schedule --daily          # 设置每日备份

EOF
}

parse_arguments() {
    ENCRYPT_BACKUP=false
    COMPRESS_TYPE="gzip"
    RETENTION_DAYS="$BACKUP_RETENTION_DAYS"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --encrypt)
                ENCRYPT_BACKUP=true
                shift
                ;;
            --compress)
                COMPRESS_TYPE="$2"
                shift 2
                ;;
            --retention)
                RETENTION_DAYS="$2"
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

check_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${INFO} 创建备份目录: $BACKUP_DIR${NC}"
    fi

    if [ ! -d "$PROJECT_HOME" ]; then
        echo -e "${ERROR} 项目目录不存在: $PROJECT_HOME${NC}"
        exit 1
    fi
}

generate_backup_name() {
    local custom_name="$1"

    if [ -n "$custom_name" ]; then
        echo "${custom_name}_$(date +%Y%m%d_%H%M%S)"
    else
        echo "${BACKUP_NAME_PREFIX}_$(date +%Y%m%d_%H%M%S)"
    fi
}

cmd_create() {
    local backup_name=$(generate_backup_name "$1")

    echo -e "${INFO} 创建备份: $backup_name${NC}"

    check_backup_dir

    local backup_path="$BACKUP_DIR/$backup_name"
    local backup_data="$backup_path/data"
    local backup_meta="$backup_path/metadata.json"

    mkdir -p "$backup_data"

    echo -e "${INFO} 备份配置文件...${NC}"
    if [ -f "$PROJECT_HOME/docker-compose.yml" ]; then
        cp "$PROJECT_HOME/docker-compose.yml" "$backup_data/"
    fi

    if [ -f "$CONFIG_DIR/.env" ]; then
        cp "$CONFIG_DIR/.env" "$backup_data/"
    fi

    if [ -d "$DATA_DIR" ]; then
        echo -e "${INFO} 备份数据目录...${NC}"
        rsync -a "$DATA_DIR/" "$backup_data/data/" 2>/dev/null || cp -r "$DATA_DIR" "$backup_data/"
    fi

    if [ -d "$LOG_DIR" ]; then
        echo -e "${INFO} 备份日志目录...${NC}"
        cp -r "$LOG_DIR" "$backup_data/" 2>/dev/null || true
    fi

    cat > "$backup_meta" << EOF
{
  "name": "$backup_name",
  "created_at": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "project_home": "$PROJECT_HOME",
  "compress_type": "$COMPRESS_TYPE",
  "encrypted": $ENCRYPT_BACKUP,
  "version": "$SCRIPT_VERSION",
  "files": [
    $(ls -1 "$backup_data" 2>/dev/null | sed 's/.*/"&"/' | paste -sd "," || echo "")
  ]
}
EOF

    echo -e "${INFO} 压缩备份...${NC}"
    case "$COMPRESS_TYPE" in
        gzip)
            tar -czf "$backup_path.tar.gz" -C "$backup_path" . 2>/dev/null
            rm -rf "$backup_path"
            backup_path="$backup_path.tar.gz"
            ;;
        bzip2)
            tar -cjf "$backup_path.tar.bz2" -C "$backup_path" . 2>/dev/null
            rm -rf "$backup_path"
            backup_path="$backup_path.tar.bz2"
            ;;
        xz)
            tar -cJf "$backup_path.tar.xz" -C "$backup_path" . 2>/dev/null
            rm -rf "$backup_path"
            backup_path="$backup_path.tar.xz"
            ;;
    esac

    if [ "$ENCRYPT_BACKUP" = true ]; then
        echo -e "${INFO} 加密备份...${NC}"

        if command -v openssl &> /dev/null; then
            local encrypt_pass=$(openssl rand -base64 32)
            openssl enc -aes-256-cbc -salt -pbkdf2 -in "$backup_path" -out "${backup_path}.enc" -k "$encrypt_pass"
            rm -f "$backup_path"

            echo "$encrypt_pass" > "${backup_path}.key"
            chmod 600 "${backup_path}.key"

            backup_path="${backup_path}.enc"

            echo -e "${YELLOW}重要: 请妥善保管解密密钥!${NC}"
            echo "密钥文件: ${backup_path}.key"
        else
            echo -e "${ERROR} openssl 未安装，无法加密备份${NC}"
            return 1
        fi
    fi

    local backup_size=$(du -h "$backup_path" | cut -f1)
    echo -e "${SUCCESS} 备份创建成功${NC}"
    echo "  备份文件: $backup_path"
    echo "  备份大小: $backup_size"
    echo "  创建时间: $(date)"
}

cmd_list() {
    echo -e "${INFO} 列出备份...${NC}"

    check_backup_dir

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}       RustDesk 备份列表${NC}"
    echo -e "${BLUE}========================================${NC}"

    local count=0
    local total_size=0

    for backup in "$BACKUP_DIR"/*; do
        if [ -f "$backup" ]; then
            local filename=$(basename "$backup")
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" "$backup" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

            local encrypted=""
            if [[ "$filename" == *.enc ]]; then
                encrypted=" [加密]"
            fi

            echo -e "\n备份: $filename$encrypted"
            echo "  大小: $size"
            echo "  日期: $date"

            if [[ "$filename" == *.enc ]]; then
                local key_file="${backup}.key"
                if [ -f "$key_file" ]; then
                    echo "  密钥: $key_file"
                fi
            fi

            local size_bytes=$(stat -c %s "$backup" 2>/dev/null || stat -f %z "$backup" 2>/dev/null)
            total_size=$((total_size + size_bytes))
            count=$((count + 1))
        fi
    done

    echo -e "\n${BLUE}========================================${NC}"
    echo "总计: $count 个备份"
    echo "总大小: $(numfmt --to=iec $total_size 2>/dev/null || echo "${total_size} bytes")"
    echo -e "${BLUE}========================================${NC}"

    if [ "$count" -eq 0 ]; then
        echo -e "${INFO} 没有找到备份文件${NC}"
    fi
}

cmd_verify() {
    local backup_name="$1"

    if [ -z "$backup_name" ]; then
        echo -e "${ERROR} 请指定备份文件名${NC}"
        exit 1
    fi

    local backup_path="$BACKUP_DIR/$backup_name"

    if [ ! -f "$backup_path" ] && [ ! -f "$BACKUP_DIR/${backup_name}.tar.gz" ]; then
        backup_path="$BACKUP_DIR/${backup_name}.tar.gz"
    fi

    if [ ! -f "$backup_path" ]; then
        backup_path=$(find "$BACKUP_DIR" -name "*${backup_name}*" -type f 2>/dev/null | head -1)
    fi

    if [ ! -f "$backup_path" ]; then
        echo -e "${ERROR} 备份文件不存在: $backup_name${NC}"
        exit 1
    fi

    echo -e "${INFO} 验证备份: $(basename "$backup_path")${NC}"

    if [[ "$backup_path" == *.enc ]]; then
        echo -e "${INFO} 备份已加密，跳过完整性检查${NC}"

        if [ -f "${backup_path}.key" ]; then
            echo -e "${SUCCESS} 密钥文件存在${NC}"
        else
            echo -e "${ERROR} 密钥文件不存在${NC}"
            return 1
        fi
        return 0
    fi

    case "$backup_path" in
        *.tar.gz)
            if tar -tzf "$backup_path" > /dev/null 2>&1; then
                echo -e "${SUCCESS} 备份完整性验证通过${NC}"
                return 0
            else
                echo -e "${ERROR} 备份完整性验证失败${NC}"
                return 1
            fi
            ;;
        *.tar.bz2)
            if tar -tjf "$backup_path" > /dev/null 2>&1; then
                echo -e "${SUCCESS} 备份完整性验证通过${NC}"
                return 0
            else
                echo -e "${ERROR} 备份完整性验证失败${NC}"
                return 1
            fi
            ;;
        *.tar.xz)
            if tar -tJf "$backup_path" > /dev/null 2>&1; then
                echo -e "${SUCCESS} 备份完整性验证通过${NC}"
                return 0
            else
                echo -e "${ERROR} 备份完整性验证失败${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${ERROR} 未知备份格式${NC}"
            return 1
            ;;
    esac
}

cmd_restore() {
    local backup_name="$1"

    if [ -z "$backup_name" ]; then
        echo -e "${ERROR} 请指定备份文件名${NC}"
        exit 1
    fi

    local backup_path="$BACKUP_DIR/$backup_name"

    if [ ! -f "$backup_path" ]; then
        backup_path=$(find "$BACKUP_DIR" -name "*${backup_name}*" -type f 2>/dev/null | head -1)
    fi

    if [ ! -f "$backup_path" ]; then
        echo -e "${ERROR} 备份文件不存在: $backup_name${NC}"
        exit 1
    fi

    echo -e "${WARN} 即将恢复备份，这可能会覆盖当前配置${NC}"
    read -p "确定要继续吗? (yes/no): " -r
    echo

    if [ "$REPLY" != "yes" ]; then
        echo -e "${INFO} 恢复已取消${NC}"
        return 0
    fi

    echo -e "${INFO} 停止服务...${NC}"
    cd "$PROJECT_HOME"
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

    local temp_dir="$BACKUP_DIR/temp_restore_$$"
    mkdir -p "$temp_dir"

    echo -e "${INFO} 解压备份...${NC}"

    if [[ "$backup_path" == *.enc ]]; then
        if [ ! -f "${backup_path}.key" ]; then
            echo -e "${ERROR} 密钥文件不存在: ${backup_path}.key${NC}"
            rm -rf "$temp_dir"
            return 1
        fi

        echo -e "${INFO} 解密备份...${NC}"
        openssl enc -aes-256-cbc -d -pbkdf2 -in "$backup_path" -out "${temp_dir}/backup.tar.gz" -k "$(cat "${backup_path}.key")"
        backup_path="${temp_dir}/backup.tar.gz"
    fi

    case "$backup_path" in
        *.tar.gz)
            tar -xzf "$backup_path" -C "$temp_dir"
            ;;
        *.tar.bz2)
            tar -xjf "$backup_path" -C "$temp_dir"
            ;;
        *.tar.xz)
            tar -xJf "$backup_path" -C "$temp_dir"
            ;;
    esac

    echo -e "${INFO} 恢复配置文件...${NC}"

    if [ -f "${temp_dir}/docker-compose.yml" ]; then
        cp "${temp_dir}/docker-compose.yml" "$PROJECT_HOME/"
        echo "  docker-compose.yml 已恢复"
    fi

    if [ -f "${temp_dir}/.env" ]; then
        mkdir -p "$CONFIG_DIR"
        cp "${temp_dir}/.env" "$CONFIG_DIR/"
        echo "  .env 已恢复"
    fi

    if [ -d "${temp_dir}/data" ]; then
        rm -rf "$DATA_DIR" 2>/dev/null || true
        cp -r "${temp_dir}/data" "$DATA_DIR"
        echo "  数据目录已恢复"
    fi

    rm -rf "$temp_dir"

    echo -e "${INFO} 重启服务...${NC}"
    docker compose up -d 2>/dev/null || docker-compose up -d

    echo -e "${SUCCESS} 备份恢复完成${NC}"
}

cmd_delete() {
    local backup_name="$1"

    if [ -z "$backup_name" ]; then
        echo -e "${ERROR} 请指定备份文件名${NC}"
        exit 1
    fi

    local backup_path="$BACKUP_DIR/$backup_name"

    if [ ! -f "$backup_path" ]; then
        backup_path=$(find "$BACKUP_DIR" -name "*${backup_name}*" -type f 2>/dev/null | head -1)
    fi

    if [ ! -f "$backup_path" ]; then
        echo -e "${ERROR} 备份文件不存在: $backup_name${NC}"
        exit 1
    fi

    echo -e "${WARN} 即将删除备份: $(basename "$backup_path")${NC}"
    read -p "确定要删除吗? (yes/no): " -r
    echo

    if [ "$REPLY" = "yes" ]; then
        rm -f "$backup_path"

        if [ -f "${backup_path}.key" ]; then
            rm -f "${backup_path}.key"
        fi

        echo -e "${SUCCESS} 备份已删除${NC}"
    else
        echo -e "${INFO} 删除已取消${NC}"
    fi
}

cmd_cleanup() {
    echo -e "${INFO} 清理过期备份...${NC}"
    echo "保留最近 $RETENTION_DAYS 天的备份"

    local count=0

    while IFS= read -r backup; do
        if [ -f "$backup" ]; then
            local age=$(($(date +%s) - $(stat -c %Y "$backup" 2>/dev/null || stat -f %m "$backup" 2>/dev/null)))
            local age_days=$((age / 86400))

            if [ $age_days -gt $RETENTION_DAYS ]; then
                echo -e "删除过期备份: $(basename "$backup") (${age_days} 天前)"
                rm -f "$backup"

                if [ -f "${backup}.key" ]; then
                    rm -f "${backup}.key"
                fi

                count=$((count + 1))
            fi
        fi
    done < <(find "$BACKUP_DIR" -type f \( -name "*.tar.gz" -o -name "*.tar.bz2" -o -name "*.tar.xz" -o -name "*.enc" \) 2>/dev/null)

    if [ $count -eq 0 ]; then
        echo -e "${INFO} 没有过期的备份需要清理${NC}"
    else
        echo -e "${SUCCESS} 已删除 $count 个过期备份${NC}"
    fi
}

cmd_schedule() {
    echo -e "${INFO} 设置定时备份任务...${NC}"

    local schedule_type="${1:-daily}"

    local cron_entry=""
    case "$schedule_type" in
        hourly)
            cron_entry="0 * * * *"
            echo "每小时执行一次备份"
            ;;
        daily)
            cron_entry="0 2 * * *"
            echo "每天凌晨 2:00 执行备份"
            ;;
        weekly)
            cron_entry="0 2 * * 0"
            echo "每周日凌晨 2:00 执行备份"
            ;;
        monthly)
            cron_entry="0 2 1 * *"
            echo "每月 1 日凌晨 2:00 执行备份"
            ;;
        *)
            echo -e "${ERROR} 不支持的备份频率: $schedule_type${NC}"
            echo "支持的频率: hourly, daily, weekly, monthly"
            exit 1
            ;;
    esac

    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SCRIPT_NAME"

    local cron_job="$cron_entry root $script_path create --compress gzip --retention $RETENTION_DAYS"

    echo -e "\n${INFO} 计划任务配置:${NC}"
    echo "$cron_job"

    echo -e "\n${INFO} 添加到 crontab...${NC}"

    if command -v crontab &> /dev/null; then
        (crontab -l 2>/dev/null | grep -v "$script_path"; echo "$cron_entry root $script_path create --compress gzip --retention $RETENTION_DAYS >> $LOG_DIR/backup-cron.log 2>&1") | crontab -
        echo -e "${SUCCESS} 定时备份任务已设置${NC}"

        echo -e "\n查看 crontab:"
        crontab -l | grep "$script_path"
    else
        echo -e "${ERROR} crontab 未安装，无法设置定时任务${NC}"
        return 1
    fi
}

cmd_remote_setup() {
    echo -e "${INFO} 配置远程备份...${NC}"

    if [ -z "$REMOTE_BACKUP_URL" ]; then
        echo -e "${ERROR} 未设置远程备份 URL${NC}"
        echo "请在 config.env 中设置 REMOTE_BACKUP_URL"
        exit 1
    fi

    echo "支持的远程存储类型:"
    echo "  1. S3 (AWS S3 或兼容)"
    echo "  2. SFTP"
    echo "  3. 自定义"

    read -p "选择存储类型 (1-3): " -n 1 -r
    echo

    case $REPLY in
        1)
            echo -e "${INFO} 配置 S3 远程备份${NC}"
            echo "需要配置以下环境变量:"
            echo "  AWS_ACCESS_KEY_ID"
            echo "  AWS_SECRET_ACCESS_KEY"
            echo "  AWS_DEFAULT_REGION"
            echo "  S3_BUCKET_NAME"
            ;;
        2)
            echo -e "${INFO} 配置 SFTP 远程备份${NC}"
            echo "需要配置以下环境变量:"
            echo "  SFTP_HOST"
            echo "  SFTP_PORT"
            echo "  SFTP_USER"
            echo "  SFTP_KEY_PATH"
            echo "  SFTP_REMOTE_PATH"
            ;;
        3)
            echo -e "${INFO} 配置自定义远程备份${NC}"
            echo "请实现自定义备份逻辑"
            ;;
    esac

    echo -e "${SUCCESS} 远程备份配置完成${NC}"
}

main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        create)
            cmd_create "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        verify)
            cmd_verify "$@"
            ;;
        restore)
            cmd_restore "$@"
            ;;
        delete)
            cmd_delete "$@"
            ;;
        cleanup)
            cmd_cleanup "$@"
            ;;
        schedule)
            cmd_schedule "$@"
            ;;
        remote-setup)
            cmd_remote_setup "$@"
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
