# RustDesk Server Helm Chart

Kubernetes 上部署 RustDesk 服务端的 Helm Chart。

## 目录结构

```
rustdesk-server/
├── Chart.yaml
├── values.yaml
├── README.md
└── templates/
    ├── _helpers.tpl
    ├── _namespace.tpl
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

## 先决条件

- Kubernetes 1.21+
- Helm 3.0+
- StorageClass 配置（用于持久化存储）
- 可选的 metrics-server（用于 HPA）

## 安装

### 添加 Helm 仓库

```bash
helm repo add rustdesk https://rustdesk.github.io/rustdesk
helm repo update
```

### 基础安装

```bash
helm install rustdesk rustdesk/rustdesk-server -n rustdesk --create-namespace
```

### 使用自定义配置安装

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f custom-values.yaml
```

### 从本地目录安装

```bash
helm install rustdesk . -n rustdesk --create-namespace
```

## 配置

### 通用参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `replicaCount` | 默认副本数 | `2` |
| `image.repository` | 镜像仓库 | `rustdesk/rustdesk-server` |
| `image.tag` | 镜像标签 | `latest` |
| `image.pullPolicy` | 镜像拉取策略 | `IfNotPresent` |
| `createNamespace` | 创建命名空间 | `true` |
| `namespaceOverride` | 覆盖命名空间名称 | `""` |

### 服务配置

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `service.type` | 服务类型 (ClusterIP/NodePort/LoadBalancer) | `ClusterIP` |
| `service.hbbs.type` | HBBS 服务类型 | `ClusterIP` |
| `service.hbbr.type` | HBBR 服务类型 | `ClusterIP` |
| `service.enableNodePort` | 启用 NodePort 服务 | `false` |

### 资源限制

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `resources.hbbs.requests.cpu` | HBBS CPU 请求 | `100m` |
| `resources.hbbs.requests.memory` | HBBS 内存请求 | `128Mi` |
| `resources.hbbs.limits.cpu` | HBBS CPU 限制 | `500m` |
| `resources.hbbs.limits.memory` | HBBS 内存限制 | `512Mi` |
| `resources.hbbr.requests.cpu` | HBBR CPU 请求 | `100m` |
| `resources.hbbr.requests.memory` | HBBR 内存请求 | `128Mi` |
| `resources.hbbr.limits.cpu` | HBBR CPU 限制 | `1000m` |
| `resources.hbbr.limits.memory` | HBBR 内存限制 | `1Gi` |

### 自动扩缩容

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `autoscaling.enabled` | 启用 HPA | `true` |
| `autoscaling.hbbs.minReplicas` | HBBS 最小副本数 | `2` |
| `autoscaling.hbbs.maxReplicas` | HBBS 最大副本数 | `10` |
| `autoscaling.hbbs.targetCPUUtilizationPercentage` | HBBS CPU 目标利用率 | `70` |
| `autoscaling.hbbr.minReplicas` | HBBR 最小副本数 | `2` |
| `autoscaling.hbbr.maxReplicas` | HBBR 最大副本数 | `10` |
| `autoscaling.hbbr.targetCPUUtilizationPercentage` | HBBR CPU 目标利用率 | `70` |

### 持久化存储

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `persistence.enabled` | 启用持久化存储 | `true` |
| `persistence.data.enabled` | 启用数据卷 | `true` |
| `persistence.data.storageClass` | 数据卷 StorageClass | `standard` |
| `persistence.data.size` | 数据卷大小 | `10Gi` |
| `persistence.data.accessMode` | 数据卷访问模式 | `ReadWriteMany` |
| `persistence.logs.enabled` | 启用日志卷 | `true` |
| `persistence.logs.storageClass` | 日志卷 StorageClass | `standard` |
| `persistence.logs.size` | 日志卷大小 | `5Gi` |

### Ingress 配置

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `ingress.enabled` | 启用 Ingress | `false` |
| `ingress.className` | Ingress 类名 | `nginx` |
| `ingress.annotations` | Ingress 注解 | `{}` |
| `ingress.hosts` | Ingress 主机配置 | `[]` |
| `ingress.tls.enabled` | 启用 TLS | `false` |
| `ingress.tls.secretName` | TLS 密钥名称 | `rustdesk-tls` |

### 安全配置

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `podSecurityContext.runAsNonRoot` | 以非 root 用户运行 | `true` |
| `podSecurityContext.runAsUser` | 运行用户 ID | `1000` |
| `securityContext.allowPrivilegeEscalation` | 禁止权限提升 | `false` |
| `securityContext.capabilities.drop` | 丢弃所有 capabilities | `["ALL"]` |
| `secrets.enabled` | 启用密钥管理 | `false` |
| `secrets.encryptionKey` | 加密密钥 | `""` |
| `secrets.apiKey` | API 密钥 | `""` |

