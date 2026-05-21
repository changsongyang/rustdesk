# RustDesk Kubernetes 快速开始指南

## 概述

本指南帮助你快速在 Kubernetes 集群上部署 RustDesk 服务端。

## 前提条件

- Kubernetes 1.21+ 集群
- kubectl 已配置
- Helm 3.0+ (可选)

## 快速安装

### 方式一：Helm Chart (推荐)

```bash
# 添加 Helm 仓库
helm repo add rustdesk https://rustdesk.github.io/rustdesk
helm repo update

# 安装 RustDesk
helm install rustdesk rustdesk/rustdesk-server \
  --namespace rustdesk \
  --create-namespace

# 查看部署状态
kubectl get pods -n rustdesk
```

### 方式二：Kubernetes Manifest

```bash
# 部署所有资源
kubectl apply -f k8s/manifests/

# 查看部署状态
kubectl get pods -n rustdesk
```

### 方式三：使用安装脚本

```bash
# 使用 Helm 安装
chmod +x k8s/scripts/install-rustdesk.sh
./k8s/scripts/install-rustdesk.sh --method helm

# 使用 Manifest 安装
./k8s/scripts/install-rustdesk.sh --method manifest
```

## 验证部署

```bash
# 检查所有资源
kubectl get all -n rustdesk

# 查看 Pod 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbs --tail=50

# 检查服务
kubectl get svc -n rustdesk
```

## 配置 RustDesk 客户端

部署完成后，获取节点 IP 并配置客户端：

```bash
# 获取节点 IP
kubectl get nodes -o wide

# 或获取 LoadBalancer IP
kubectl get svc -n rustdesk -l app.kubernetes.io/component=hbbs
```

在 RustDesk 客户端设置中：
- **ID Server**: `<node-ip>:32115`
- **Relay Server**: `<node-ip>:32116`

## 常用命令

### 查看状态

```bash
# 查看 Pods
kubectl get pods -n rustdesk

# 查看 Deployments
kubectl get deployments -n rustdesk

# 查看 Services
kubectl get svc -n rustdesk

# 查看 HPA
kubectl get hpa -n rustdesk

# 查看 PVC
kubectl get pvc -n rustdesk
```

### 扩展服务

```bash
# 手动扩展 HBBS
kubectl scale deployment rustdesk-hbbs -n rustdesk --replicas=3

# 手动扩展 HBBR
kubectl scale deployment rustdesk-hbbr -n rustdesk --replicas=3

# 查看 HPA 状态
kubectl get hpa -n rustdesk
kubectl describe hpa rustdesk-hbbs-hpa -n rustdesk
```

### 查看日志

```bash
# HBBS 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbs --tail=100 -f

# HBBR 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbr --tail=100 -f

# 查看特定 Pod
kubectl logs -n rustdesk deployment/rustdesk-hbbs --tail=100
```

### 故障排查

```bash
# 查看资源详情
kubectl describe pod -n rustdesk -l app.kubernetes.io/component=hbbs

# 查看事件
kubectl get events -n rustdesk --sort-by='.lastTimestamp'

# 进入 Pod 调试
kubectl run -it --rm debug --image=busybox:latest -n rustdesk -- sh

# 端口转发测试
kubectl port-forward -n rustdesk svc/rustdesk-hbbs-service 21115:21115
```

## 自定义配置

### Helm Chart 自定义

```bash
# 使用自定义配置安装
helm install rustdesk rustdesk/rustdesk-server \
  --namespace rustdesk \
  --create-namespace \
  --set replicaCount=3 \
  --set autoscaling.hbbs.minReplicas=3 \
  --set autoscaling.hbbs.maxReplicas=10

# 使用配置文件
helm install rustdesk rustdesk/rustdesk-server \
  --namespace rustdesk \
  --create-namespace \
  -f values-production.yaml
```

### 常用配置示例

#### 生产环境配置

```yaml
# values.yaml
replicaCount: 3

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
  hbbr:
    minReplicas: 3
    maxReplicas: 20

persistence:
  enabled: true
  data:
    size: 50Gi
  logs:
    size: 10Gi
```

