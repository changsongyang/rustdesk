# RustDesk 监控部署方案

本目录包含完整的 RustDesk 服务监控解决方案，包括 Prometheus、Grafana、AlertManager 和日志收集系统。

## 目录结构

```
monitoring/
├── prometheus/
│   ├── prometheus.yml          # Prometheus 主配置文件
│   └── rules/                  # 告警和记录规则
│       ├── recording-rules.yml # 记录规则
│       └── rustdesk-alerts.yml # 告警规则
├── grafana/
│   ├── dashboards/             # Grafana 仪表板
│   │   └── rustdesk-overview.json
│   └── provisioning/           # 自动配置
│       ├── dashboards.yaml     # 仪表板配置
│       └── datasources.yaml    # 数据源配置
├── alertmanager/
│   └── alertmanager.yml        # AlertManager 配置
├── filebeat/
│   └── filebeat.yml            # Filebeat 日志收集配置
├── docker-compose.monitoring.yml
└── README.md
```

## 快速开始

### 前提条件

- Docker 和 Docker Compose
- RustDesk 服务已部署并运行
- 至少 4GB RAM 和 20GB 磁盘空间

### 启动监控服务

1. 进入 monitoring 目录：

```bash
cd monitoring
```

2. 启动监控栈：

```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

3. 验证服务状态：

```bash
docker-compose -f docker-compose.monitoring.yml ps
```

## 服务访问

- **Prometheus**: http://localhost:9090
  - 用户名: admin
  - 密码: admin123

- **Grafana**: http://localhost:3000
  - 用户名: admin
  - 密码: admin123

- **AlertManager**: http://localhost:9093

- **Node Exporter**: http://localhost:9100

- **cAdvisor**: http://localhost:8080

## 监控指标

### RustDesk 服务指标

- `rustdesk_active_connections_total`: 活跃连接数
- `rustdesk_requests_total`: 请求总数
- `rustdesk_request_duration_seconds_bucket`: 请求延迟分布
- `rustdesk_network_bytes_total`: 网络流量
- `rustdesk_relay_connections_total`: 中继连接数
- `rustdesk_relay_latency_seconds_bucket`: 中继延迟分布
- `rustdesk_registration_total`: 注册请求总数
- `rustdesk_registration_failures_total`: 注册失败数

### 系统指标

- `node_cpu_seconds_total`: CPU 使用时间
- `node_memory_MemAvailable_bytes`: 可用内存
- `node_memory_MemTotal_bytes`: 总内存
- `node_filesystem_avail_bytes`: 可用磁盘空间
- `node_filesystem_size_bytes`: 总磁盘空间
- `node_network_receive_bytes_total`: 网络入站流量
- `node_network_transmit_bytes_total`: 网络出站流量

## 告警规则

### 严重告警 (Critical)

- RustDesk 服务宕机
- 中继服务宕机
- Rendezvous 服务宕机

### 警告告警 (Warning)

- CPU 使用率超过 80%
- 内存使用率超过 85%
- 磁盘使用率超过 85%
- 连接数超过 1000
- 请求延迟 P95 超过 1 秒
- 错误率超过 5%
- 注册失败率超过 10%

### 信息告警 (Info)

- 带宽使用较高
- 网络流量较高

## Grafana 仪表板

### RustDesk 服务概览

导入 `grafana/dashboards/rustdesk-overview.json` 仪表板，包含：

- 服务状态概览
- 性能指标（连接数、带宽、延迟）
- 系统资源使用（CPU、内存、磁盘）
- 连接质量（中继延迟、带宽）
- 告警历史

## 告警通知配置

### Email 配置

编辑 `alertmanager/alertmanager.yml`，配置 SMTP：

```yaml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'alertmanager@example.com'
  smtp_auth_password: 'your-password'
```

### Slack 配置

添加 Slack webhook：

```yaml
receivers:
  - name: 'critical-receiver'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'
        channel: '#alerts'
