# RustDesk Docker Deployment Guide
# RustDesk Docker 部署指南

## 目录 / Table of Contents

- [概述](#概述)
- [快速开始](#快速开始)
- [单节点部署](#单节点部署)
- [多节点部署 (Docker Swarm)](#多节点部署-docker-swarm)
- [自定义镜像构建](#自定义镜像构建)
- [生产环境配置](#生产环境配置)
- [故障排除](#故障排除)
- [安全加固](#安全加固)
- [备份和恢复](#备份和恢复)
- [监控和日志](#监控和日志)

## 概述

本目录包含 RustDesk Server 的完整 Docker 部署配置，支持单节点和多节点部署场景。

### 包含文件

- `docker-compose.yml` - 单节点 Docker Compose 部署配置
- `docker-swarm.yml` - Docker Swarm 多节点部署配置
- `.env.example` - 环境变量配置模板
- `Dockerfile` - 自定义镜像构建文件

### 组件说明

- **hbbs** - RustDesk 信号服务器 (ID Server)，处理连接请求和用户认证
- **hbbr** - RustDesk 中继服务器 (Relay Server)，数据中转和 P2P 中继
- **nginx** - 可选的反向代理，提供 HTTPS 支持

## 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose v2.0+ 或 Docker Swarm
- 至少 1GB RAM 和 2 核 CPU

### 基本步骤

```bash
# 1. 进入 docker 目录 / Enter docker directory
cd docker

# 2. 复制环境变量配置 / Copy environment configuration
cp .env.example .env

# 3. 编辑 .env 文件（可选）/ Edit .env file (optional)
vim .env

# 4. 启动服务 / Start services
docker-compose up -d

# 5. 查看服务状态 / Check service status
docker-compose ps

# 6. 查看日志 / View logs
docker-compose logs -f
```

## 单节点部署

### 使用 Docker Compose

```bash
# 启动所有服务
docker-compose up -d

# 仅启动 hbbs
docker-compose up -d hbbs

# 仅启动 hbbr
docker-compose up -d hbbr

# 停止所有服务
docker-compose down

# 停止并删除数据卷
docker-compose down -v

# 重启所有服务
docker-compose restart

# 查看服务状态
docker-compose ps

# 查看特定服务日志
docker-compose logs -f hbbs
docker-compose logs -f hbbr
```

### 服务验证

```bash
# 检查 hbbs 健康状态
curl http://localhost:21115/api/info

# 检查 hbbr 健康状态
curl http://localhost:21116/api/info

# 查看容器详细信息
docker inspect rustdesk-hbbs
docker inspect rustdesk-hbbr

# 查看资源使用情况
docker stats
```

### 网络配置

默认使用 bridge 网络模式，配置在 `docker-compose.yml` 的 `networks` 部分。

如需修改网络配置：

```yaml
networks:
  rustdesk-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16
          gateway: 172.30.0.1
```

## 多节点部署 (Docker Swarm)

### 初始化 Swarm 集群

```bash
# 在 manager 节点初始化 / Initialize on manager node
docker swarm init

# 添加 worker 节点 / Add worker node
docker swarm join --token <TOKEN> <MANAGER-IP>:2377

# 查看节点列表 / View node list
docker node ls

# 为节点添加标签 / Add labels to nodes
docker node update --label-add storage=ssd node-1
docker node update --label-add bandwidth=high node-2
```

### 部署 Stack

```bash
# 创建 overlay 网络 / Create overlay network
docker network create -d overlay rustdesk-overlay

# 部署 stack / Deploy stack
docker stack deploy -c docker-swarm.yml rustdesk

# 查看服务列表 / View service list
docker service ls

# 查看服务详情 / View service details
docker service ps rustdesk_hbbs
docker service ps rustdesk_hbbr

# 查看服务日志 / View service logs
docker service logs rustdesk_hbbs
docker service logs rustdesk_hbbr

# 更新服务 / Update services
docker stack deploy -c docker-swarm.yml rustdesk

# 删除 stack / Remove stack
docker stack rm rustdesk
```

### 扩缩容

```bash
# 扩展 hbbr 副本 / Scale hbbr replicas
docker service scale rustdesk_hbbr=4

# 缩减 hbbr 副本 / Scale down hbbr replicas
docker service scale rustdesk_hbbr=2

# 滚动更新镜像版本 / Rolling update image version
docker service update \
  --image rustdesk/rustdesk-server:1.2.3 \
  rustdesk_hbbs
```

## 自定义镜像构建

### 构建自定义镜像

```bash
# 基本构建 / Basic build
docker build -t rustdesk-server:custom .

# 使用 BuildKit 构建（更快）/ Build with BuildKit (faster)
DOCKER_BUILDKIT=1 docker build -t rustdesk-server:custom .

# 多平台构建 / Multi-platform build
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
                    -t rustdesk-server:custom .

# 构建并推送到 Registry / Build and push to registry
docker buildx build --platform linux/amd64 \
                    -t my-registry.com/rustdesk-server:custom \
                    --push .
```

### 使用自定义镜像

在 `.env` 文件中修改：

```env
RUSTDESK_IMAGE=my-registry.com/rustdesk-server
RUSTDESK_TAG=custom
```

## 生产环境配置

### 资源配置建议

根据服务器规格调整资源配置：

```env
# 小型服务器 (< 2 vCPU, 2GB RAM)
HBBS_CPU_LIMIT=0.5
HBBS_MEMORY_LIMIT=256M
HBBR_CPU_LIMIT=1.0
HBBR_MEMORY_LIMIT=512M

# 中型服务器 (2-4 vCPU, 4GB RAM)
HBBS_CPU_LIMIT=1.0
HBBS_MEMORY_LIMIT=512M
HBBR_CPU_LIMIT=2.0
HBBR_MEMORY_LIMIT=1G

# 大型服务器 (> 4 vCPU, 8GB RAM)
HBBS_CPU_LIMIT=2.0
HBBS_MEMORY_LIMIT=1G
HBBR_CPU_LIMIT=4.0
HBBR_MEMORY_LIMIT=2G
```

### 生产环境 .env 示例

```env
# 基础配置 / Base configuration
RUSTDESK_TAG=1.2.3
DEPLOYMENT_ENV=production
RESTART_POLICY=unless-stopped
TZ=Asia/Shanghai

# 资源限制 / Resource limits
HBBS_CPU_LIMIT=1.0
HBBS_MEMORY_LIMIT=512M
HBBR_CPU_LIMIT=2.0
HBBR_MEMORY_LIMIT=1024M

# 日志配置 / Logging configuration
LOG_MAX_SIZE=50m
LOG_MAX_FILES=10

# 网络配置 / Network configuration
NETWORK_DRIVER=bridge
NETWORK_SUBNET=172.28.0.0/16
```

### 高可用性配置

```bash
# Docker Swarm 高可用性部署
docker stack deploy -c docker-swarm.yml rustdesk

# 配置副本数
# hbbs: 至少 2 个副本在 manager 节点
# hbbr: 至少 3 个副本分布在不同节点
```

## 故障排除

### 常见问题

#### 1. 服务无法启动

```bash
# 查看详细日志
docker-compose logs hbbs
docker-compose logs hbbr

# 检查容器状态
docker ps -a

# 检查端口占用
netstat -tuln | grep -E "21115|21116|21117"

# 检查防火墙
ufw status
iptables -L
```

#### 2. 连接失败

```bash
# 检查网络连通性
docker network inspect rustdesk_network

# 测试端口连接
nc -zv localhost 21115
nc -zv localhost 21116

# 查看连接日志
docker-compose logs | grep -i "connection\|error"
```

#### 3. 性能问题

```bash
# 查看资源使用
docker stats

# 检查容器资源限制
docker inspect rustdesk-hbbs | grep -A 10 "Resources"

# 监控网络连接
ss -s

# 查看进程状态
docker top rustdesk-hbbs
docker top rustdesk-hbbr
```

#### 4. 日志文件过大

```bash
# 配置日志轮转（在 .env 中）
LOG_MAX_SIZE=10m
LOG_MAX_FILES=5

# 手动清理日志
truncate -s 0 /var/lib/docker/containers/*/*-json.log

# 查看磁盘使用
df -h
du -sh /var/lib/docker
```

### 调试技巧

```bash
# 进入容器调试
docker exec -it rustdesk-hbbs /bin/sh

# 查看实时日志
docker-compose logs -f --tail=100

# 测试服务健康状态
wget --spider -q http://localhost:21115/api/info
wget --spider -q http://localhost:21116/api/info

# 检查 DNS 解析
docker exec rustdesk-hbbs nslookup localhost

# 网络抓包（需要 tcpdump）
docker exec rustdesk-hbbs tcpdump -i eth0 port 21115
```

### 重置部署

```bash
# 停止所有服务
docker-compose down

# 删除所有数据卷
docker-compose down -v

# 清理 Docker 资源
docker system prune -a --volumes

# 重新创建网络
docker network rm rustdesk_network
docker network create rustdesk_network

# 重新启动服务
docker-compose up -d
```

## 安全加固

### 基本安全措施

1. **使用非 root 用户运行容器**
   已配置在 Dockerfile 中

2. **限制容器权限**
   ```yaml
   security_opt:
     - no-new-privileges:true
   cap_drop:
     - ALL
   ```

3. **使用只读文件系统**
   ```yaml
   security_opt:
     - read-only:rootfs:true
   ```

4. **配置资源限制**
   防止资源耗尽攻击

5. **启用日志审计**
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "5"
   ```

### 网络隔离

```yaml
networks:
  rustdesk-network:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_icc: "false"
```

### SSL/TLS 配置

```bash
# 使用 Let's Encrypt 获取证书
certbot --nginx -d your-domain.com

# 或手动配置证书
# 将证书复制到 ./certs 目录
cp /path/to/fullchain.pem ./certs/
cp /path/to/privkey.pem ./certs/
```

## 备份和恢复

### 备份数据

```bash
# 备份所有数据卷
docker run --rm \
  -v rustdesk_hbbs-data:/data \
  -v $(pwd)/backups:/backups \
  alpine \
  tar czf /backups/hbbs-$(date +%Y%m%d).tar.gz -C /data .

# 备份配置
docker run --rm \
  -v rustdesk_hbbs-config:/config \
  -v $(pwd)/backups:/backups \
  alpine \
  tar czf /backups/hbbs-config-$(date +%Y%m%d).tar.gz -C /config .

# 备份所有
./backup.sh
```

### 恢复数据

```bash
# 恢复 hbbs 数据
docker run --rm \
  -v rustdesk_hbbs-data:/data \
  -v $(pwd)/backups:/backups \
  alpine \
  tar xzf /backups/hbbs-20240101.tar.gz -C /data

# 恢复配置
docker run --rm \
  -v rustdesk_hbbs-config:/config \
  -v $(pwd)/backups:/backups \
  alpine \
  tar xzf /backups/hbbs-config-20240101.tar.gz -C /config

# 重启服务
docker-compose restart
```

## 监控和日志

### 日志管理

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f hbbs
docker-compose logs -f hbbr

# 导出日志
docker-compose logs > logs.txt

# 使用 grep 过滤日志
docker-compose logs | grep -i error
docker-compose logs --since="2024-01-01" > logs-2024.txt
```

### 集成 Prometheus

```bash
# 添加 Prometheus 配置
# 在 prometheus.yml 中添加:
#   - job_name: 'rustdesk'
#     static_configs:
#       - targets: ['localhost:21115', 'localhost:21116']
```

### 集成 Grafana

```bash
# 创建 Grafana 数据源
# 导入 RustDesk 仪表板模板
# 监控指标: 连接数、带宽使用、延迟等
```

### 资源监控

```bash
# 实时资源使用
docker stats

# 查看详细资源信息
docker inspect rustdesk-hbbs | grep -A 20 "Resources"

# 监控系统资源
docker run --rm \
  --pid=host \
  --network=none \
  -v /:/rootfs:ro \
  prom/node-exporter
```

## 更多资源

- [RustDesk 官方文档](https://rustdesk.com/docs/)
- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 官方文档](https://docs.docker.com/compose/)
- [Docker Swarm 官方文档](https://docs.docker.com/engine/swarm/)
- [RustDesk Server GitHub](https://github.com/rustdesk/rustdesk-server)

## 许可证

本项目遵循 RustDesk 相同许可证。
