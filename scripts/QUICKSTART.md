# RustDesk 一键部署快速开始指南

## 🚀 5分钟快速部署

本指南将帮助你在5分钟内快速部署 RustDesk 服务器。

### 前置要求

- Linux / macOS / Windows 操作系统
- 2核 CPU / 2GB 内存 / 10GB 可用磁盘空间
- root 或管理员权限
- 网络可访问 Docker Hub

---

## 📦 Linux / macOS 部署

### 第一步：下载脚本

```bash
# 进入项目目录
cd /path/to/rustdesk

# 进入脚本目录
cd scripts/linux

# 添加执行权限
chmod +x *.sh
```

### 第二步：环境检测

```bash
# 运行环境检测
./check-env.sh
```

查看输出，确保：
- ✅ Docker 已安装
- ✅ 系统资源充足
- ✅ 端口可用

### 第三步：安装部署

```bash
# 交互式安装
sudo ./install.sh

# 或静默安装（自动化部署）
sudo ./install.sh --silent
```

安装过程会自动：
1. 安装 Docker（如未安装）
2. 安装 Docker Compose
3. 创建目录结构
4. 生成配置文件
5. 启动服务

### 第四步：验证部署

```bash
# 查看服务状态
./manage.sh status

# 查看服务日志
./manage.sh logs hbbs
```

---

## 🖥️ Windows 部署

### 第一步：准备环境

