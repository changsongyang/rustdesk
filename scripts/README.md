# RustDesk 一键部署脚本系统

## 概述

RustDesk 一键部署脚本系统提供了一套完整的自动化部署、维护和备份解决方案，支持 Linux、macOS 和 Windows 三大主流平台。通过本脚本系统，用户可以快速部署和管理 RustDesk 远程桌面服务器。

## 功能特性

✅ **一键环境检测** - 自动检测系统环境、Docker、资源占用、端口占用等
✅ **一键安装部署** - 支持 Docker、Kubernetes、源码编译等多种部署方式
✅ **服务全生命周期管理** - 启动、停止、重启、查看状态、日志管理等
✅ **自动备份恢复** - 支持备份加密、定时备份、远程备份、备份验证
✅ **详细日志记录** - 完整的日志输出便于故障排查
✅ **错误恢复机制** - 自动错误检测和回滚机制
✅ **配置管理** - 热更新配置、配置备份恢复
✅ **性能监控** - 实时监控服务性能、连接统计
✅ **跨平台支持** - Linux/macOS (Bash) + Windows (PowerShell)

## 目录结构

```
scripts/
├── linux/
│   ├── check-env.sh          # 环境检测脚本
│   ├── install.sh            # 自动安装脚本
│   ├── manage.sh             # 服务管理脚本
│   └── backup.sh             # 备份恢复脚本
├── windows/
│   ├── check-env.ps1         # 环境检测脚本
│   ├── install.ps1           # 自动安装脚本
│   ├── manage.ps1            # 服务管理脚本
│   └── backup.ps1            # 备份恢复脚本
├── common/
│   ├── config.env           # 环境配置文件
│   └── constants.sh         # 通用常量定义
├── README.md                 # 本文档
└── QUICKSTART.md             # 快速开始指南
```

## 快速开始

详细的使用说明请参考 [QUICKSTART.md](QUICKSTART.md)

### Linux/macOS

```bash
# 1. 进入脚本目录
cd scripts/linux

# 2. 添加执行权限
chmod +x *.sh

# 3. 环境检测
./check-env.sh

# 4. 安装部署
sudo ./install.sh

# 5. 服务管理
./manage.sh status          # 查看状态
./manage.sh logs hbbs       # 查看日志
./manage.sh restart         # 重启服务

# 6. 备份管理
./backup.sh create          # 创建备份
./backup.sh list            # 列出备份
./backup.sh restore <备份名> # 恢复备份
```

### Windows

```powershell
# 1. 进入脚本目录
cd scripts\windows

# 2. 以管理员身份运行 PowerShell

# 3. 环境检测
.\check-env.ps1

# 4. 安装部署
.\install.ps1

# 5. 服务管理
.\manage.ps1 -Command status    # 查看状态
.\manage.ps1 -Command logs      # 查看日志
.\manage.ps1 -Command restart   # 重启服务

# 6. 备份管理
.\backup.ps1 -Command create    # 创建备份
.\backup.ps1 -Command list     # 列出备份
.\backup.ps1 -Command restore   # 恢复备份
```

## 核心功能

### 1. 环境检测 (check-env)

自动检测以下内容：
- 操作系统类型和版本
- Docker 和 Docker Compose 安装情况
- Kubernetes 和 kubectl (可选)
- 系统资源占用 (CPU、内存、磁盘)
- 端口可用性
- 网络连通性
- 防火墙状态
- 必需依赖项

### 2. 自动安装 (install)

支持的部署模式：
- **Docker Compose** (推荐)
- **Kubernetes** (待实现)
- **源码编译** (待实现)

安装内容包括：
- Docker 引擎
- Docker Compose
- RustDesk Server 镜像
- 配置文件生成
- 目录结构创建
- 服务自动启动

### 3. 服务管理 (manage)

支持的操作：
- `start` - 启动服务
- `stop` - 停止服务
- `restart` - 重启服务
- `status` - 查看状态
- `logs [服务]` - 查看日志 (支持 hbbs/hbbr/all)
- `health` - 健康检查
- `stats` - 连接统计
- `config [操作]` - 配置管理
- `update` - 更新服务
- `cleanup` - 清理资源