```

### Telegram 配置

通过 Alertmanager Bot 配置 Telegram 通知。

## 日志收集

### Filebeat 配置

Filebeat 收集以下日志：

- Docker 容器日志
- RustDesk 服务日志
  - `/var/log/rustdesk/hbbs.log`
  - `/var/log/rustdesk/hbbr.log`

### ELK 集成

可选的 ELK 集成配置：

1. 安装 Elasticsearch、Kibana、Logstash
2. 配置 Filebeat 输出到 Logstash
3. 在 Kibana 中创建日志索引

### Loki + Grafana 替代方案

如果不需要完整的 ELK 堆栈，可以使用 Loki：

```yaml
# docker-compose.loki.yml
loki:
  image: grafana/loki:2.8.0
  ports:
    - "3100:3100"

promtail:
  image: grafana/promtail:2.8.0
  volumes:
    - /var/log:/var/log
```

## 性能调优

### Prometheus 资源建议

- 测试环境: 2CPU, 4GB RAM
- 生产环境: 4CPU, 8GB RAM
- 保留期限: 30 天
- 数据保留大小: 50GB

### Grafana 资源建议

- 测试环境: 1CPU, 2GB RAM
- 生产环境: 2CPU, 4GB RAM

### 抓取间隔配置

```yaml
global:
  scrape_interval: 15s      # 基础抓取间隔
  evaluation_interval: 15s   # 规则评估间隔
```

根据需要调整，更短的间隔会产生更多数据。

## 故障排查

### Prometheus 无法启动

检查配置文件语法：

```bash
docker run --rm -v $(pwd)/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Grafana 仪表板无数据

1. 检查 Prometheus 数据源配置
2. 验证指标名称是否正确
3. 检查时间范围设置

### AlertManager 不发送告警

1. 验证告警规则语法：

```bash
docker run --rm -v $(pwd)/prometheus/rules:/rules prom/prometheus promtool check rules /rules/*.yml
```

2. 检查 AlertManager 日志：

```bash
docker logs alertmanager
```

3. 测试告警通知配置

### 告警规则不触发

1. 确认指标已正确暴露
2. 检查指标标签是否匹配
3. 验证告警评估间隔

### 日志收集问题

1. 检查 Filebeat 日志：

```bash
docker logs filebeat
```

2. 验证日志文件路径
3. 检查 Elasticsearch 连接

## Kubernetes 部署

### 使用 Prometheus Operator

```bash
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
```

### Helm Chart 部署

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus
helm install grafana grafana/grafana
```

## 安全建议

1. **更改默认密码**: 立即更改 Grafana 和其他服务的默认密码
2. **启用 TLS**: 在生产环境中启用 HTTPS
3. **网络隔离**: 使用 Docker 网络隔离监控服务
4. **访问控制**: 配置防火墙规则限制访问
5. **密钥管理**: 使用 Docker secrets 或 Kubernetes secrets

## 维护

### 备份监控数据

```bash
# 备份 Prometheus 数据
docker run --rm -v prometheus-data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz /data

# 备份 Grafana 数据
docker run --rm -v grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz /data
```

### 更新监控组件

```bash
docker-compose -f docker-compose.monitoring.yml pull
docker-compose -f docker-compose.monitoring.yml up -d
```

### 清理旧数据

```bash
# 清理 Docker 卷
docker volume prune
```

## 资源使用建议

### 小型部署 (< 100 并发连接)

- Prometheus: 2CPU, 4GB RAM
- Grafana: 1CPU, 2GB RAM
- 保留期限: 15 天

### 中型部署 (100-500 并发连接)

- Prometheus: 4CPU, 8GB RAM
- Grafana: 2CPU, 4GB RAM
- 保留期限: 30 天

### 大型部署 (> 500 并发连接)

- Prometheus: 8CPU, 16GB RAM
- Grafana: 4CPU, 8GB RAM
- 保留期限: 30-60 天
- 考虑使用 Prometheus 集群

## 支持

如遇问题，请检查：

1. 日志文件: `docker-compose logs`
2. 监控目标状态: Prometheus > Status > Targets
3. 告警状态: Prometheus > Alerts
4. 服务健康状态: 各服务健康检查端点

## 参考资料

- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/)
- [AlertManager 文档](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Docker Monitoring 最佳实践](https://docs.docker.com/config/containers/runmetrics/)
