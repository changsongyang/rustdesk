# RustDesk 部署指南

## 目录

- [1. 概述](#1-概述)
- [2. 快速开始](#2-快速开始)
- [3. 环境要求](#3-环境要求)
- [4. Docker 部署](#4-docker-部署)
  - [4.1 单节点部署](#41-单节点部署)
  - [4.2 多节点部署 (Docker Swarm)](#42-多节点部署-docker-swarm)
  - [4.3 自定义镜像构建](#43-自定义镜像构建)
  - [4.4 生产环境配置](#44-生产环境配置)
  - [4.5 安全加固](#45-安全加固)
  - [4.6 备份和恢复](#46-备份和恢复)
  - [4.7 故障排查](#47-故障排查)
  - [↗ 详细文档](docker/README.md)
- [5. Kubernetes 部署](#5-kubernetes-部署)
  - [5.1 Manifest 部署](#51-manifest-部署)
  - [5.2 Helm Chart 部署](#52-helm-chart-部署)
  - [5.3 自动扩缩容](#53-自动扩缩容)
  - [5.4 持久化存储](#54-持久化存储)
  - [5.5 高可用部署](#55-高可用部署)
  - [5.6 故障排查](#56-故障排查)
  - [↗ 详细文档](k8s/DEPLOYMENT.md)
- [6. 源码编译部署](#6-源码编译部署)
  - [6.1 Linux 平台编译](#61-linux-平台编译)
  - [6.2 Windows 平台编译](#62-windows-平台编译)
  - [6.3 macOS 平台编译](#63-macos-平台编译)
  - [6.4 交叉编译](#64-交叉编译)
  - [↗ Linux 编译详细文档](docs/BUILD_LINUX.md)
  - [↗ Windows 编译详细文档](docs/BUILD_WINDOWS.md)
  - [↗ macOS 编译详细文档](docs/BUILD_MACOS.md)
  - [↗ 交叉编译详细文档](docs/BUILD_CROSS_COMPILE.md)
- [7. 监控部署](#7-监控部署)
  - [7.1 Prometheus 配置](#71-prometheus-配置)
  - [7.2 Grafana 配置](#72-grafana-配置)
  - [7.3 告警配置](#73-告警配置)
  - [7.4 日志收集](#74-日志收集)
  - [↗ 详细文档](monitoring/README.md)
- [8. 一键配置脚本](#8-一键配置脚本)
  - [8.1 环境检测](#81-环境检测)
  - [8.2 安装部署](#82-安装部署)
  - [8.3 服务管理](#83-服务管理)
  - [8.4 备份恢复](#84-备份恢复)
  - [↗ 详细文档](scripts/README.md)
- [9. 中国镜像加速](#9-中国镜像加速)
  - [9.1 Rust/Cargo 镜像](#91-rustcargo-镜像)
  - [9.2 Docker 镜像加速](#92-docker-镜像加速)
  - [9.3 GitHub 镜像加速](#93-github-镜像加速)
  - [9.4 Flutter/Dart 镜像](#94-flutterdart-镜像)
  - [↗ 详细文档](docs/zh/CN_MIRRORS.md)
- [10. 最佳实践](#10-最佳实践)
- [11. 故障排查](#11-故障排查)
- [12. 参考资料](#12-参考资料)

---

## 1. 概述

### 1.1 什么是 RustDesk

RustDesk 是一个开源的远程桌面软件，类似于 TeamViewer 和 AnyDesk。它采用 Rust 语言编写，具有高性能、高安全性的特点。RustDesk 支持自托管部署，用户可以完全控制自己的数据。

### 1.2 部署架构

RustDesk 服务端由两个核心组件组成：

| 组件 | 说明 | 默认端口 |
|------|------|----------|
| **hbbs** | RustDesk ID/HBBS 服务器，处理连接请求和用户认证 | 21115 (TCP/UDP) |
| **hbbr** | RustDesk 中继/Relay 服务器，数据中转和 P2P 中继 | 21116 (TCP), 21117 (TCP) |

### 1.3 部署方式

RustDesk 支持多种部署方式，满足不同规模和场景的需求：

- **Docker 部署**: 适用于快速部署、容器化环境
- **Kubernetes 部署**: 适用于大规模生产环境、自动扩缩容需求
- **源码编译部署**: 适用于定制化需求、完全控制场景
- **一键脚本部署**: 适用于简化部署流程、快速上线

### 1.4 部署方式对比

| 部署方式 | 适用场景 | 难度 | 扩展性 | 维护成本 |
|----------|----------|------|--------|----------|
| Docker Compose | 小型部署、开发测试 | ⭐ | 中 | 低 |
| Docker Swarm | 中型部署、多节点 | ⭐⭐ | 高 | 中 |
| Kubernetes | 大型生产环境 | ⭐⭐⭐ | 极高 | 高 |
| 源码编译 | 定制化需求 | ⭐⭐⭐ | 中 | 中 |
| 一键脚本 | 快速部署 | ⭐ | 中 | 低 |

---

## 2. 快速开始

### 2.1 最简部署（Docker Compose）

如果你想快速体验 RustDesk，使用 Docker Compose 部署是最简单的方式：

```bash
# 1. 进入 docker 目录
cd docker

# 2. 复制环境变量配置
cp .env.example .env

# 3. 启动服务
docker-compose up -d

# 4. 查看服务状态
docker-compose ps

# 5. 查看日志
docker-compose logs -f
```

部署完成后，服务将监听以下端口：

| 端口 | 服务 | 说明 |
|------|------|------|
| 21115 | HBBS | ID 服务器主端口 |
| 21116 | HBBS | ID 服务器 TLS 端口 |
| 21117 | HBBR | 中继服务器端口 |

### 2.2 配置客户端

部署完成后，需要在 RustDesk 客户端进行配置：

1. 打开 RustDesk 客户端
2. 进入设置 -> 网络
3. 设置 ID 服务器地址为你的服务器 IP:21115
4. 设置中继服务器地址为你的服务器 IP:21117
5. 保存设置并重新连接

### 2.3 验证部署

```bash
# 检查服务健康状态
curl http://localhost:21115/api/info
curl http://localhost:21116/api/info

# 检查容器状态
docker-compose ps

# 查看资源使用
docker stats
```

### 2.4 下一步

- 如果你需要更灵活的部署方式，请查看 [Docker 部署](#4-docker-部署)
- 如果你需要在 Kubernetes 集群中部署，请查看 [Kubernetes 部署](#5-kubernetes-部署)
- 如果你需要自定义编译，请查看 [源码编译部署](#6-源码编译部署)
- 如果你想使用自动化脚本，请查看 [一键配置脚本](#8-一键配置脚本)

---

## 3. 环境要求

### 3.1 硬件要求

#### 3.1.1 开发/测试环境

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 2 核 | 4 核或更多 |
| 内存 | 2 GB | 4 GB 或更多 |
| 磁盘空间 | 10 GB | 20 GB 或更多 |
| 网络带宽 | 1 Mbps | 10 Mbps 或更多 |

#### 3.1.2 生产环境（根据并发连接数）

| 用户规模 | CPU | 内存 | 磁盘空间 | 网络带宽 |
|----------|-----|------|----------|----------|
| < 100 并发 | 2 核 | 2 GB | 20 GB | 10 Mbps |
| 100-500 并发 | 4 核 | 4 GB | 50 GB | 50 Mbps |
| 500-1000 并发 | 8 核 | 8 GB | 100 GB | 100 Mbps |
| > 1000 并发 | 16 核 | 16 GB | 200 GB | 1 Gbps |

### 3.2 软件要求

#### 3.2.1 Docker 部署

- Docker 20.10+
- Docker Compose v2.0+ 或 Docker Swarm

#### 3.2.2 Kubernetes 部署

- Kubernetes 1.21+
- kubectl 配置正确
- Helm 3.0+（仅在使用 Helm Chart 时）
- metrics-server（用于 HPA 自动扩缩容）

#### 3.2.3 源码编译

**Linux:**
- Ubuntu 20.04/22.04 LTS
- Debian 10/11/12
- CentOS 8/Rocky Linux 8+
- GCC/Clang 编译器
- Rust 1.70+

**Windows:**
- Windows 10/11 或 Windows Server 2019+
- Visual Studio 2022
- Rust 1.70+

**macOS:**
- macOS 11 (Big Sur) 或更新
- Xcode Command Line Tools
- Rust 1.70+

### 3.3 网络要求

#### 3.3.1 必需端口

| 端口 | 协议 | 用途 | 服务 |
|------|------|------|------|
| 21115 | TCP/UDP | ID/HBBS 服务 | hbbs |
| 21116 | TCP/UDP | 中继连接 | hbbr |
| 21117 | TCP | RUDP 中继 | hbbr |
| 21118 | TCP | NAT 类型测试 | - |
| 21119 | TCP | WebSocket | hbbs |

#### 3.3.2 防火墙配置

确保以下端口已在防火墙/安全组中开放：

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 22/tcp
sudo ufw allow 21115:21119/tcp
sudo ufw allow 21116/udp

# firewalld (CentOS/RHEL/Fedora)
sudo firewall-cmd --permanent --add-port=21115-21119/tcp
sudo firewall-cmd --permanent --add-port=21116/udp
sudo firewall-cmd --reload
```

### 3.4 存储要求

#### 3.4.1 存储容量估算

| 数据类型 | 估算方式 | 建议容量 |
|----------|----------|----------|
| 日志数据 | 每1000连接/天约 100MB | 10-50 GB |
| 临时数据 | 根据使用情况 | 5-10 GB |
| 备份数据 | 根据备份策略 | 20-100 GB |

#### 3.4.2 存储性能要求

- 生产环境建议使用 SSD 存储
- IOPS 要求：根据并发连接数，500-2000 IOPS
- 推荐使用本地 SSD 或高性能云盘

---

## 4. Docker 部署

Docker 部署是 RustDesk 最常用的部署方式，支持单节点和多节点部署。

> **详细信息**: 完整的 Docker 部署文档请参阅 [docker/README.md](docker/README.md)

### 4.1 单节点部署

#### 4.1.1 基本部署

```bash
# 进入 docker 目录
cd docker

# 复制环境变量配置
cp .env.example .env

# 编辑 .env 文件配置
vim .env

# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

#### 4.1.2 服务管理

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 停止并删除数据卷
docker-compose down -v

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f hbbs
docker-compose logs -f hbbr
```

#### 4.1.3 服务验证

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

### 4.2 多节点部署 (Docker Swarm)

#### 4.2.1 初始化 Swarm 集群

```bash
# 在 manager 节点初始化
docker swarm init

# 添加 worker 节点
docker swarm join --token <TOKEN> <MANAGER-IP>:2377

# 查看节点列表
docker node ls

# 为节点添加标签
docker node update --label-add storage=ssd node-1
docker node update --label-add bandwidth=high node-2
```

#### 4.2.2 部署 Stack

```bash
# 创建 overlay 网络
docker network create -d overlay rustdesk-overlay

# 部署 stack
docker stack deploy -c docker-swarm.yml rustdesk

# 查看服务列表
docker service ls

# 查看服务详情
docker service ps rustdesk_hbbs
docker service ps rustdesk_hbbr
```

#### 4.2.3 扩缩容

```bash
# 扩展 hbbr 副本
docker service scale rustdesk_hbbr=4

# 缩减 hbbr 副本
docker service scale rustdesk_hbbr=2

# 滚动更新镜像版本
docker service update \
  --image rustdesk/rustdesk-server:1.2.3 \
  rustdesk_hbbs
```

### 4.3 自定义镜像构建

#### 4.3.1 构建自定义镜像

```bash
# 基本构建
docker build -t rustdesk-server:custom .

# 使用 BuildKit 构建（更快）
DOCKER_BUILDKIT=1 docker build -t rustdesk-server:custom .

# 多平台构建
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
                    -t rustdesk-server:custom .
```

#### 4.3.2 使用自定义镜像

在 `.env` 文件中修改：

```env
RUSTDESK_IMAGE=my-registry.com/rustdesk-server
RUSTDESK_TAG=custom
```

### 4.4 生产环境配置

#### 4.4.1 资源配置建议

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

#### 4.4.2 生产环境 .env 示例

```env
# 基础配置
RUSTDESK_TAG=1.2.3
DEPLOYMENT_ENV=production
RESTART_POLICY=unless-stopped
TZ=Asia/Shanghai

# 资源限制
HBBS_CPU_LIMIT=1.0
HBBS_MEMORY_LIMIT=512M
HBBR_CPU_LIMIT=2.0
HBBR_MEMORY_LIMIT=1024M

# 日志配置
LOG_MAX_SIZE=50m
LOG_MAX_FILES=10

# 网络配置
NETWORK_DRIVER=bridge
NETWORK_SUBNET=172.28.0.0/16
```

### 4.5 安全加固

#### 4.5.1 基本安全措施

```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
```

#### 4.5.2 使用只读文件系统

```yaml
security_opt:
  - read-only:rootfs:true
```

#### 4.5.3 SSL/TLS 配置

```bash
# 使用 Let's Encrypt 获取证书
certbot --nginx -d your-domain.com

# 或手动配置证书
# 将证书复制到 ./certs 目录
cp /path/to/fullchain.pem ./certs/
cp /path/to/privkey.pem ./certs/
```

### 4.6 备份和恢复

#### 4.6.1 备份数据

```bash
# 备份所有数据卷
docker run --rm \
  -v rustdesk_hbbs-data:/data \
  -v $(pwd)/backups:/backups \
  alpine \
  tar czf /backups/hbbs-$(date +%Y%m%d).tar.gz -C /data .

# 使用备份脚本
./backup.sh
```

#### 4.6.2 恢复数据

```bash
# 恢复 hbbs 数据
docker run --rm \
  -v rustdesk_hbbs-data:/data \
  -v $(pwd)/backups:/backups \
  alpine \
  tar xzf /backups/hbbs-20240101.tar.gz -C /data

# 重启服务
docker-compose restart
```

### 4.7 故障排查

#### 4.7.1 常见问题

**服务无法启动:**
```bash
# 查看详细日志
docker-compose logs hbbs
docker-compose logs hbbr

# 检查容器状态
docker ps -a

# 检查端口占用
netstat -tuln | grep -E "21115|21116|21117"
```

**连接失败:**
```bash
# 检查网络连通性
docker network inspect rustdesk_network

# 测试端口连接
nc -zv localhost 21115
nc -zv localhost 21116

# 查看连接日志
docker-compose logs | grep -i "connection\|error"
```

**性能问题:**
```bash
# 查看资源使用
docker stats

# 检查容器资源限制
docker inspect rustdesk-hbbs | grep -A 10 "Resources"
```

#### 4.7.2 调试技巧

```bash
# 进入容器调试
docker exec -it rustdesk-hbbs /bin/sh

# 查看实时日志
docker-compose logs -f --tail=100

# 测试服务健康状态
wget --spider -q http://localhost:21115/api/info
```

#### 4.7.3 重置部署

```bash
# 停止所有服务
docker-compose down

# 删除所有数据卷
docker-compose down -v

# 清理 Docker 资源
docker system prune -a --volumes

# 重新启动服务
docker-compose up -d
```

---

## 5. Kubernetes 部署

Kubernetes 部署适用于大规模生产环境，支持自动扩缩容和高可用性。

> **详细信息**: 完整的 Kubernetes 部署文档请参阅 [k8s/DEPLOYMENT.md](k8s/DEPLOYMENT.md)

### 5.1 Manifest 部署

#### 5.1.1 快速部署

```bash
# 创建命名空间
kubectl apply -f k8s/manifests/namespace.yaml

# 部署 ConfigMap 和 Secret
kubectl apply -f k8s/manifests/configmap.yaml
kubectl apply -f k8s/manifests/secret.yaml

# 部署 PVC（可选）
kubectl apply -f k8s/manifests/pvc.yaml

# 部署 Deployment
kubectl apply -f k8s/manifests/deployment-hbbs.yaml
kubectl apply -f k8s/manifests/deployment-hbbr.yaml

# 部署 Service
kubectl apply -f k8s/manifests/service.yaml

# 一键部署
kubectl apply -f k8s/manifests/
```

#### 5.1.2 验证部署

```bash
kubectl get pods -n rustdesk
kubectl get services -n rustdesk
kubectl get deployments -n rustdesk
```

#### 5.1.3 查看日志

```bash
# HBBS 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbs --tail=50

# HBBR 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbr --tail=50
```

### 5.2 Helm Chart 部署

#### 5.2.1 安装 Helm Chart

```bash
# 添加 Helm 仓库
helm repo add rustdesk https://rustdesk.github.io/rustdesk
helm repo update

# 基础安装
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace
```

#### 5.2.2 自定义配置

```bash
# 查看可配置参数
helm show values rustdesk/rustdesk-server

# 创建自定义配置文件
vim production-values.yaml
```

配置示例：

```yaml
replicaCount: 3

image:
  tag: "1.2.0"

resources:
  hbbs:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  hbbr:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 2000m
      memory: 2Gi

autoscaling:
  enabled: true
  hbbs:
    minReplicas: 3
    maxReplicas: 10
  hbbr:
    minReplicas: 3
    maxReplicas: 10

persistence:
  data:
    size: 50Gi
  logs:
    size: 10Gi
```

```bash
# 使用自定义配置安装
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f production-values.yaml
```

#### 5.2.3 Helm 管理命令

```bash
# 升级
helm upgrade rustdesk rustdesk/rustdesk-server -n rustdesk

# 回滚
helm rollback rustdesk -n rustdesk

# 卸载
helm uninstall rustdesk -n rustdesk
```

### 5.3 自动扩缩容

#### 5.3.1 基于 CPU 和内存

```yaml
autoscaling:
  enabled: true
  hbbs:
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
  hbbr:
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

#### 5.3.2 自定义 HPA 行为

```yaml
autoscaling:
  enabled: true
  hbbs:
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    behavior:
      scaleDown:
        stabilizationWindowSeconds: 300
        policies:
          - type: Percent
            value: 10
            periodSeconds: 60
      scaleUp:
        stabilizationWindowSeconds: 0
        policies:
          - type: Percent
            value: 100
            periodSeconds: 15
```

### 5.4 持久化存储

#### 5.4.1 使用默认 StorageClass

```yaml
persistence:
  enabled: true
  data:
    storageClass: "standard"
    size: "10Gi"
  logs:
    storageClass: "standard"
    size: "5Gi"
```

#### 5.4.2 使用 NFS 存储

```yaml
persistence:
  enabled: true
  data:
    storageClass: "nfs-client"
    size: "50Gi"
    accessMode: ReadWriteMany
  logs:
    storageClass: "nfs-client"
    size: "10Gi"
    accessMode: ReadWriteMany
```

#### 5.4.3 禁用持久化

```yaml
persistence:
  enabled: false
```

### 5.5 高可用部署

#### 5.5.1 生产环境推荐配置

```yaml
replicaCount: 3

image:
  tag: "latest"
  pullPolicy: Always

resources:
  hbbs:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  hbbr:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2000m
      memory: 2Gi

autoscaling:
  enabled: true
  hbbs:
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 60
    targetMemoryUtilizationPercentage: 70
  hbbr:
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 60
    targetMemoryUtilizationPercentage: 70

persistence:
  enabled: true
  data:
    storageClass: "nfs-client"
    size: "100Gi"
    accessMode: ReadWriteMany
  logs:
    storageClass: "nfs-client"
    size: "20Gi"
    accessMode: ReadWriteMany

podDisruptionBudget:
  enabled: true
  minAvailable: 2

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/component: ""
        topologyKey: topology.kubernetes.io/zone
```

### 5.6 故障排查

#### 5.6.1 Pod 无法启动

```bash
kubectl describe pod <pod-name> -n rustdesk
kubectl logs <pod-name> -n rustdesk
```

#### 5.6.2 PVC 无法挂载

```bash
kubectl describe pvc <pvc-name> -n rustdesk
kubectl get events -n rustdesk --field-selector involvedObject.name=<pvc-name>

# 检查 StorageClass
kubectl get storageclass
```

#### 5.6.3 HPA 不工作

```bash
# 确保 metrics-server 已安装
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top pods -n rustdesk
```

#### 5.6.4 服务无法访问

```bash
# 检查 Service 配置
kubectl get svc -n rustdesk
kubectl describe svc <service-name> -n rustdesk

# 检查端点
kubectl get endpoints -n rustdesk
```

#### 5.6.5 调试命令

```bash
# 查看所有资源
kubectl get all -n rustdesk

# 查看 Events
kubectl get events -n rustdesk --sort-by='.lastTimestamp'

# 进入 Pod 调试
kubectl run -it --rm debug --image=busybox --restart=Never -n rustdesk -- sh

# 端口转发测试
kubectl port-forward -n rustdesk svc/rustdesk-hbbs-service 21115:21115
```

---

## 6. 源码编译部署

源码编译部署适用于需要完全控制或进行定制化开发的场景。

> **详细信息**:
> - [Linux 编译详细文档](docs/BUILD_LINUX.md)
> - [Windows 编译详细文档](docs/BUILD_WINDOWS.md)
> - [macOS 编译详细文档](docs/BUILD_MACOS.md)
> - [交叉编译详细文档](docs/BUILD_CROSS_COMPILE.md)

### 6.1 Linux 平台编译

#### 6.1.1 环境准备

**Ubuntu/Debian:**

```bash
# 安装基础编译工具
sudo apt update
sudo apt install -y build-essential cmake ninja-build pkg-config git curl

# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup target add x86_64-unknown-linux-gnu

# 安装系统库
sudo apt install -y \
    libssl-dev libxdo-dev libxcb-shape0-dev libxcb-xfixes0-dev \
    libxkbcommon-dev libxkbcommon-x11-dev libgl1-mesa-dev \
    libasound2-dev libpulse-dev protobuf-compiler libprotobuf-dev \
    libavcodec-dev libavformat-dev libswscale-dev libopus-dev libvpx-dev
```

**CentOS/RHEL/Rocky Linux:**

```bash
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y cmake ninja-build pkg-config git curl
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup target add x86_64-unknown-linux-gnu
```

#### 6.1.2 编译步骤

```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 初始化子模块
git submodule update --init --recursive

# 编译 Release 版本
cargo build --release

# 编译后的二进制文件位于：
# target/release/hbbs   - RustDesk ID/HBBS 服务器
# target/release/hbrs   - RustDesk 中继服务器
```

#### 6.1.3 编译优化

```bash
# 启用 LTO 和优化
export RUSTFLAGS="-C lto=fat -C codegen-units=1 -C opt-level=3"

# 指定目标 CPU（Intel Haswell 及更新 / AMD Zen 及更新）
export RUSTFLAGS="-C target-cpu=haswell"

cargo build --release
```

### 6.2 Windows 平台编译

#### 6.2.1 环境准备

1. 安装 Visual Studio 2022（含 C++ 桌面开发工作负载）
2. 安装 Rust: `irm https://rustup.rs -OutFile rustup-init.exe`
3. 配置 vcpkg: `git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg`

```powershell
# 添加 MSVC 目标平台
rustup target add x86_64-pc-windows-msvc

# 安装 vcpkg 依赖
cd C:\vcpkg
.\vcpkg install ffmpeg:x64-windows libvpx:x64-windows opus:x64-windows libsodium:x64-windows
.\vcpkg integrate install
```

#### 6.2.2 编译步骤

```powershell
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 初始化子模块
git submodule update --init --recursive

# 编译 Release 版本
cargo build --release

# 编译后的二进制文件位于：
# target\release\hbbs.exe   - RustDesk ID/HBBS 服务器
# target\release\hbrs.exe   - RustDesk 中继服务器
```

### 6.3 macOS 平台编译

#### 6.3.1 环境准备

```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 安装 Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 添加目标平台
rustup target add aarch64-apple-darwin  # Apple Silicon
rustup target add x86_64-apple-darwin   # Intel Mac

# 安装依赖
brew install cmake ninja pkg-config ffmpeg opus libvpx nasm
```

#### 6.3.2 编译步骤

```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 初始化子模块
git submodule update --init --recursive

# 编译 Release 版本
cargo build --release

# 编译后的二进制文件位于：
# target/release/hbbs   - RustDesk ID/HBBS 服务器
# target/release/hbrs   - RustDesk 中继服务器
```

### 6.4 交叉编译

#### 6.4.1 Linux 到 ARM 交叉编译

```bash
# 安装交叉编译工具链
sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# 添加 Rust 目标平台
rustup target add aarch64-unknown-linux-gnu

# 配置 .cargo/config.toml
cat >> ~/.cargo/config.toml << 'EOF'
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"
EOF

# 编译
cargo build --release --target aarch64-unknown-linux-gnu
```

#### 6.4.2 Linux 到 Windows (MinGW) 交叉编译

```bash
# 安装 MinGW
sudo apt install -y mingw-w64

# 编译
cargo build --release --target x86_64-pc-windows-gnu
```

---

## 7. 监控部署

完整的监控解决方案，包括 Prometheus、Grafana、AlertManager 和日志收集系统。

> **详细信息**: 完整的监控部署文档请参阅 [monitoring/README.md](monitoring/README.md)

### 7.1 Prometheus 配置

#### 7.1.1 Prometheus 主配置

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'rustdesk'
    static_configs:
      - targets: ['localhost:21115', 'localhost:21116']
    metrics_path: '/metrics'
```

#### 7.1.2 监控指标

**RustDesk 服务指标:**
- `rustdesk_active_connections_total`: 活跃连接数
- `rustdesk_requests_total`: 请求总数
- `rustdesk_request_duration_seconds_bucket`: 请求延迟分布
- `rustdesk_network_bytes_total`: 网络流量
- `rustdesk_relay_connections_total`: 中继连接数
- `rustdesk_relay_latency_seconds_bucket`: 中继延迟分布

**系统指标:**
- `node_cpu_seconds_total`: CPU 使用时间
- `node_memory_MemAvailable_bytes`: 可用内存
- `node_filesystem_avail_bytes`: 可用磁盘空间

### 7.2 Grafana 配置

#### 7.2.1 导入仪表板

导入 `grafana/dashboards/rustdesk-overview.json` 仪表板，包含：

- 服务状态概览
- 性能指标（连接数、带宽、延迟）
- 系统资源使用（CPU、内存、磁盘）
- 连接质量（中继延迟、带宽）
- 告警历史

#### 7.2.2 服务访问

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
- **AlertManager**: http://localhost:9093

### 7.3 告警配置

#### 7.3.1 告警规则

**严重告警 (Critical):**
- RustDesk 服务宕机
- 中继服务宕机
- Rendezvous 服务宕机

**警告告警 (Warning):**
- CPU 使用率超过 80%
- 内存使用率超过 85%
- 磁盘使用率超过 85%
- 连接数超过 1000
- 请求延迟 P95 超过 1 秒

#### 7.3.2 告警通知配置

**Email 配置:**
```yaml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'alertmanager@example.com'
  smtp_auth_password: 'your-password'
```

**Slack 配置:**
```yaml
receivers:
  - name: 'critical-receiver'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'
        channel: '#alerts'
```

### 7.4 日志收集

#### 7.4.1 Filebeat 配置

Filebeat 收集以下日志：

- Docker 容器日志
- RustDesk 服务日志
  - `/var/log/rustdesk/hbbs.log`
  - `/var/log/rustdesk/hbbr.log`

#### 7.4.2 ELK 集成

可选的 ELK 集成配置：

1. 安装 Elasticsearch、Kibana、Logstash
2. 配置 Filebeat 输出到 Logstash
3. 在 Kibana 中创建日志索引

#### 7.4.3 Loki + Grafana 替代方案

```yaml
loki:
  image: grafana/loki:2.8.0
  ports:
    - "3100:3100"

promtail:
  image: grafana/promtail:2.8.0
  volumes:
    - /var/log:/var/log
```

---

## 8. 一键配置脚本

完整的自动化部署、维护和备份解决方案。

> **详细信息**: 完整的脚本系统文档请参阅 [scripts/README.md](scripts/README.md)

### 8.1 环境检测

```bash
# Linux/macOS
cd scripts/linux
chmod +x *.sh
./check-env.sh

# Windows
cd scripts\windows
.\check-env.ps1
```

自动检测内容：
- 操作系统类型和版本
- Docker 和 Docker Compose 安装情况
- Kubernetes 和 kubectl (可选)
- 系统资源占用 (CPU、内存、磁盘)
- 端口可用性
- 网络连通性
- 防火墙状态

### 8.2 安装部署

```bash
# Linux/macOS
sudo ./install.sh

# Windows
.\install.ps1
```

支持的部署模式：
- **Docker Compose** (推荐)
- **Kubernetes** (待实现)
- **源码编译** (待实现)

### 8.3 服务管理

```bash
# Linux/macOS
./manage.sh status          # 查看状态
./manage.sh logs hbbs       # 查看日志
./manage.sh restart         # 重启服务

# Windows
.\manage.ps1 -Command status
.\manage.ps1 -Command logs
.\manage.ps1 -Command restart
```

支持的操作：
- `start` - 启动服务
- `stop` - 停止服务
- `restart` - 重启服务
- `status` - 查看状态
- `logs [服务]` - 查看日志
- `health` - 健康检查
- `stats` - 连接统计
- `config [操作]` - 配置管理
- `update` - 更新服务
- `cleanup` - 清理资源

### 8.4 备份恢复

```bash
# Linux/macOS
./backup.sh create          # 创建备份
./backup.sh list            # 列出备份
./backup.sh restore <备份名> # 恢复备份

# Windows
.\backup.ps1 -Command create
.\backup.ps1 -Command list
.\backup.ps1 -Command restore
```

备份特性：
- 支持 gzip/bzip2/xz 压缩
- 支持 AES-256 加密
- 支持远程备份 (S3/SFTP)
- 备份完整性验证
- 备份元数据记录

---

## 9. 中国镜像加速

针对中国用户的镜像加速配置，包括 Rust、Cargo、Docker 和 GitHub。

> **详细信息**: 完整的镜像加速文档请参阅 [docs/zh/CN_MIRRORS.md](docs/zh/CN_MIRRORS.md)

### 9.1 Rust/Cargo 镜像

#### 9.1.1 镜像源列表

| 镜像名称 | 地址 | 说明 |
|----------|------|------|
| rsproxy（推荐） | `sparse+https://rsproxy.cn/index/` | 最新推荐的稀疏索引方式 |
| 中科大 | `sparse+https://mirrors.ustc.edu.cn/crates.io-index/` | 稀疏索引方式 |
| 清华大学 | `sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/` | 稀疏索引方式 |
| 阿里云 | `sparse+https://mirrors.aliyun.com/crates.io-index/` | 稀疏索引方式 |

#### 9.1.2 配置方法

创建或编辑 `~/.cargo/config.toml`：

```toml
[source.crates-io]
replace-with = 'rsproxy-sparse'

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[net]
git-fetch-with-cli = true
```

#### 9.1.3 环境变量配置

```bash
# Linux/macOS
export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
export RUSTUP_DIST_SERVER=https://rsproxy.cn
export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup

# Windows PowerShell
$env:CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"
$env:RUSTUP_DIST_SERVER="https://rsproxy.cn"
$env:RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
```

### 9.2 Docker 镜像加速

#### 9.2.1 daemon.json 配置

编辑 `/etc/docker/daemon.json` (Linux) 或 `%PROGRAMDATA%\Docker\config\daemon.json` (Windows)：

```json
{
  "registry-mirrors": [
    "https://<your-id>.mirror.aliyuncs.com",
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
```

#### 9.2.2 常用镜像加速器

| 加速器 | 地址 | 说明 |
|--------|------|------|
| 阿里云 | `https://xxx.mirror.aliyuncs.com` | 需要登录获取专属地址 |
| 腾讯云 | `https://mirror.ccs.tencentyun.com` | 腾讯云镜像加速 |
| 中科大 | `https://docker.mirrors.ustc.edu.cn` | 适合内网部署 |
| DaoCloud | `https://docker.m.daocloud.io` | 跨境加速 |

### 9.3 GitHub 镜像加速

#### 9.3.1 Git 协议优化

```bash
# 使用 fastgit 镜像
git config --global url."https://hub.fastgit.xyz/".insteadOf "https://github.com"
git config --global url."https://hub.fastgit.xyz/".insteadOf "git@github.com:"

# 使用 ghproxy 代理
git config --global url."https://ghproxy.com/".insteadOf "https://github.com"
git config --global url."https://ghproxy.com/".insteadOf "git@github.com:"
```

#### 9.3.2 常用 GitHub 镜像

| 镜像名称 | 地址 | 说明 |
|----------|------|------|
| fastgit | `https://hub.fastgit.xyz/` | 全球 CDN 加速 |
| ghproxy | `https://ghproxy.com/` | 提供代理加速 |
| gitclone | `https://gitclone.com/` | 国内镜像 |
| mirror.ghproxy | `https://ghproxy.cn/` | 代理镜像 |

### 9.4 Flutter/Dart 镜像

```bash
# 设置 Flutter 镜像
flutter config --global pub url https://pub.flutter-io.cn

# 设置 Dart 镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

---

## 10. 最佳实践

### 10.1 部署最佳实践

#### 10.1.1 生产环境部署

1. **使用 Docker 或 Kubernetes 部署**
   - 便于管理、扩缩容和维护
   - 建议使用 Docker Compose 或 Kubernetes

2. **配置资源限制**
   ```yaml
   resources:
     limits:
       cpu: "2"
       memory: 2G
     reservations:
       cpu: "1"
       memory: 1G
   ```

3. **启用健康检查**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:21115/api/info"]
     interval: 30s
     timeout: 10s
     retries: 3
   ```

4. **配置日志轮转**
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "5"
   ```

5. **启用自动重启**
   ```yaml
   restart: unless-stopped
   ```

#### 10.1.2 安全最佳实践

1. **使用非 root 用户运行容器**
2. **限制容器权限**
   ```yaml
   security_opt:
     - no-new-privileges:true
   cap_drop:
     - ALL
   ```
3. **配置 TLS/SSL 加密**
4. **使用强密钥和密码**
5. **配置防火墙规则**
6. **定期更新镜像版本**

#### 10.1.3 性能最佳实践

1. **使用 SSD 存储**
2. **配置合适的资源限制**
3. **启用 LTO 优化编译**
   ```bash
   export RUSTFLAGS="-C lto=fat -C codegen-units=1"
   ```
4. **使用目标 CPU 优化**
   ```bash
   export RUSTFLAGS="-C target-cpu=haswell"
   ```
5. **配置合适的副本数**
6. **使用负载均衡器分发流量**

### 10.2 监控最佳实践

1. **部署完整的监控栈**
   - Prometheus + Grafana + AlertManager

2. **配置合理的告警阈值**
   - CPU > 80%
   - Memory > 85%
   - Disk > 85%
   - Connection > 1000

3. **配置多个通知渠道**
   - Email
   - Slack/Telegram
   - Webhook

4. **定期检查监控数据**
   - 查看趋势
   - 分析异常
   - 优化配置

### 10.3 备份最佳实践

1. **配置自动备份**
   - 每日增量备份
   - 每周全量备份
   - 异地备份

2. **测试恢复流程**
   - 定期测试备份恢复
   - 验证备份完整性
   - 文档化恢复步骤

3. **加密敏感数据**
   - 使用 AES-256 加密备份
   - 安全存储密钥

### 10.4 网络最佳实践

1. **开放必需端口**
   | 端口 | 协议 | 说明 |
   |------|------|------|
   | 21115 | TCP/UDP | ID 服务器 |
   | 21116 | TCP/UDP | 中继连接 |
   | 21117 | TCP | RUDP 中继 |
   | 21118 | TCP | NAT 测试 |
   | 21119 | TCP | WebSocket |

2. **配置防火墙规则**
   - 仅允许必要的入站流量
   - 使用云服务商的安全组
   - 启用 DDoS 防护（如果提供）

3. **使用 CDN/WAF**
   - 隐藏真实服务器 IP
   - 加速静态资源
   - 提供额外安全层

---

## 11. 故障排查

### 11.1 常见问题

#### 11.1.1 Docker 部署问题

**服务无法启动:**
```bash
# 查看详细日志
docker-compose logs hbbs
docker-compose logs hbbr

# 检查容器状态
docker ps -a

# 检查端口占用
netstat -tuln | grep -E "21115|21116|21117"
```

**连接失败:**
```bash
# 检查网络连通性
docker network inspect rustdesk_network

# 测试端口连接
nc -zv localhost 21115
nc -zv localhost 21116
```

**镜像拉取失败:**
```bash
# 检查 Docker 配置
docker info | grep -A 10 "Registry Mirrors"

# 重启 Docker 服务
sudo systemctl restart docker
```

#### 11.1.2 Kubernetes 部署问题

**Pod 无法启动:**
```bash
kubectl describe pod <pod-name> -n rustdesk
kubectl logs <pod-name> -n rustdesk
```

**PVC 无法挂载:**
```bash
kubectl describe pvc <pvc-name> -n rustdesk
kubectl get events -n rustdesk --field-selector involvedObject.name=<pvc-name>
kubectl get storageclass
```

**HPA 不工作:**
```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top pods -n rustdesk
```

#### 11.1.3 编译问题

**编译错误:**
```bash
# 清理并重新编译
cargo clean
cargo build --release

# 检查依赖
cargo build --release -vv
```

**缺少依赖:**
```bash
# Ubuntu/Debian
sudo apt install -y libssl-dev libxdo-dev protobuf-compiler

# macOS
brew install ffmpeg opus libvpx nasm
```

**内存不足:**
```bash
# 减少并行编译数
cargo build --release -j 2

# 或创建交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 11.2 性能问题

#### 11.2.1 CPU 使用率过高

```bash
# 查看进程状态
top -p $(pgrep hbbs)

# 限制 CPU 使用
docker update --cpus 1.0 rustdesk-hbbs
```

#### 11.2.2 内存泄漏

```bash
# 检查内存使用
free -h
docker stats

# 重启服务
docker-compose restart
```

#### 11.2.3 网络延迟

```bash
# 测试网络延迟
ping <server-ip>

# 检查网络配置
docker network inspect rustdesk_network
```

### 11.3 连接问题

#### 11.3.1 防火墙阻止

```bash
# 检查防火墙状态
sudo ufw status
sudo firewall-cmd --list-all

# 开放端口
sudo ufw allow 21115/tcp
sudo ufw allow 21116/tcp
sudo ufw allow 21116/udp
```

#### 11.3.2 端口被占用

```bash
# Linux
netstat -tuln | grep 21115

# Windows
netstat -ano | findstr 21115

# 释放端口
sudo kill -9 <PID>
```

#### 11.3.3 DNS 解析问题

```bash
# 检查 DNS
nslookup <domain>

# 使用 IP 地址代替域名测试
```

### 11.4 日志分析

#### 11.4.1 查看日志

```bash
# Docker
docker-compose logs -f

# Systemd
sudo journalctl -u rustdesk-hbbs -f
sudo journalctl -u rustdesk-hbrs -f

# Kubernetes
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbs -f
```

#### 11.4.2 分析日志

```bash
# 查找错误
docker-compose logs | grep -i error

# 按时间过滤
docker-compose logs --since "1 hour ago"

# 导出日志
docker-compose logs > logs.txt
```

### 11.5 获取帮助

如果以上方法无法解决问题，请：

1. 收集诊断信息：
   ```bash
   # Docker
   docker-compose logs > docker-logs.txt
   docker inspect rustdesk-hbbs > hbbs-inspect.json
   docker stats > docker-stats.txt

   # Kubernetes
   kubectl get all -n rustdesk -o yaml > k8s-resources.yaml
   kubectl describe pods -n rustdesk > pods-describe.txt
   ```

2. 查看官方文档：
   - [RustDesk 官方文档](https://rustdesk.com/docs/)
   - [RustDesk GitHub Issues](https://github.com/rustdesk/rustdesk/issues)

3. 提交 Issue：
   - 提供详细的错误信息
   - 附上诊断信息
   - 说明复现步骤

---

## 12. 参考资料

### 12.1 官方文档

- [RustDesk 官网](https://rustdesk.com)
- [RustDesk 文档](https://rustdesk.com/docs/)
- [RustDesk GitHub](https://github.com/rustdesk/rustdesk)
- [RustDesk Server GitHub](https://github.com/rustdesk/rustdesk-server)

### 12.2 相关技术文档

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 官方文档](https://docs.docker.com/compose/)
- [Docker Swarm 官方文档](https://docs.docker.com/engine/swarm/)
- [Kubernetes 官方文档](https://kubernetes.io/zh/docs/)
- [Helm 官方文档](https://helm.sh/zh/docs/)
- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 官方文档](https://grafana.com/docs/)

### 12.3 详细部署文档

- [Docker 部署详细文档](docker/README.md)
- [Kubernetes 部署详细文档](k8s/DEPLOYMENT.md)
- [监控部署详细文档](monitoring/README.md)
- [脚本系统详细文档](scripts/README.md)
- [Linux 编译详细文档](docs/BUILD_LINUX.md)
- [Windows 编译详细文档](docs/BUILD_WINDOWS.md)
- [macOS 编译详细文档](docs/BUILD_MACOS.md)
- [交叉编译详细文档](docs/BUILD_CROSS_COMPILE.md)
- [中国镜像加速详细文档](docs/zh/CN_MIRRORS.md)

### 12.4 许可证

RustDesk 采用 AGPL-3.0 许可证开源。

---

*本文档由 RustDesk 团队维护，最后更新于 2024 年。*