### Pod 中断预算

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `podDisruptionBudget.enabled` | 启用 PDB | `true` |
| `podDisruptionBudget.minAvailable` | 最小可用 Pod 数 | `1` |

## 使用示例

### 示例 1: 基础安装

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace
```

### 示例 2: 自定义副本数和资源

```yaml
# custom-values.yaml
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
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 2000m
      memory: 2Gi
```

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f custom-values.yaml
```

### 示例 3: 启用 NodePort 服务

```yaml
# nodeport-values.yaml
service:
  type: NodePort
  enableNodePort: true
```

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f nodeport-values.yaml
```

### 示例 4: 禁用持久化存储

```yaml
# ephemeral-values.yaml
persistence:
  enabled: false
```

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f ephemeral-values.yaml
```

### 示例 5: 启用 Ingress

```yaml
# ingress-values.yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: rustdesk.example.com
      paths:
        - path: /
          pathType: Prefix
          service: hbbs
          port: 21115
  tls:
    enabled: true
    secretName: rustdesk-tls
```

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f ingress-values.yaml
```

### 示例 6: 禁用 HPA

```yaml
# no-hpa-values.yaml
autoscaling:
  enabled: false
```

```bash
helm install rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  --create-namespace \
  -f no-hpa-values.yaml
```

## 升级

### 升级 Chart

```bash
helm upgrade rustdesk rustdesk/rustdesk-server -n rustdesk
```

### 升级并自定义配置

```bash
helm upgrade rustdesk rustdesk/rustdesk-server \
  -n rustdesk \
  -f custom-values.yaml
```

### 回滚

```bash
helm rollback rustdesk -n rustdesk
```

## 卸载

```bash
helm uninstall rustdesk -n rustdesk
```

## 故障排查

### 检查 Pod 状态

```bash
kubectl get pods -n rustdesk -l app.kubernetes.io/name=rustdesk-server
```

### 查看 Pod 日志

```bash
# HBBS 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbs --tail=100

# HBBR 日志
kubectl logs -n rustdesk -l app.kubernetes.io/component=hbbr --tail=100
```

### 查看资源详情

```bash
# 查看 Deployment
kubectl get deployment -n rustdesk

# 查看 Service
kubectl get svc -n rustdesk

# 查看 PVC
kubectl get pvc -n rustdesk

# 查看 HPA
kubectl get hpa -n rustdesk
```

### 检查 Events

```bash
kubectl get events -n rustdesk --sort-by='.lastTimestamp'
```

### 常见问题

1. **PVC 挂载失败**
   - 确保 StorageClass 存在并可用
   - 检查 PVC 的 AccessMode 是否支持 ReadWriteMany

2. **HPA 不工作**
   - 确保 metrics-server 已安装并可用
   - 检查 Pod 是否有足够的资源请求

3. **服务无法访问**
   - 检查 Service 类型和端口配置
   - 验证防火墙规则允许所需端口

## 架构

```
┌─────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                │
│                                                      │
│  ┌─────────────┐          ┌─────────────┐           │
│  │  HBBS Pod 1 │◄────────►│  HBBS Pod 2 │           │
│  │  (ID Server)│          │(ID Server) │           │
│  └──────┬──────┘          └──────┬──────┘           │
│         │                        │                    │
│  ┌──────┴──────┐          ┌──────┴──────┐           │
│  │  HBBR Pod 1 │◄────────►│  HBBR Pod 2 │           │
│  │(Relay Server│          │(Relay Server│           │
│  └─────────────┘          └─────────────┘           │
│         │                        │                    │
│  ┌──────┴──────┐          ┌──────┴──────┐           │
│  │   Service   │          │   Service   │           │
│  │  (ClusterIP)│          │  (ClusterIP)│           │
│  └─────────────┘          └─────────────┘           │
│                                                      │
└─────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
    RustDesk Client         RustDesk Client
```

## 端口说明

| 端口 | 协议 | 服务 | 用途 |
|------|------|------|------|
| 21115 | TCP/UDP | HBBS | ID 注册服务 |
| 21116 | TCP | HBBR | 中继服务 |
| 21117 | TCP | HBBR | 数据中继 |
| 21118 | UDP | HBBS | NAT 类型查询 |

## 生产环境建议

1. **高可用性**
   - 至少部署 2 个副本
   - 启用 PodDisruptionBudget
   - 使用多可用区部署

2. **资源规划**
   - 根据用户数量调整资源限制
   - 启用 HPA 进行自动扩缩容
   - 监控 CPU 和内存使用

3. **存储**
   - 使用高性能存储
   - 配置定期备份
   - 考虑使用 ReadWriteMany 访问模式

4. **安全**
   - 启用安全上下文
   - 使用 TLS 加密通信
   - 定期更新镜像版本

5. **监控**
   - 集成 Prometheus 和 Grafana
   - 配置日志收集
   - 设置告警规则

## License

Apache License 2.0 - RustDesk Team
