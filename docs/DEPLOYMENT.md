# RustDesk 部署手册

## 目录

1. [概述](#1-概述)
2. [部署架构](#2-部署架构)
3. [部署环境准备](#3-部署环境准备)
4. [部署流程](#4-部署流程)
5. [部署工具使用](#5-部署工具使用)
6. [版本更新策略](#6-版本更新策略)
7. [回滚机制](#7-回滚机制)
8. [部署验证步骤](#8-部署验证步骤)
9. [部署注意事项](#9-部署注意事项)

---

## 1. 概述

### 1.1 文档目的

本手册详细描述 RustDesk 的部署流程，帮助运维人员正确、安全地将 RustDesk 部署到不同环境，确保服务稳定运行。

### 1.2 部署环境概览

| 环境 | 用途 | 特点 |
|------|------|------|
| 开发环境 | 开发测试 | 本地或虚拟机，配置灵活 |
| 测试环境 | 功能测试 | 模拟生产环境配置 |
| 预生产环境 | 上线前验证 | 与生产环境一致 |
| 生产环境 | 正式运行 | 高可用、高性能要求 |

### 1.3 部署架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        部署架构                                     │
├─────────────────────────────────────────────────────────────────────┤
│  负载均衡层                                                        │
│  └── Nginx / HAProxy                                               │
├─────────────────────────────────────────────────────────────────────┤
│  服务层                                                            │
│  ├── hbbs (信号服务器) x 2 (主备)                                   │
│  └── hbbr (中继服务器) x N (可扩展)                                │
├─────────────────────────────────────────────────────────────────────┤
│  数据库层                                                          │
│  └── SQLite / PostgreSQL                                           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. 部署架构

### 2.1 服务器角色

| 角色 | 功能 | 推荐配置 |
|------|------|----------|
| 信号服务器 (hbbs) | 处理连接请求、用户认证 | 4核/8GB/100GB SSD |
| 中继服务器 (hbbr) | 数据中转、P2P 中继 | 8核/16GB/200GB SSD |
| 负载均衡器 | 流量分发 | 2核/4GB/50GB SSD |
| 监控服务器 | 监控告警、日志收集 | 4核/8GB/500GB SSD |

### 2.2 网络拓扑

```
互联网 → 防火墙 → 负载均衡器 → 信号服务器/中继服务器
```

### 2.3 端口规划

| 端口 | 用途 | 协议 |
|------|------|------|
| 21115 | hbbs 信号服务 | TCP |
| 21116 | hbbr 中继服务 | TCP |
| 21117 | hbbs NAT 穿透 | TCP/UDP |
| 80 | HTTP (重定向) | TCP |
| 443 | HTTPS | TCP |
| 22 | SSH 管理 | TCP |

---

## 3. 部署环境准备

### 3.1 操作系统要求

| 操作系统 | 版本 | 推荐 |
|----------|------|------|
| Ubuntu Server | 22.04 LTS | ✅ |
| Debian | 12 | ✅ |
| CentOS | 8+ | ⚠️ |

### 3.2 依赖安装

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    wget \
    curl \
    nginx \
    certbot \
    python3-certbot-nginx \
    chrony \
    ufw

# 启用防火墙
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 21115/tcp
sudo ufw allow 21116/tcp
```

### 3.3 用户创建

```bash
# 创建 rustdesk 用户
sudo useradd -m -s /bin/bash rustdesk
sudo mkdir -p /var/lib/rustdesk/{hbbs,hbbr}
sudo chown -R rustdesk:rustdesk /var/lib/rustdesk/
```

### 3.4 SSL 证书配置

```bash
# 使用 Let's Encrypt 申请证书
sudo certbot --nginx -d your-domain.com --agree-tos -m admin@your-domain.com
```

---

## 4. 部署流程

### 4.1 开发环境部署

```bash
# 克隆仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 构建项目
cargo build --release

# 运行服务（开发模式）
./target/release/hbbs
./target/release/hbbr
```

### 4.2 测试环境部署

```bash
# 下载预构建包
wget https://github.com/rustdesk/rustdesk-server/releases/download/latest/hbbs
wget https://github.com/rustdesk/rustdesk-server/releases/download/latest/hbbr

# 安装到系统
chmod +x hbbs hbbr
sudo mv hbbs hbbr /usr/local/bin/

# 创建配置文件
sudo mkdir -p /etc/rustdesk
cat > /etc/rustdesk/hbbs.conf << EOF
[hbbs]
port = 21115
log_level = debug
EOF

cat > /etc/rustdesk/hbbr.conf << EOF
[hbbr]
port = 21116
log_level = debug
EOF

# 创建系统服务
sudo cp /path/to/hbbs.service /etc/systemd/system/
sudo cp /path/to/hbbr.service /etc/systemd/system/

# 启动服务
sudo systemctl daemon-reload
sudo systemctl start hbbs hbbr
sudo systemctl enable hbbs hbbr
```

### 4.3 预生产环境部署

```bash
# 使用 Ansible 部署
ansible-playbook -i inventory/prod.yml playbooks/deploy.yml

# 验证部署
ansible -i inventory/prod.yml all -m ping
```

### 4.4 生产环境部署

#### 4.4.1 蓝绿部署流程

```
┌──────────────────────────────────────────────────────────────────┐
│                    蓝绿部署流程                                   │
├──────────────────────────────────────────────────────────────────┤
│  1. 部署新版本到绿色环境                                         │
│  2. 在绿色环境运行测试                                           │
│  3. 切换负载均衡到绿色环境                                       │
│  4. 监控生产流量                                                │
│  5. 如有问题回滚到蓝色环境                                       │
│  6. 清理蓝色环境准备下次部署                                     │
└──────────────────────────────────────────────────────────────────┘
```

#### 4.4.2 部署命令

```bash
# 部署到绿色环境
ansible-playbook -i inventory/green.yml playbooks/deploy.yml

# 运行测试
ansible-playbook -i inventory/green.yml playbooks/test.yml

# 切换负载均衡
ansible-playbook -i inventory/loadbalancer.yml playbooks/switch-green.yml

# 验证
curl -I https://your-domain.com
```

---

## 5. 部署工具使用

### 5.1 Ansible 配置

#### 5.1.1 Inventory 文件

**文件**: `inventory/prod.yml`

```yaml
[signaling_servers]
hbbs-01 ansible_host=192.168.1.101
hbbs-02 ansible_host=192.168.1.102

[relay_servers]
hbbr-01 ansible_host=192.168.1.103
hbbr-02 ansible_host=192.168.1.104
hbbr-03 ansible_host=192.168.1.105

[loadbalancer]
lb-01 ansible_host=192.168.1.100

[all:vars]
ansible_user=ops
ansible_become=true
rustdesk_version=1.2.0
```

#### 5.1.2 Playbook 文件

**文件**: `playbooks/deploy.yml`

```yaml
---
- name: Deploy RustDesk Server
  hosts: signaling_servers:relay_servers
  become: yes
  tasks:
    - name: Download hbbs/hbbr
      get_url:
        url: "https://github.com/rustdesk/rustdesk-server/releases/download/v{{ rustdesk_version }}/{{ item }}"
        dest: "/usr/local/bin/{{ item }}"
        mode: '0755'
      loop:
        - hbbs
        - hbbr

    - name: Create configuration directory
      file:
        path: /etc/rustdesk
        state: directory

    - name: Deploy hbbs config
      template:
        src: templates/hbbs.conf.j2
        dest: /etc/rustdesk/hbbs.conf
      when: "'signaling_servers' in group_names"

    - name: Deploy hbbr config
      template:
        src: templates/hbbr.conf.j2
        dest: /etc/rustdesk/hbbr.conf
      when: "'relay_servers' in group_names"

    - name: Deploy systemd service
      template:
        src: templates/rustdesk.service.j2
        dest: "/etc/systemd/system/{{ item }}.service"
      loop:
        - hbbs
        - hbbr

    - name: Start and enable service
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
        daemon_reload: yes
      loop:
        - hbbs
        - hbbr
```

### 5.2 Docker 部署

#### 5.2.1 Docker Compose 文件

**文件**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    command: hbbs
    ports:
      - "21115:21115"
      - "21117:21117/udp"
    volumes:
      - ./data/hbbs:/root
    restart: always
    environment:
      - RUST_LOG=info

  hbbr:
    image: rustdesk/rustdesk-server:latest
    command: hbbr
    ports:
      - "21116:21116"
    volumes:
      - ./data/hbbr:/root
    restart: always
    environment:
      - RUST_LOG=info

  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/certs:/etc/nginx/certs
    restart: always
```

#### 5.2.2 启动命令

```bash
# 创建目录结构
mkdir -p data/hbbs data/hbbr nginx/conf.d nginx/certs

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f
```

---

## 6. 版本更新策略

### 6.1 版本号规则

采用 Semantic Versioning：

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: 重大变更，不兼容升级
- **MINOR**: 新功能，向后兼容
- **PATCH**: Bug 修复，向后兼容

### 6.2 更新流程

```bash
# 1. 查看当前版本
curl -s https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest | grep tag_name

# 2. 备份当前配置
cp -r /etc/rustdesk /etc/rustdesk.bak

# 3. 停止服务
sudo systemctl stop hbbs hbbr

# 4. 下载新版本
wget https://github.com/rustdesk/rustdesk-server/releases/download/vX.Y.Z/hbbs
wget https://github.com/rustdesk/rustdesk-server/releases/download/vX.Y.Z/hbbr

# 5. 安装
chmod +x hbbs hbbr
sudo mv hbbs hbbr /usr/local/bin/

# 6. 启动服务
sudo systemctl start hbbs hbbr

# 7. 验证
curl http://localhost:21115/health
```

### 6.3 灰度发布

```bash
# 先更新部分服务器
ansible-playbook -i inventory/prod.yml playbooks/deploy.yml --limit "hbbs-01"

# 监控一段时间
sleep 300

# 更新剩余服务器
ansible-playbook -i inventory/prod.yml playbooks/deploy.yml
```

---

## 7. 回滚机制

### 7.1 回滚准备

```bash
# 保存旧版本
mkdir -p /opt/rustdesk/versions
cp /usr/local/bin/hbbs /opt/rustdesk/versions/hbbs-vX.Y.Z
cp /usr/local/bin/hbbr /opt/rustdesk/versions/hbbr-vX.Y.Z
```

### 7.2 回滚流程

```bash
# 1. 停止服务
sudo systemctl stop hbbs hbbr

# 2. 恢复旧版本
cp /opt/rustdesk/versions/hbbs-vX.Y.Z /usr/local/bin/hbbs
cp /opt/rustdesk/versions/hbbr-vX.Y.Z /usr/local/bin/hbbr

# 3. 恢复配置
cp -r /etc/rustdesk.bak/* /etc/rustdesk/

# 4. 启动服务
sudo systemctl start hbbs hbbr

# 5. 验证
curl http://localhost:21115/health
```

### 7.3 自动回滚脚本

```bash
#!/bin/bash
# rollback.sh

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

echo "Stopping services..."
systemctl stop hbbs hbbr

echo "Rolling back to version $VERSION..."
cp /opt/rustdesk/versions/hbbs-v$VERSION /usr/local/bin/hbbs
cp /opt/rustdesk/versions/hbbr-v$VERSION /usr/local/bin/hbbr

echo "Restoring configuration..."
cp -r /etc/rustdesk.bak/* /etc/rustdesk/

echo "Starting services..."
systemctl start hbbs hbbr

echo "Verifying..."
if curl -s http://localhost:21115/health | grep -q "OK"; then
    echo "Rollback successful!"
else
    echo "Rollback failed!"
    exit 1
fi
```

---

## 8. 部署验证步骤

### 8.1 服务验证

```bash
# 检查服务状态
systemctl status hbbs hbbr

# 检查端口监听
ss -tlnp | grep -E "21115|21116"

# 检查健康检查
curl http://localhost:21115/health
curl http://localhost:21116/health
```

### 8.2 功能验证

```bash
# 使用客户端测试连接
# 1. 配置服务器地址为 your-domain.com
# 2. 尝试建立远程连接
# 3. 验证屏幕共享、输入控制、文件传输功能
```

### 8.3 性能验证

```bash
# 使用 wrk 进行压力测试
wrk -t12 -c400 -d30s http://localhost:21115/

# 检查资源使用
top -p $(pgrep hbbs)
top -p $(pgrep hbbr)
```

### 8.4 安全验证

```bash
# 检查 SSL 证书
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# 检查 TLS 版本
nmap --script ssl-enum-ciphers -p 443 your-domain.com
```

---

## 9. 部署注意事项

### 9.1 安全注意事项

| 事项 | 说明 |
|------|------|
| 禁用密码登录 | 使用 SSH 密钥登录 |
| 定期更新系统 | 保持系统补丁最新 |
| 限制端口访问 | 只开放必要端口 |
| 使用 HTTPS | 启用 SSL/TLS |
| 备份配置文件 | 定期备份关键配置 |

### 9.2 高可用性注意事项

| 事项 | 说明 |
|------|------|
| 多服务器部署 | 避免单点故障 |
| 负载均衡 | 均匀分发流量 |
| 自动故障转移 | 配置健康检查 |
| 数据备份 | 定期备份数据 |

### 9.3 性能注意事项

| 事项 | 说明 |
|------|------|
| 资源监控 | 监控 CPU、内存、磁盘使用 |
| 连接数限制 | 配置合理的连接上限 |
| 日志轮转 | 避免日志占用过多空间 |
| 缓存策略 | 合理配置缓存 |

### 9.4 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 服务无法启动 | 配置错误 | 检查配置文件和日志 |
| 连接失败 | 端口未开放 | 检查防火墙配置 |
| 证书过期 | SSL 证书到期 | 重新申请证书 |
| 性能下降 | 资源不足 | 增加服务器资源 |

---

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 包含部署架构、部署环境准备、部署流程、部署工具使用、版本更新策略、回滚机制、部署验证步骤、部署注意事项