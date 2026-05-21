# RustDesk Kubernetes 部署指南

## 概述

本文档提供了在 Kubernetes 集群上部署 RustDesk 服务端的完整指南，包括原生 Manifest 和 Helm Chart 两种部署方式。

## 目录结构

```
k8s/
├── manifests/              # Kubernetes 原生 Manifest
│   ├── namespace.yaml      # 命名空间定义
│   ├── configmap.yaml      # 配置字典
│   ├── secret.yaml         # 密钥管理
│   ├── pvc.yaml            # 持久化存储声明
│   ├── deployment-hbbs.yaml # HBBS 部署
│   ├── deployment-hbbr.yaml # HBBR 部署
│   ├── service.yaml        # 服务定义
│   ├── hpa.yaml             # 自动扩缩容
│   ├── ingress.yaml         # 入口配置
│   └── pdb.yaml             # Pod 中断预算
│
└── helm/                   # Helm Chart 部署
    └── rustdesk-server/
        ├── Chart.yaml
        ├── values.yaml
        ├── README.md
        └── templates/
            ├── _helpers.tpl
            ├── namespace.yaml
            ├── configmap.yaml
            ├── secret.yaml
            ├── pvc.yaml
            ├── deployment-hbbs.yaml
            ├── deployment-hbbr.yaml
            ├── service.yaml
            ├── serviceaccount.yaml
            ├── hpa.yaml
            ├── ingress.yaml
            ├── pdb.yaml
            └── NOTES.txt
```

## 前置条件

### 通用要求

- Kubernetes 1.21+
- kubectl 配置正确
- Helm 3.0+ (仅在使用 Helm Chart 时)

### 可选组件

- **metrics-server**: 用于 HPA 自动扩缩容
- **StorageClass**: 支持 ReadWriteMany 模式的存储类
- **Ingress Controller**: 如需通过 Ingress 访问服务
- **cert-manager**: 如需自动 TLS 证书管理

### 安装 metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## 部署方式一：Kubernetes Manifest

### 快速部署

1. 创建命名空间：

```bash
kubectl apply -f k8s/manifests/namespace.yaml
```

2. 部署 ConfigMap 和 Secret：

```bash
kubectl apply -f k8s/manifests/configmap.yaml
kubectl apply -f k8s/manifests/secret.yaml
```

3. 部署 PVC（可选）：

```bash
kubectl apply -f k8s/manifests/pvc.yaml
```

4. 部署 Deployment：

```bash
kubectl apply -f k8s/manifests/deployment-hbbs.yaml
kubectl apply -f k8s/manifests/deployment-hbbr.yaml
```

5. 部署 Service：

```bash
kubectl apply -f k8s/manifests/service.yaml
```

6. 部署 HPA（可选）：

```bash
kubectl apply -f k8s/manifests/hpa.yaml
```

7. 部署 Ingress（可选）：

```bash
kubectl apply -f k8s/manifests/ingress.yaml
```

### 一键部署

```bash
kubectl apply -f k8s/manifests/
```

### 验证部署

```bash
kubectl get pods -n rustdesk
kubectl get services -n rustdesk
kubectl get deployments -n rustdesk
```

### 查看日志

```bash
# HBBS 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbs --tail=50

# HBBR 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbr --tail=50
```

## 部署方式二：Helm Chart

### 安装 Helm Chart

1. 添加 Helm 仓库：

```bash
helm repo add rustdesk https://rustdesk.github.io/rustdesk
helm repo update
```

2. 基础安装：

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace
```

### 自定义配置

1. 查看可配置参数：

```bash
helm show values rustdesk/rustdesk-server
```

2. 创建自定义配置文件：

```yaml
# production-values.yaml
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