#### 开发环境配置

```yaml
# values-dev.yaml
replicaCount: 1

service:
  type: NodePort
  enableNodePort: true

autoscaling:
  enabled: false

persistence:
  enabled: false
```

## 升级

### Helm 升级

```bash
# 升级到最新版本
helm upgrade rustdesk rustdesk/rustdesk-server -n rustdesk

# 升级到指定版本
helm upgrade rustdesk rustdesk/rustdesk-server \
  --namespace rustdesk \
  --set image.tag=1.2.0

# 回滚
helm rollback rustdesk -n rustdesk
```

### Manifest 升级

```bash
kubectl apply -f k8s/manifests/
```

## 卸载

### Helm 卸载

```bash
helm uninstall rustdesk -n rustdesk
```

### Manifest 卸载

```bash
kubectl delete -f k8s/manifests/
```

## 持久化存储配置

### 使用 NFS 存储

```yaml
persistence:
  enabled: true
  data:
    storageClass: "nfs-client"
    size: "100Gi"
    accessMode: ReadWriteMany
```

### 使用云存储

**AWS EBS:**
```yaml
persistence:
  data:
    storageClass: "gp3"
```

**GCP Persistent Disk:**
```yaml
persistence:
  data:
    storageClass: "standard"
```

**Azure Disk:**
```yaml
persistence:
  data:
    storageClass: "managed-premium"
```

## 高可用配置

```yaml
replicaCount: 3

autoscaling:
  enabled: true
  hbbs:
    minReplicas: 3
    maxReplicas: 20
  hbbr:
    minReplicas: 3
    maxReplicas: 20

podDisruptionBudget:
  enabled: true
  minAvailable: 2

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/component: hbbs
        topologyKey: topology.kubernetes.io/zone
```

## 安全配置

### 启用 TLS

```yaml
ingress:
  enabled: true
  tls:
    enabled: true
    secretName: rustdesk-tls
```

### 使用密钥

```yaml
secrets:
  enabled: true
  encryptionKey: "your-32-byte-key"
  apiKey: "your-api-key"
```

## 监控配置

Helm Chart 默认配置了 Prometheus 注解：

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "21115"
  prometheus.io/path: "/metrics"
```

确保 metrics-server 已安装：

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## 资源规划

根据用户数量调整资源配置：

| 用户数量 | HBBS CPU/Memory | HBBR CPU/Memory | 副本数 |
|---------|----------------|----------------|-------|
| < 50    | 100m/128Mi     | 100m/128Mi     | 2     |
| 50-200  | 200m/256Mi     | 500m/512Mi     | 3     |
| 200-500 | 500m/512Mi     | 1000m/1Gi      | 5     |
| > 500   | 1000m/1Gi      | 2000m/2Gi      | 10    |

## 常见问题

### Q: Pod 无法启动？

```bash
# 检查状态
kubectl describe pod <pod-name> -n rustdesk

# 查看日志
kubectl logs <pod-name> -n rustdesk
```

### Q: PVC 无法挂载？

```bash
# 检查 StorageClass
kubectl get storageclass

# 检查 PVC 状态
kubectl describe pvc -n rustdesk
```

### Q: HPA 不工作？

```bash
# 检查 metrics-server
kubectl get pods -n kube-system -l k8s-app=metrics-server

# 查看 metrics
kubectl top pods -n rustdesk
```

### Q: 服务无法访问？

```bash
# 检查 Service
kubectl get svc -n rustdesk

# 检查端点
kubectl get endpoints -n rustdesk

# 测试端口转发
kubectl port-forward -n rustdesk svc/rustdesk-hbbs-service 21115:21115
```

## 获取帮助

- 官方文档: https://rustdesk.com
- GitHub Issues: https://github.com/rustdesk/rustdesk/issues
- Kubernetes 文档: https://kubernetes.io/zh/docs/
- Helm 文档: https://helm.sh/zh/docs/
