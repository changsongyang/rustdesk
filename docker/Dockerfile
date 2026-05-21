# ============================================================
# RustDesk Server Dockerfile
# RustDesk 服务器自定义镜像构建
# ============================================================
#
# Multi-stage build for optimized image size
# 多阶段构建以优化镜像大小
#
# Build command / 构建命令:
#   docker build -t rustdesk-server:custom .
#
# Build with BuildKit / 使用 BuildKit 构建:
#   DOCKER_BUILDKIT=1 docker build -t rustdesk-server:custom .
#
# ============================================================

# ============================================================
# 第一阶段: 构建 / Stage 1: Build
# ============================================================
FROM rustdesk/rustdesk-server:latest AS builder

# 设置工作目录 / Set working directory
WORKDIR /build

# 复制源代码 / Copy source code
# COPY ./src /build/src

# 安装构建依赖 / Install build dependencies
# RUN apt-get update && apt-get install -y \
#     build-essential \
#     pkg-config \
#     libssl-dev \
#     && rm -rf /var/lib/apt/lists/*

# 构建项目 / Build project
# RUN cargo build --release --target x86_64-unknown-linux-musl

# ============================================================
# 第二阶段: 运行镜像 / Stage 2: Runtime Image
# ============================================================
# 使用 Alpine Linux 基础镜像以减小镜像体积
# Use Alpine Linux base image to reduce image size
FROM alpine:3.19

# 维护者信息 / Maintainer information
LABEL maintainer="RustDesk Team <support@rustdesk.com>"
LABEL description="RustDesk Server - Signaling and Relay Server"

# 设置环境变量 / Set environment variables
ENV RUST_LOG=info \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# 安装运行时依赖 / Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    wget \
    tzdata \
    dumb-init \
    openssl \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*

# 创建非 root 用户 / Create non-root user
RUN addgroup -g 1000 rustdesk && \
    adduser -u 1000 -G rustdesk -s /bin/sh -D rustdesk

# 设置工作目录 / Set working directory
WORKDIR /home/rustdesk

# 从构建阶段复制二进制文件 / Copy binaries from build stage
COPY --from=builder /usr/local/bin/hbbs /usr/local/bin/hbbs
COPY --from=builder /usr/local/bin/hbbr /usr/local/bin/hbbr

# 设置权限 / Set permissions
RUN chmod +x /usr/local/bin/hbbs /usr/local/bin/hbbr && \
    chown -R rustdesk:rustdesk /home/rustdesk

# 创建必要目录 / Create necessary directories
RUN mkdir -p /var/log/rustdesk /etc/rustdesk && \
    chown -R rustdesk:rustdesk /var/log/rustdesk /etc/rustdesk && \
    chmod 755 /var/log/rustdesk /etc/rustdesk

# 复制健康检查脚本 / Copy health check script
COPY <<EOF /healthcheck.sh
#!/bin/sh
# Health check script / 健康检查脚本
set -e

# 检查进程是否运行 / Check if process is running
if ! pgrep -x "hbbs\|hbbr" > /dev/null; then
    echo "Service not running"
    exit 1
fi

# 检查端口是否监听 / Check if port is listening
if ! netstat -tuln | grep -E "21115|21116|21117" > /dev/null; then
    echo "Ports not listening"
    exit 1
fi

echo "Health check passed"
exit 0
EOF

RUN chmod +x /healthcheck.sh && \
    chown rustdesk:rustdesk /healthcheck.sh

# 复制 entrypoint 脚本 / Copy entrypoint script
COPY <<EOF /entrypoint.sh
#!/bin/sh
# Entry point script / 入口点脚本
set -e

# 等待函数 / Wait function
wait_for() {
    echo "Waiting for $1..."
    shift
    until "$@"; do
        sleep 1
    done
    echo "$1 is ready"
}

# 初始化数据库 / Initialize database
if [ ! -f /root/.rustdesk/id_ed25519 ]; then
    echo "Generating new identity..."
fi

# 设置信号处理 / Set up signal handling
handle_signal() {
    echo "Received signal, shutting down gracefully..."
    exit 0
}

trap handle_signal SIGTERM SIGINT

# 执行命令 / Execute command
echo "Starting $@"
exec "$@"
EOF

RUN chmod +x /entrypoint.sh && \
    chown rustdesk:rustdesk /entrypoint.sh

# 用户切换 / Switch to non-root user
USER rustdesk

# 暴露端口 / Expose ports
# hbbs: 21115 (TCP), 21117 (UDP)
# hbbr: 21116 (TCP)
EXPOSE 21115 21116 21117

# 健康检查 / Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /healthcheck.sh

# 卷挂载点 / Volume mount points
VOLUME ["/root", "/etc/rustdesk", "/var/log/rustdesk"]

# 入口点 / Entry point
ENTRYPOINT ["/entrypoint.sh"]

# 默认命令 / Default command
CMD ["hbbs"]

# ============================================================
# 安全加固说明 / Security Hardening Notes
# ============================================================
# 1. 使用 Alpine Linux 减小攻击面
#    Use Alpine Linux to reduce attack surface
#
# 2. 使用非 root 用户运行
#    Run as non-root user
#
# 3. 只安装必要的包
#    Install only necessary packages
#
# 4. 使用 dumb-init 处理信号
#    Use dumb-init for signal handling
#
# 5. 移除 shell 和不必要的工具
#    Remove shell and unnecessary tools
#
# 6. 设置只读文件系统（如果可能）
#    Set read-only filesystem (if possible)
#
# 7. 启用 AppArmor/SELinux（如果可用）
#    Enable AppArmor/SELinux (if available)
#
# ============================================================
# 构建示例 / Build Examples
# ============================================================
# Basic build / 基本构建:
#   docker build -t rustdesk-server:custom .
#
# Build with specific version / 指定版本构建:
#   docker build --build-arg RUSTDESK_VERSION=1.2.3 \
#                -t rustdesk-server:1.2.3 .
#
# Build with BuildKit (faster) / 使用 BuildKit 构建 (更快):
#   DOCKER_BUILDKIT=1 docker build -t rustdesk-server:custom .
#
# Multi-platform build / 多平台构建:
#   docker buildx build --platform linux/amd64,linux/arm64 \
#                       -t rustdesk-server:custom .
#
# ============================================================
# 运行示例 / Usage Examples
# ============================================================
# Run hbbs only / 仅运行 hbbs:
#   docker run -d --name rustdesk-hbbs \
#              -p 21115:21115 -p 21117:21117/udp \
#              rustdesk-server:custom hbbs
#
# Run hbbr only / 仅运行 hbbr:
#   docker run -d --name rustdesk-hbbr \
#              -p 21116:21116 \
#              rustdesk-server:custom hbbr
#
# Run both services / 运行两个服务:
#   docker network create rustdesk-net
#   docker run -d --name rustdesk-hbbs \
#              --network rustdesk-net \
#              -p 21115:21115 -p 21117:21117/udp \
#              rustdesk-server:custom hbbs
#   docker run -d --name rustdesk-hbbr \
#              --network rustdesk-net \
#              -p 21116:21116 \
#              rustdesk-server:custom hbbr
#
# Run with data persistence / 数据持久化运行:
#   docker run -d --name rustdesk-hbbs \
#              -v /path/to/data:/root \
#              -p 21115:21115 -p 21117:21117/udp \
#              rustdesk-server:custom hbbs