1. 下载安装 [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. 确保启用 WSL2 和 Hyper-V
3. 以管理员身份打开 PowerShell

### 第二步：运行脚本

```powershell
# 进入脚本目录
cd C:\path\to\rustdesk\scripts\windows

# 环境检测
.\check-env.ps1

# 安装部署
.\install.ps1

# 查看状态
.\manage.ps1 -Command status
```

---

## 🔧 基础配置

### 获取公钥

```bash
# Linux/macOS
docker logs rustdesk-hbbs 2>&1 | grep "public key"

# Windows
docker logs rustdesk-hbbs 2>&1 | Select-String "public key"
```

### 配置 RustDesk 客户端

1. 打开 RustDesk 客户端
2. 设置 → 网络 → ID 服务器
3. 输入你的服务器地址（IP 或域名）
4. 填入上面获取的公钥
5. 保存并重新连接

---

## 📊 常用命令

### 服务管理

```bash
# 查看状态
./manage.sh status

# 查看日志
./manage.sh logs hbbs        # 查看 hbbs 日志
./manage.sh logs hbbr        # 查看 hbbr 日志
./manage.sh logs all         # 查看所有日志

# 实时日志
./manage.sh logs all --follow

# 重启服务
./manage.sh restart

# 停止服务
./manage.sh stop

# 启动服务
./manage.sh start

# 健康检查
./manage.sh health

# 连接统计
./manage.sh stats
```

### 备份恢复

```bash
# 创建备份
./backup.sh create                    # 自动命名
./backup.sh create my-backup         # 自定义名称

# 列出备份
./backup.sh list

# 验证备份
./backup.sh verify <备份文件名>

# 恢复备份
./backup.sh restore <备份文件名>

# 删除备份
./backup.sh delete <备份文件名>

# 清理过期备份
./backup.sh cleanup

# 设置定时备份
./backup.sh schedule daily           # 每日备份
./backup.sh schedule weekly          # 每周备份
./backup.sh schedule monthly         # 每月备份
```

### 配置管理

```bash
# 查看当前配置
./manage.sh config show

# 编辑配置
./manage.sh config edit

# 备份配置
./manage.sh config backup-config

# 重载配置
./manage.sh config reload
```

---

## 🔒 安全配置

### 1. 配置防火墙

```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 21115:21120/tcp

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=21115-21120/tcp
sudo firewall-cmd --reload

# 检查状态
sudo firewall-cmd --list-ports
```

### 2. 启用备份加密

```bash
# 创建加密备份
./backup.sh create --encrypt

# 恢复加密备份
./backup.sh restore <加密备份文件名>
```

### 3. 配置 TLS

编辑 `docker-compose.yml`：

```yaml
services:
  hbbs:
    environment:
      - ENABLE_TLS=true
```

---

## 🔍 故障排查

### 问题 1：Docker 未运行

**症状**: 安装脚本报错 "Docker 服务未运行"

**解决方案**:
```bash
# Linux - 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# macOS - 重启 Docker Desktop
open -a Docker

# Windows - 重启 Docker Desktop
Restart-Service com.docker.service
```

### 问题 2：端口被占用

**症状**: 服务启动失败，端口冲突

**解决方案**:
```bash
# 查找占用端口的进程
# Linux
netstat -tulnp | grep 21115

# Windows
netstat -ano | findstr 21115

# 停止占用进程或修改配置中的端口
```

### 问题 3：连接失败

**症状**: 客户端无法连接到服务器

**排查步骤**:
```bash
# 1. 检查服务状态
./manage.sh status

# 2. 检查端口监听
netstat -tuln | grep 211

# 3. 检查防火墙
sudo firewall-cmd --list-ports

# 4. 测试网络连通性
telnet <服务器IP> 21115

# 5. 查看日志
./manage.sh logs all
```

### 问题 4：备份恢复失败

**症状**: 恢复备份后服务无法启动

**解决方案**:
```bash
# 1. 验证备份完整性
./backup.sh verify <备份文件名>

# 2. 检查备份文件
ls -lh /opt/rustdesk/backups/

# 3. 手动解压检查
tar -tzf <备份文件> | head -20
```

---

## 💡 最佳实践

### 1. 定期备份

```bash
# 设置每日自动备份
./backup.sh schedule daily

# 保留最近 30 天备份
./backup.sh cleanup --retention 30
```

### 2. 监控服务

```bash
# 添加到 crontab
crontab -e

# 添加健康检查
*/5 * * * * /path/to/manage.sh health >> /var/log/rustdesk-health.log 2>&1
```

### 3. 日志管理

```bash
# 配置日志轮转
cat > /etc/logrotate.d/rustdesk << EOF
/opt/rustdesk/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF
```

### 4. 性能优化

```bash
# Linux - 增加文件描述符
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Linux - 网络优化
echo "net.core.somaxconn=65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog=65535" >> /etc/sysctl.conf
sysctl -p
```

---

## 📝 配置示例

### 基础配置 (config.env)

```bash
PROJECT_HOME=/opt/rustdesk
HBBDS_PORT=21115
HBBDS_TLS_PORT=21116
RELAY_PORT=21117
NAT_TYPE_TEST_PORT=21118
ENABLE_TLS=true
LOG_LEVEL=info
BACKUP_RETENTION_DAYS=30
```

### Docker Compose 配置

```yaml
version: '3.8'

services:
  hbbs:
    container_name: rustdesk-hbbs
    image: rustdesk/rustdesk-server:latest
    command: hbbs -k _
    ports:
      - "21115:21115"
      - "21116:21116"
      - "21118:21118"
    volumes:
      - ./data:/data
    restart: unless-stopped
    network_mode: host

  hbbr:
    container_name: rustdesk-hbbr
    image: rustdesk/rustdesk-server:latest
    command: hbbr -k _
    ports:
      - "21117:21117"
    volumes:
      - ./data:/data
    restart: unless-stopped
    network_mode: host
    depends_on:
      - hbbs
```

---

## 🆘 获取帮助

### 文档资源

- [RustDesk 官方文档](https://rustdesk.com/docs/)
- [Docker 官方文档](https://docs.docker.com/)
- [常见问题解答](FAQ.md)

### 获取日志

```bash
# 完整诊断信息
./check-env.sh > diagnostics.log 2>&1

# 服务日志
./manage.sh logs all > service.log 2>&1

# Docker 状态
docker info > docker-info.log 2>&1
docker ps -a > docker-ps.log 2>&1
```

### 社区支持

- GitHub Issues: https://github.com/rustdesk/rustdesk/issues
- 论坛: https://github.com/rustdesk/rustdesk/discussions
- Discord: https://discord.gg/rustdesk

---

## ✅ 验证清单

部署完成后，确认以下项目：

- [ ] `./manage.sh status` 显示所有服务运行中
- [ ] 端口 21115-21120 被正确监听
- [ ] 防火墙已开放所需端口
- [ ] 可以获取公钥：`docker logs rustdesk-hbbs`
- [ ] 客户端可以连接到服务器
- [ ] 备份功能正常：`./backup.sh create`
- [ ] 日志可正常查看：`./manage.sh logs`

---

**恭喜！** 🎉 你的 RustDesk 服务器已成功部署。

如有任何问题，请查看详细的 [README.md](README.md) 或提交 GitHub Issue。