### 4. 备份恢复 (backup)

功能包括：
- `create [名称]` - 创建备份
- `list` - 列出备份
- `verify [备份]` - 验证备份完整性
- `restore [备份]` - 恢复备份
- `delete [备份]` - 删除备份
- `cleanup` - 清理过期备份
- `schedule [频率]` - 设置定时备份

备份特性：
- 支持 gzip/bzip2/xz 压缩
- 支持 AES-256 加密
- 支持远程备份 (S3/SFTP)
- 备份完整性验证
- 备份元数据记录

## 配置说明

### 环境变量配置

编辑 `common/config.env` 文件：

```bash
# 项目路径
PROJECT_HOME=/opt/rustdesk

# 端口配置
HBBDS_PORT=21115
HBBDS_TLS_PORT=21116
RELAY_PORT=21117
NAT_TYPE_TEST_PORT=21118

# 备份配置
BACKUP_RETENTION_DAYS=30
BACKUP_ENCRYPTION=true

# 镜像源 (中国用户)
DOCKER_MIRROR=https://mirror.ccs.tencentyun.com
```

### 必需端口

确保以下端口可用：

| 端口 | 服务 | 说明 |
|------|------|------|
| 21115 | HBBDS | ID 服务器主端口 |
| 21116 | HBBDS TLS | ID 服务器 TLS 端口 |
| 21117 | RELAY | 中继服务器端口 |
| 21118 | NAT TEST | NAT 类型测试端口 |
| 21119 | STATUS | 状态服务端口 |
| 21120 | HEALTH | 健康检查端口 |

## 故障排查

### 常见问题

#### 1. Docker 未安装

**Linux:**
```bash
curl -fsSL https://get.docker.com | sh
sudo systemctl start docker
sudo systemctl enable docker
```

**Windows:**
下载安装 [Docker Desktop](https://www.docker.com/products/docker-desktop)

#### 2. 端口被占用

```bash
# Linux - 查看端口占用
netstat -tuln | grep 211

# Windows - 查看端口占用
netstat -ano | findstr 211

# 释放端口
sudo kill -9 <PID>
```

#### 3. 服务启动失败

```bash
# 查看日志
docker compose logs

# 检查配置文件
cat docker-compose.yml

# 重新创建容器
docker compose down
docker compose up -d
```

#### 4. 权限问题

```bash
# Linux - 添加用户到 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

#### 5. 网络问题

```bash
# 检查防火墙
sudo firewall-cmd --list-ports

# 开放端口 (Linux)
sudo firewall-cmd --permanent --add-port=21115-21120/tcp
sudo firewall-cmd --reload
```

## 安全建议

1. **使用非 root 用户运行 Docker**
2. **配置防火墙规则**
3. **启用 TLS 加密**
4. **定期备份配置**
5. **监控日志异常**
6. **使用强密码和密钥**

## 性能优化

### Docker 资源限制

编辑 `docker-compose.yml`：

```yaml
services:
  hbbs:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

### 系统参数优化

```bash
# Linux - 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Linux - 网络参数优化
sysctl -w net.core.somaxconn=65535
sysctl -w net.ipv4.tcp_max_syn_backlog=65535
```

## 国际化

支持中文和英文界面，通过环境变量切换：

```bash
# 英文 (默认)
export LANG=en

# 中文
export LANG=zh
```

## 更新日志

### v1.0.0 (2024-01)
- 初始版本发布
- 支持 Linux/Windows/macOS
- Docker Compose 部署
- 完整的服务管理和备份恢复功能

## 贡献指南

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目遵循 [AGPL-3.0 License](LICENSE)

## 联系方式

- GitHub Issues: https://github.com/rustdesk/rustdesk/issues
- 文档: https://rustdesk.com/docs/

## 参考资源

- [RustDesk 官方文档](https://rustdesk.com/docs/)
- [Docker 官方文档](https://docs.docker.com/)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)

---

**提示**: 如遇问题，请优先查看脚本输出的错误信息和日志。