3. 使用自定义配置安装：

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f production-values.yaml
```

### 从本地目录安装

```bash
cd k8s/helm/rustdesk-server
helm install rustdesk . -n rustdesk --create-namespace
```

### 升级

```bash
helm upgrade rustdesk rustdesk/rustdesk-server -n rustdesk
```

### 回滚

```bash
helm rollback rustdesk -n rustdesk
```

### 卸载

```bash
helm uninstall rustdesk -n rustdesk
```

## 配置说明

### 端口配置

| 端口 | 协议 | 服务 | 用途 |
|------|------|------|------|
| 21115 | TCP/UDP | HBBS | ID 注册服务 |
| 21116 | TCP | HBBR | 中继服务 |
| 21117 | TCP | HBBR | 数据中继 |
| 21118 | UDP | HBBS | NAT 类型查询 |

### 服务类型选择

#### ClusterIP (默认)

- 仅在集群内部可访问
- 适合开发和测试环境
- 通过 NodePort 或 Ingress 暴露服务

```yaml
service:
  hbbs:
    type: ClusterIP
  hbbr:
    type: ClusterIP
```

#### NodePort

- 在每个节点的指定端口暴露服务
- 适合不需要负载均衡的小规模部署
- 端口范围：30000-32767

```yaml
service:
  enableNodePort: true
```

#### LoadBalancer

- 使用云提供商的负载均衡器
- 适合生产环境
- 自动配置外部访问

```yaml
service:
  type: LoadBalancer
  hbbs:
    type: LoadBalancer
  hbbr:
    type: LoadBalancer
```

### 存储配置

#### 使用默认 StorageClass

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

#### 使用 NFS 存储

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

#### 禁用持久化

```yaml
persistence:
  enabled: false
```

### 自动扩缩容配置

#### 基于 CPU 和内存

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

#### 自定义 HPA 行为

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

### 安全配置

#### 启用密钥

```yaml
secrets:
  enabled: true
  encryptionKey: "your-32-byte-encryption-key"
  apiKey: "your-api-key"
```

#### 自定义安全上下文

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: false
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

### Ingress 配置

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
  hosts:
    - host: rustdesk.example.com
      paths:
        - path: /
          pathType: Prefix
          service: hbbs
          port: 21115
        - path: /relay
          pathType: Prefix
          service: hbbr
          port: 21117
  tls:
    enabled: true
    secretName: rustdesk-tls
```

## 高可用部署

### 生产环境推荐配置

```yaml
# production-ha.yaml
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

## 监控和日志

### Prometheus 集成

Helm Chart 默认配置了 Prometheus 注解：

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "21115"
  prometheus.io/path: "/metrics"
```

### 日志收集

使用 Fluent Bit 或 Fluentd 收集日志：

```yaml
# fluent-bit-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: rustdesk
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Log_Level     info
        Daemon        off

    [INPUT]
        Name              tail
        Path              /var/log/rustdesk/*.log
        Parser            docker
        Tag               rustdesk.*
        Refresh_Interval 5

    [OUTPUT]
        Name              stdout
        Match             rustdesk.*
```

## 故障排查

### 常见问题

#### 1. Pod 无法启动

```bash
kubectl describe pod <pod-name> -n rustdesk
kubectl logs <pod-name> -n rustdesk
```

#### 2. PVC 无法挂载

```bash
kubectl describe pvc <pvc-name> -n rustdesk
kubectl get events -n rustdesk --field-selector involvedObject.name=<pvc-name>
```

检查 StorageClass 是否存在：

```bash
kubectl get storageclass
```

#### 3. HPA 不工作

确保 metrics-server 已安装并运行：

```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
kubectl top pods -n rustdesk
```

#### 4. 服务无法访问

检查 Service 配置：

```bash
kubectl get svc -n rustdesk
kubectl describe svc <service-name> -n rustdesk
```

检查端点：

```bash
kubectl get endpoints -n rustdesk
```

### 调试命令

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

## 备份和恢复

### 备份 PVC 数据

