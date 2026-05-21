# RustDesk 运维手册

## 目录

1. [概述](#1-概述)
2. [服务器环境配置](#2-服务器环境配置)
3. [软件安装与配置](#3-软件安装与配置)
4. [服务启停管理](#4-服务启停管理)
5. [监控告警设置](#5-监控告警设置)
6. [日志收集与分析](#6-日志收集与分析)
7. [性能优化策略](#7-性能优化策略)
8. [安全防护措施](#8-安全防护措施)
9. [日常运维操作流程](#9-日常运维操作流程)

---

## 1. 概述

### 1.1 文档目的

本手册详细描述 RustDesk 服务器端的运维流程，帮助运维人员正确配置、监控和维护生产环境，确保服务稳定运行。

### 1.2 运维架构

```
┌─────────────────────────────────────────────────────────────┐
│                     运维架构                                │
├─────────────────────────────────────────────────────────────┤
│  监控层                                                    │
│  ├── Prometheus + Grafana                                  │
│  ├── Alertmanager                                          │
│  └── ELK Stack                                             │
├─────────────────────────────────────────────────────────────┤
│  服务层                                                    │
│  ├── hbbs (信号服务器)                                      │
│  ├── hbbr (中继服务器)                                      │
│  └── Nginx (反向代理)                                       │
├─────────────────────────────────────────────────────────────┤
│  基础设施层                                                 │
│  ├── Linux 服务器                                           │
│  ├── 防火墙配置                                             │
│  └── SSL/TLS 证书                                          │
└─────────────────────────────────────────────────────────────┘
```

### 1.3 运维职责

| 职责 | 说明 |
|------|------|
| 服务监控 | 实时监控服务状态、性能指标 |
| 故障处理 | 及时响应和解决服务故障 |
| 日志管理 | 收集、存储、分析日志 |
| 安全管理 | 维护系统安全、更新补丁 |
| 性能优化 | 优化系统性能、资源利用 |

---

## 2. 服务器环境配置

### 2.1 服务器规格

| 角色 | CPU | 内存 | 存储 | 网络 |
|------|-----|------|------|------|
| 信号服务器 | 4核 | 8GB | 100GB SSD | 1Gbps |
| 中继服务器 | 8核 | 16GB | 200GB SSD | 1Gbps |
| 监控服务器 | 4核 | 8GB | 500GB SSD | 1Gbps |

### 2.2 操作系统要求

| 操作系统 | 版本 | 说明 |
|----------|------|------|
| Ubuntu Server | 22.04 LTS | 推荐 |
| Debian | 12 | 支持 |
| CentOS | 8+ | 支持 |

### 2.3 系统配置

#### 2.3.1 时间同步

```bash
# 安装 NTP
sudo apt-get install chrony -y

# 启动服务
sudo systemctl enable --now chronyd

# 验证
timedatectl status
```

#### 2.3.2 防火墙配置

```bash
# 开放必要端口
sudo ufw allow 22/tcp          # SSH
sudo ufw allow 80/tcp          # HTTP
sudo ufw allow 443/tcp         # HTTPS
sudo ufw allow 21115/tcp       # hbbs 端口
sudo ufw allow 21116/tcp       # hbbr 端口
sudo ufw allow 21117/tcp       # hbbs NAT 端口
sudo ufw enable
```

#### 2.3.3 用户管理

```bash
# 创建运维用户
sudo useradd -m -s /bin/bash ops
sudo usermod -aG sudo ops

# 设置 SSH 密钥登录
mkdir -p /home/ops/.ssh
chmod 700 /home/ops/.ssh
cat id_rsa.pub >> /home/ops/.ssh/authorized_keys
chmod 600 /home/ops/.ssh/authorized_keys
```

---

## 3. 软件安装与配置

### 3.1 hbbs (信号服务器)

#### 3.1.1 安装

```bash
# 下载最新版本
wget https://github.com/rustdesk/rustdesk-server/releases/download/latest/hbbs
chmod +x hbbs

# 移动到安装目录
sudo mv hbbs /usr/local/bin/
```

#### 3.1.2 配置

**配置文件**: `/etc/rustdesk/hbbs.conf`

```ini
[hbbs]
# 监听端口
port = 21115

# NAT 类型
nat_type = 1

# 日志级别
log_level = info

# 数据目录
data_dir = /var/lib/rustdesk/hbbs
```

#### 3.1.3 系统服务

**文件**: `/etc/systemd/system/hbbs.service`

```ini
[Unit]
Description=RustDesk Signal Server
After=network.target

[Service]
Type=simple
User=rustdesk
Group=rustdesk
ExecStart=/usr/local/bin/hbbs
WorkingDirectory=/var/lib/rustdesk/hbbs
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 3.2 hbbr (中继服务器)

#### 3.2.1 安装

```bash
wget https://github.com/rustdesk/rustdesk-server/releases/download/latest/hbbr
chmod +x hbbr
sudo mv hbbr /usr/local/bin/
```

#### 3.2.2 配置

**配置文件**: `/etc/rustdesk/hbbr.conf`

```ini
[hbbr]
# 监听端口
port = 21116

# 日志级别
log_level = info

# 数据目录
data_dir = /var/lib/rustdesk/hbbr
```

#### 3.2.3 系统服务

**文件**: `/etc/systemd/system/hbbr.service`

```ini
[Unit]
Description=RustDesk Relay Server
After=network.target

[Service]
Type=simple
User=rustdesk
Group=rustdesk
ExecStart=/usr/local/bin/hbbr
WorkingDirectory=/var/lib/rustdesk/hbbr
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 3.3 Nginx 反向代理

#### 3.3.1 安装

```bash
sudo apt-get install nginx -y
```

#### 3.3.2 配置

**文件**: `/etc/nginx/sites-available/rustdesk`

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # hbbs 信号服务
    location / {
        proxy_pass http://localhost:21115;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # hbbr 中继服务
    location /relay/ {
        proxy_pass http://localhost:21116/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 4. 服务启停管理

### 4.1 启动服务

```bash
# 启动 hbbs
sudo systemctl start hbbs

# 启动 hbbr
sudo systemctl start hbbr

# 启动 Nginx
sudo systemctl start nginx
```

### 4.2 停止服务

```bash
# 停止 hbbs
sudo systemctl stop hbbs

# 停止 hbbr
sudo systemctl stop hbbr

# 停止 Nginx
sudo systemctl stop nginx
```

### 4.3 重启服务

```bash
# 重启 hbbs
sudo systemctl restart hbbs

# 重启 hbbr
sudo systemctl restart hbbr

# 重启 Nginx
sudo systemctl reload nginx
```

### 4.4 设置开机自启

```bash
sudo systemctl enable hbbs
sudo systemctl enable hbbr
sudo systemctl enable nginx
```

### 4.5 查看服务状态

```bash
# 查看所有服务状态
sudo systemctl status hbbs hbbr nginx

# 查看服务日志
journalctl -u hbbs -f
journalctl -u hbbr -f
```

---

## 5. 监控告警设置

### 5.1 Prometheus 配置

#### 5.1.1 安装 Prometheus

```bash
# 创建用户
sudo useradd --no-create-home --shell /bin/false prometheus

# 下载安装
wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
tar xzf prometheus-2.47.0.linux-amd64.tar.gz
sudo cp prometheus-2.47.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.47.0.linux-amd64/promtool /usr/local/bin/
```

#### 5.1.2 配置文件

**文件**: `/etc/prometheus/prometheus.yml`

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'hbbs'
    static_configs:
      - targets: ['localhost:21115']
  
  - job_name: 'hbbr'
    static_configs:
      - targets: ['localhost:21116']
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

### 5.2 Grafana 配置

#### 5.2.1 安装 Grafana

```bash
sudo apt-get install -y adduser libfontconfig1
wget https://dl.grafana.com/enterprise/release/grafana-enterprise_10.1.0_amd64.deb
sudo dpkg -i grafana-enterprise_10.1.0_amd64.deb
sudo systemctl enable --now grafana-server
```

#### 5.2.2 配置 Dashboard

1. 访问 http://localhost:3000
2. 登录 (admin/admin)
3. 添加 Prometheus 数据源
4. 导入 RustDesk 监控 Dashboard

### 5.3 Alertmanager 配置

#### 5.3.1 安装

```bash
wget https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz
tar xzf alertmanager-0.26.0.linux-amd64.tar.gz
sudo cp alertmanager-0.26.0.linux-amd64/alertmanager /usr/local/bin/
```

#### 5.3.2 告警规则

**文件**: `/etc/prometheus/rules/alert_rules.yml`

```yaml
groups:
- name: rustdesk_alerts
  rules:
  - alert: HbbsDown
    expr: up{job="hbbs"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "hbbs 服务宕机"
      description: "hbbs 服务已停止运行"

  - alert: HbbrDown
    expr: up{job="hbbr"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "hbbr 服务宕机"
      description: "hbbr 服务已停止运行"

  - alert: HighCPUUsage
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "CPU 使用率过高"
      description: "CPU 使用率超过 80%"
```

---

## 6. 日志收集与分析

### 6.1 日志目录

| 服务 | 日志路径 |
|------|----------|
| hbbs | `/var/log/rustdesk/hbbs.log` |
| hbbr | `/var/log/rustdesk/hbbr.log` |
| Nginx | `/var/log/nginx/` |
| 系统 | `/var/log/syslog` |

### 6.2 ELK Stack 部署

#### 6.2.1 安装 Elasticsearch

```bash
# 添加 GPG 密钥
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# 添加仓库
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic.list > /dev/null

# 安装
sudo apt-get update && sudo apt-get install elasticsearch -y

# 启动服务
sudo systemctl enable --now elasticsearch
```

#### 6.2.2 安装 Logstash

```bash
sudo apt-get install logstash -y
sudo systemctl enable --now logstash
```

**配置文件**: `/etc/logstash/conf.d/rustdesk.conf`

```ruby
input {
  file {
    path => "/var/log/rustdesk/*.log"
    type => "rustdesk"
    start_position => "beginning"
  }
}

filter {
  if [type] == "rustdesk" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "rustdesk-%{+YYYY.MM.dd}"
  }
}
```

#### 6.2.3 安装 Kibana

```bash
sudo apt-get install kibana -y
sudo systemctl enable --now kibana
```

### 6.3 日志查询示例

```bash
# 查看 hbbs 错误日志
grep -i "error" /var/log/rustdesk/hbbs.log

# 查看最近 100 条日志
tail -n 100 /var/log/rustdesk/hbbs.log

# 实时监控日志
tail -f /var/log/rustdesk/hbbs.log
```

---

## 7. 性能优化策略

### 7.1 资源限制

#### 7.1.1 CPU 亲和性

```bash
# 设置 hbbs 使用特定 CPU 核心
taskset -c 0-3 /usr/local/bin/hbbs

# 设置 hbbr 使用特定 CPU 核心
taskset -c 4-7 /usr/local/bin/hbbr
```

#### 7.1.2 内存限制

**修改 systemd 服务文件**:

```ini
[Service]
MemoryLimit=8G
CPUQuota=80%
```

### 7.2 网络优化

#### 7.2.1 TCP 优化

**文件**: `/etc/sysctl.conf`

```ini
# TCP 优化
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_fin_timeout = 30
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
```

```bash
# 应用配置
sudo sysctl -p
```

#### 7.2.2 连接数限制

```bash
# 修改文件描述符限制
echo "rustdesk soft nofile 65535" >> /etc/security/limits.conf
echo "rustdesk hard nofile 65535" >> /etc/security/limits.conf
```

### 7.3 存储优化

#### 7.3.1 日志轮转

**文件**: `/etc/logrotate.d/rustdesk`

```
/var/log/rustdesk/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 rustdesk rustdesk
    sharedscripts
    postrotate
        systemctl reload hbbs hbbr > /dev/null 2>&1 || true
    endscript
}
```

---

## 8. 安全防护措施

### 8.1 防火墙规则

```bash
# 允许特定 IP 访问
sudo ufw allow from 192.168.1.0/24 to any port 22

# 限制连接速率
sudo ufw limit 21115/tcp
sudo ufw limit 21116/tcp
```

### 8.2 SSL/TLS 配置

#### 8.2.1 申请证书

```bash
# 使用 Let's Encrypt
sudo apt-get install certbot python3-certbot-nginx -y
sudo certbot --nginx -d your-domain.com
```

#### 8.2.2 安全配置

**Nginx 配置**:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
```

### 8.3 定期安全更新

```bash
# 自动更新脚本
#!/bin/bash
apt-get update
apt-get upgrade -y
apt-get autoremove -y
```

### 8.4 备份策略

#### 8.4.1 数据备份

```bash
# 备份脚本
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_DIR="/backup"
mkdir -p $BACKUP_DIR

# 备份配置文件
tar -czf $BACKUP_DIR/config_$DATE.tar.gz /etc/rustdesk/

# 备份数据目录
tar -czf $BACKUP_DIR/data_$DATE.tar.gz /var/lib/rustdesk/

# 保留最近 7 天备份
find $BACKUP_DIR -type f -mtime +7 -delete
```

#### 8.4.2 备份验证

```bash
# 验证备份完整性
tar -tzf /backup/config_$DATE.tar.gz
```

---

## 9. 日常运维操作流程

### 9.1 每日检查

| 检查项 | 命令 | 说明 |
|--------|------|------|
| 服务状态 | `systemctl status hbbs hbbr` | 确认服务运行正常 |
| 日志检查 | `grep -i error /var/log/rustdesk/*.log` | 检查错误日志 |
| 磁盘空间 | `df -h` | 检查磁盘使用率 |
| 内存使用 | `free -h` | 检查内存使用 |

### 9.2 每周维护

```bash
# 更新系统
sudo apt-get update && sudo apt-get upgrade -y

# 清理缓存
sudo apt-get clean

# 检查安全更新
sudo unattended-upgrades -d
```

### 9.3 每月维护

```bash
# 完整备份
./backup.sh

# 性能分析
top -n 1 -b > /var/log/performance_report_$(date +%Y%m).txt

# 安全扫描
sudo apt-get install rkhunter -y
sudo rkhunter --check
```

### 9.4 故障处理流程

```
故障发现 → 初步诊断 → 定位问题 → 实施修复 → 验证恢复 → 记录报告
```

#### 9.4.1 常见故障处理

| 故障现象 | 可能原因 | 处理方法 |
|----------|----------|----------|
| 服务无法启动 | 配置错误 | 检查配置文件和日志 |
| 连接超时 | 网络问题 | 检查防火墙和网络连通性 |
| 性能下降 | 资源耗尽 | 检查 CPU/内存/磁盘使用 |
| 日志报错 | 代码问题 | 查看错误日志定位问题 |

---

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 包含服务器环境配置、软件安装与配置、服务启停管理、监控告警设置、日志收集与分析、性能优化策略、安全防护措施、日常运维操作流程