```bash
# 创建备份
kubectl exec -n rustdesk <pod-name> -- tar czf /tmp/backup.tar.gz /data

# 复制备份文件
kubectl cp rustdesk/<pod-name>:/tmp/backup.tar.gz ./rustdesk-backup.tar.gz
```

### 恢复数据

```bash
# 恢复备份
kubectl cp ./rustdesk-backup.tar.gz rustdesk/<pod-name>:/tmp/backup.tar.gz
kubectl exec -n rustdesk <pod-name> -- tar xzf /tmp/backup.tar.gz -C /
```

### 自动备份脚本

```bash
#!/bin/bash
# backup-rustdesk.sh

NAMESPACE=rustdesk
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

for pvc in $(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
  echo "Backing up $pvc..."
  kubectl exec -n $NAMESPACE deploy/rustdesk-hbbs -- tar czf /tmp/${pvc}.tar.gz -C /data . 2>/dev/null || true
  kubectl cp $NAMESPACE/deploy/rustdesk-hbbs:/tmp/${pvc}.tar.gz $BACKUP_DIR/${pvc}_${DATE}.tar.gz
done

echo "Backup completed: $BACKUP_DIR"
```

## 安全建议

1. **使用 TLS**: 启用 Ingress TLS 或配置 LoadBalancer TLS
2. **网络策略**: 配置 NetworkPolicy 限制 Pod 通信
3. **资源限制**: 设置合理的资源限制防止资源耗尽
4. **定期更新**: 定期更新镜像版本修复安全漏洞
5. **审计日志**: 启用 Kubernetes 审计日志
6. **密钥管理**: 使用外部密钥管理服务（如 Vault）

### 网络策略示例

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: rustdesk-network-policy
  namespace: rustdesk
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: rustdesk-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: production
      ports:
        - protocol: TCP
          port: 21115
        - protocol: UDP
          port: 21115
        - protocol: TCP
          port: 21116
        - protocol: TCP
          port: 21117
        - protocol: UDP
          port: 21118
```

## 性能优化

### 资源调优

根据用户数量调整资源：

| 用户数量 | CPU (请求/限制) | 内存 (请求/限制) |
|---------|----------------|-----------------|
| < 100   | 100m / 500m   | 128Mi / 512Mi  |
| 100-500 | 200m / 1000m  | 256Mi / 1Gi    |
| 500-1000| 500m / 2000m  | 512Mi / 2Gi    |
| > 1000  | 1000m / 4000m | 1Gi / 4Gi      |

### 存储性能

- 使用 SSD 存储提高 IOPS
- 选择低延迟的 StorageClass
- 考虑使用 Local PV 减少网络延迟

### 网络优化

- 启用 Pod 间的直接通信
- 配置服务质量 (QoS) 保障
- 使用服务网格优化流量管理

## 升级策略

### 滚动升级

```bash
# 更新镜像版本
helm upgrade rustdesk rustdesk/rustdesk-server \
  --set image.tag=new-version \
  -n rustdesk
```

### 蓝绿部署

```bash
# 安装新版本
helm install rustdesk-new rustdesk/rustdesk-server \
  --set image.tag=new-version \
  -n rustdesk

# 验证新版本
kubectl rollout status deployment/rustdesk-new-hbbs -n rustdesk

# 切换流量（通过修改 Service selector）
kubectl patch service rustdesk-hbbs-service -n rustdesk \
  -p '{"spec":{"selector":{"app.kubernetes.io/instance":"rustdesk-new"}}}'

# 删除旧版本
helm uninstall rustdesk -n rustdesk
```

## 许可证

Apache License 2.0 - RustDesk Team

## 参考资源

- [RustDesk 官网](https://rustdesk.com)
- [RustDesk GitHub](https://github.com/rustdesk/rustdesk)
- [Kubernetes 官方文档](https://kubernetes.io/zh/docs/)
- [Helm 官方文档](https://helm.sh/zh/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)
