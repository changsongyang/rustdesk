# RustDesk Linux 平台编译指南

## 目录

1. [环境准备](#1-环境准备)
2. [源码获取](#2-源码获取)
3. [编译步骤](#3-编译步骤)
4. [服务配置](#4-服务配置)
5. [防火墙配置](#5-防火墙配置)
6. [性能优化](#6-性能优化)
7. [故障排除](#7-故障排除)
8. [验证部署](#8-验证部署)

---

## 1. 环境准备

### 1.1 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 2 核 | 4 核或更多 |
| 内存 | 4 GB | 8 GB 或更多 |
| 磁盘空间 | 10 GB | 20 GB 或更多 |
| 系统架构 | x86_64 或 aarch64 | x86_64 或 aarch64 |

### 1.2 操作系统支持

- Ubuntu 20.04/22.04 LTS
- Debian 10/11/12
- CentOS 8/Rocky Linux 8+
- Fedora 34+
- Arch Linux
- openSUSE Leap 15.4+

### 1.3 安装编译依赖

根据你的 Linux 发行版选择对应命令：

**Ubuntu/Debian**:

```bash
# 更新软件包列表
sudo apt update

# 安装基础编译工具
sudo apt install -y build-essential cmake ninja-build pkg-config git curl

# 安装 Rust 和 Cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 激活 Rust 环境
source ~/.cargo/env

# 添加 Rust 目标平台
rustup target add x86_64-unknown-linux-gnu

# 安装系统库
sudo apt install -y \
    libssl-dev \
    libxdo-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libgl1-mesa-dev \
    libasound2-dev \
    libpulse-dev

# 安装协议缓冲区
sudo apt install -y protobuf-compiler libprotobuf-dev

# 安装视频编解码库
sudo apt install -y \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libopus-dev \
    libvpx-dev

# 安装屏幕捕获依赖
sudo apt install -y \
    libx11-dev \
    libxext-dev \
    libxdamage-dev \
    libxfixes-dev \
    libxcomposite-dev \
    libxrandr-dev

# 安装 Systemd 开发库
sudo apt install -y libsystemd-dev
```

**CentOS/RHEL/Rocky Linux**:

```bash
# 启用 EPEL 和 PowerTools
sudo dnf install -y epel-release
sudo dnf config-manager --set-enabled powertools

# 安装基础编译工具
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y cmake ninja-build pkg-config git curl

# 安装 Rust 和 Cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup target add x86_64-unknown-linux-gnu

# 安装系统库
sudo dnf install -y \
    openssl-devel \
    xdotool \
    libxkbcommon-devel \
    libxkbcommon-x11-devel \
    mesa-libGL-devel \
    alsa-lib-devel \
    pulseaudio-libs-devel

# 安装协议缓冲区
sudo dnf install -y protobuf-compiler protobuf-devel

# 安装视频编解码库
sudo dnf install -y \
    ffmpeg-devel \
    opus-devel \
    libvpx-devel

# 安装 Systemd 开发库
sudo dnf install -y systemd-devel
```

**Fedora**:

```bash
# 安装基础编译工具
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y cmake ninja-build pkg-config git curl

# 安装 Rust 和 Cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup target add x86_64-unknown-linux-gnu

# 安装系统库
sudo dnf install -y \
    openssl-devel \
    xdotool \
    libxkbcommon-devel \
    libxkbcommon-x11-devel \
    mesa-libGL-devel \
    alsa-lib-devel \
    pulseaudio-libs-devel

# 安装协议缓冲区
sudo dnf install -y protobuf-compiler protobuf-devel

# 安装视频编解码库
sudo dnf install -y \
    ffmpeg-devel \
    opus-devel \
    libvpx-devel
```

**Arch Linux/Manjaro**:

```bash
# 安装基础编译工具
sudo pacman -S --needed base-devel cmake ninja pkg-config git curl

# 安装 Rust 和 Cargo
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
rustup target add x86_64-unknown-linux-gnu

# 安装系统库
sudo pacman -S --needed \
    openssl \
    xdotool \
    libxkbcommon \
    libxkbcommon-x11 \
    mesa \
    alsa-lib \
    pulseaudio

# 安装协议缓冲区
sudo pacman -S --needed protobuf

# 安装视频编解码库
sudo pacman -S --needed ffmpeg opus libvpx
```

### 1.4 国内镜像加速（可选）

如果在中国大陆，可以使用国内镜像加速下载：

```bash
# 设置 Rust 镜像源
cat >> ~/.cargo/config.toml << 'EOF'
[source.crates-io]
replace-with = "rsproxy-sparse"

[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[net]
git-fetch-with-cli = true
EOF

# 设置 Git 镜像（可选）
git config --global url."https://ghproxy.com/".insteadOf https://github.com
```

### 1.5 验证安装

```bash
# 验证 Rust 安装
rustc --version
cargo --version
rustup --version

# 验证编译工具
gcc --version
cmake --version
pkg-config --version

# 验证协议缓冲区
protoc --version
```

---

## 2. 源码获取

### 2.1 克隆仓库

```bash
# 创建工作目录
mkdir -p ~/rustdesk-build
cd ~/rustdesk-build

# 克隆主仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 初始化子模块
git submodule update --init --recursive
```

### 2.2 选择版本

```bash
# 查看可用标签
git tag

# 切换到最新稳定版本（以 v1.2.0 为例）
git checkout v1.2.0

# 或使用最新开发版本
git checkout develop
```

### 2.3 目录结构

```
rustdesk/
├── src/                      # Rust 服务端代码
│   ├── server/              # 服务器核心
│   ├── platform/           # 平台特定代码
│   └── rendezvous_mediator.rs
├── libs/                    # 共享库
│   ├── hbb_common/         # 通用工具
│   ├── scrap/              # 屏幕捕获
│   ├── enigo/              # 输入控制
│   └── clipboard/          # 剪贴板
├── flutter/                # Flutter UI
└── docs/                   # 文档
```

---

## 3. 编译步骤

### 3.1 环境变量配置

```bash
# 设置编译优化标志
export RUSTFLAGS="-C opt-level=3"

# 设置并行编译数量（根据 CPU 核心数）
export CARGO_BUILD_JOBS=$(nproc)

# 启用 LTO（链接时优化，提升性能）
export RUSTFLAGS="-C lto=fat -C codegen-units=1"

# 可选：设置日志级别
export RUST_LOG=info
```

### 3.2 纯 Rust 编译（仅服务端）

如果你只需要编译服务端（hbbs 和 hbrs），无需 Flutter：

```bash
# 进入项目目录
cd rustdesk

# 编译 Release 版本
cargo build --release

# 或编译 Debug 版本（更快但性能较差）
cargo build

# 编译后的二进制文件位于：
# target/release/hbbs   - RustDesk ID/HBBS 服务器
# target/release/hbrs   - RustDesk 中继服务器
```

### 3.3 完整编译（包括 Flutter UI）

```bash
# 1. 编译 Rust 服务端
cargo build --release

# 2. 安装 Flutter 依赖
cd flutter
flutter pub get

# 3. 配置 Linux 桌面构建
flutter config --enable-linux-desktop

# 4. 编译 Linux 版本
flutter build linux --release

# 编译产物位于：
# flutter/build/linux/x64/release/bundle/
```

### 3.4 指定目标架构

**x86_64**:

```bash
cargo build --release --target x86_64-unknown-linux-gnu
```

**ARM64 (aarch64)**:

```bash
# 先添加目标平台
rustup target add aarch64-unknown-linux-gnu

# 编译
cargo build --release --target aarch64-unknown-linux-gnu
```

### 3.5 编译选项

**最小化编译（减少二进制大小）**:

```bash
# 设置剥离符号
export RUSTFLAGS="-C strip=symbols -C lto=fat -C codegen-units=1"

cargo build --release --release
```

**启用硬件加速**:

```bash
# AVX2 加速（现代 Intel/AMD CPU）
export RUSTFLAGS="-C target-cpu=haswell"

# AVX512 加速（高端服务器 CPU）
export RUSTFLAGS="-C target-cpu=skylake-avx512"

cargo build --release
```

### 3.6 编译脚本

创建编译脚本 `build-server.sh`：

```bash
#!/bin/bash
set -e

echo "=== RustDesk 服务端编译脚本 ==="

# 设置变量
BUILD_DIR="$HOME/rustdesk-build"
PROJECT_DIR="$BUILD_DIR/rustdesk"
BUILD_TYPE="${1:-release}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Rust
if ! command -v rustc &> /dev/null; then
    log_error "Rust 未安装，请先安装 Rust"
    exit 1
fi

# 进入项目目录
cd "$PROJECT_DIR"

# 清理旧构建
if [ "$BUILD_TYPE" == "clean" ]; then
    log_info "清理构建目录..."
    cargo clean
fi

# 设置优化标志
export RUSTFLAGS="-C lto=fat -C codegen-units=1 -C opt-level=3"

# 编译
log_info "开始编译 RustDesk 服务端..."
cargo build --release

# 复制二进制文件
log_info "复制二进制文件到 output 目录..."
mkdir -p "$BUILD_DIR/output"
cp target/release/hbbs "$BUILD_DIR/output/"
cp target/release/hbrs "$BUILD_DIR/output/"

# 设置可执行权限
chmod +x "$BUILD_DIR/output/hbbs"
chmod +x "$BUILD_DIR/output/hbrs"

log_info "编译完成！"
log_info "二进制文件位于: $BUILD_DIR/output/"
ls -lh "$BUILD_DIR/output/"
```

使用方式：

```bash
chmod +x build-server.sh
./build-server.sh release
```

---

## 4. 服务配置

### 4.1 创建服务用户

```bash
# 创建专用用户（推荐）
sudo useradd -r -s /bin/false rustdesk

# 创建数据目录
sudo mkdir -p /var/lib/rustdesk
sudo chown rustdesk:rustdesk /var/lib/rustdesk
```

### 4.2 部署二进制文件

```bash
# 创建部署目录
sudo mkdir -p /opt/rustdesk
sudo mkdir -p /var/lib/rustdesk/{hbbs,hbrs}

# 复制二进制文件
sudo cp target/release/hbbs /opt/rustdesk/
sudo cp target/release/hbrs /opt/rustdesk/

# 设置权限
sudo chown rustdesk:rustdesk /opt/rustdesk/hbbs
sudo chown rustdesk:rustdesk /opt/rustdesk/hbrs
sudo chmod +x /opt/rustdesk/hbbs
sudo chmod +x /opt/rustdesk/hbrs
```

### 4.3 HBBS 配置（ID 服务器）

#### 4.3.1 Systemd 服务文件

创建 `/etc/systemd/system/rustdesk-hbbs.service`:

```ini
[Unit]
Description=RustDesk ID/HBBS Server
Documentation=https://github.com/rustdesk/rustdesk
After=network.target

[Service]
Type=simple
User=rustdesk
Group=rustdesk
WorkingDirectory=/var/lib/rustdesk/hbbs
ExecStart=/opt/rustdesk/hbbs
Restart=always
RestartSec=5

# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/rustdesk/hbbs
PrivateTmp=true

# 环境变量（可选）
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
```

#### 4.3.2 HBBS 配置目录

```bash
sudo -u rustdesk mkdir -p /var/lib/rustdesk/hbbs
```

#### 4.3.3 HBBS 命令行参数

```bash
# 查看可用参数
/opt/rustdesk/hbbs --help

# 常用参数：
# -k <file>   私钥文件路径（用于加密通信）
# -r <addr>   中继服务器地址
# -l <port>   监听端口（默认 21115）
# --help      显示帮助信息
```

### 4.4 HBRS 配置（中继服务器）

#### 4.4.1 Systemd 服务文件

创建 `/etc/systemd/system/rustdesk-hbrs.service`:

```ini
[Unit]
Description=RustDesk Relay/HBRS Server
Documentation=https://github.com/rustdesk/rustdesk
After=network.target

[Service]
Type=simple
User=rustdesk
Group=rustdesk
WorkingDirectory=/var/lib/rustdesk/hbrs
ExecStart=/opt/rustdesk/hbrs
Restart=always
RestartSec=5

# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/rustdesk/hbrs
PrivateTmp=true

# 环境变量（可选）
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
```

#### 4.4.2 HBRS 配置目录

```bash
sudo -u rustdesk mkdir -p /var/lib/rustdesk/hbrs
```

#### 4.4.3 HBRS 命令行参数

```bash
# 查看可用参数
/opt/rustdesk/hbrs --help

# 常用参数：
# -k <file>   私钥文件路径
# -l <port>   监听端口（默认 21117）
# -s <port>   RUDP 端口（默认 21116）
# --help      显示帮助信息
```

### 4.5 启用并启动服务

```bash
# 重新加载 systemd
sudo systemctl daemon-reload

# 启用服务（开机自启）
sudo systemctl enable rustdesk-hbbs
sudo systemctl enable rustdesk-hbrs

# 启动服务
sudo systemctl start rustdesk-hbbs
sudo systemctl start rustdesk-hbrs

# 检查服务状态
sudo systemctl status rustdesk-hbbs
sudo systemctl status rustdesk-hbrs

# 查看日志
sudo journalctl -u rustdesk-hbbs -f
sudo journalctl -u rustdesk-hbrs -f
```

### 4.6 服务管理命令

```bash
# 停止服务
sudo systemctl stop rustdesk-hbbs
sudo systemctl stop rustdesk-hbrs

# 重启服务
sudo systemctl restart rustdesk-hbbs
sudo systemctl restart rustdesk-hbrs

# 查看服务状态
sudo systemctl status rustdesk-hbbs
sudo systemctl status rustdesk-hbrs

# 查看实时日志
sudo journalctl -u rustdesk-hbbs -f
sudo journalctl -u rustdesk-hbrs -f

# 查看最近日志
sudo journalctl -u rustdesk-hbbs --since "1 hour ago"
sudo journalctl -u rustdesk-hbrs --since "1 hour ago"
```

---

## 5. 防火墙配置

### 5.1 必需端口

RustDesk 服务需要以下端口：

| 端口 | 协议 | 用途 | 服务 |
|------|------|------|------|
| 21115 | TCP | ID/HBBS 服务 | hbbs |
| 21116 | TCP/UDP | 中继连接 | hbrs |
| 21117 | TCP | RUDP 中继 | hbrs |
| 21118 | TCP | 测试端口 | - |
| 21119 | TCP | WebSocket | hbbs |

### 5.2 UFW (Ubuntu/Debian)

```bash
# 安装 UFW
sudo apt install -y ufw

# 允许 SSH（重要！防止锁死服务器）
sudo ufw allow 22/tcp

# 允许 RustDesk 端口
sudo ufw allow 21115/tcp
sudo ufw allow 21116/tcp
sudo ufw allow 21116/udp
sudo ufw allow 21117/tcp
sudo ufw allow 21118/tcp
sudo ufw allow 21119/tcp

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status verbose
```

### 5.3 firewalld (CentOS/RHEL/Fedora)

```bash
# 启动 firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld

# 添加端口规则
sudo firewall-cmd --permanent --add-port=21115/tcp
sudo firewall-cmd --permanent --add-port=21116/tcp
sudo firewall-cmd --permanent --add-port=21116/udp
sudo firewall-cmd --permanent --add-port=21117/tcp
sudo firewall-cmd --permanent --add-port=21118/tcp
sudo firewall-cmd --permanent --add-port=21119/tcp

# 重新加载防火墙
sudo firewall-cmd --reload

# 查看开放端口
sudo firewall-cmd --list-ports
```

### 5.4 iptables

```bash
# 添加规则（临时，重启失效）
sudo iptables -A INPUT -p tcp --dport 21115 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 21116 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 21116 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 21117 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 21118 -j ACCEPT
sudo iptables -A udp --dport 21119 -j ACCEPT

# 保存规则（Debian/Ubuntu）
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

# 保存规则（CentOS/RHEL）
sudo service iptables save
```

### 5.5 云服务器特殊配置

**阿里云/腾讯云**:

```bash
# 登录云控制台
# 找到 "安全组" 或 "防火墙"
# 添加上述端口的入站规则
```

**AWS EC2**:

```bash
# 通过 AWS CLI 添加安全组规则
aws ec2 authorize-security-group-ingress \
    --group-id <security-group-id> \
    --protocol tcp \
    --port 21115 \
    --cidr 0.0.0.0/0

# 或通过控制台
# EC2 Dashboard -> Security Groups -> Edit inbound rules
```

### 5.6 验证防火墙配置

```bash
# 检查端口是否开放
sudo ss -tuln | grep -E '(21115|21116|21117|21118|21119)'

# 或使用 nc 测试
nc -zv localhost 21115
nc -zv localhost 21116
nc -zv localhost 21117

# 从外部测试（使用在线端口扫描工具）
# 访问 https://tool.chinaz.com/port
# 扫描你的服务器 IP 的 21115-21119 端口
```

---

## 6. 性能优化

### 6.1 编译优化

**启用 LTO（链接时优化）**:

```bash
export RUSTFLAGS="-C lto=fat -C codegen-units=1"
cargo build --release
```

**目标 CPU 优化**:

```bash
# Intel Haswell 及更新 / AMD Zen 及更新
export RUSTFLAGS="-C target-cpu=haswell"

# 高端服务器（AVX2）
export RUSTFLAGS="-C target-cpu=skylake"

# 超高性能（AVX512）
export RUSTFLAGS="-C target-cpu=skylake-avx512"

cargo build --release
```

### 6.2 服务优化

**系统限制**:

```bash
# 编辑 /etc/security/limits.conf
sudo nano /etc/security/limits.conf

# 添加以下行
rustdesk soft nofile 65535
rustdesk hard nofile 65535
rustdesk soft nproc 4096
rustdesk hard nproc 4096
```

**Systemd 服务优化**:

修改 `/etc/systemd/system/rustdesk-hbbs.service`:

```ini
[Service]
# 增加打开文件描述符限制
LimitNOFILE=65535

# 性能优化
Nice=-5
CPUSchedulingPolicy=batch

# 内存限制（根据可用内存调整）
MemoryMax=2G
```

### 6.3 网络优化

**内核参数调整**:

```bash
# 编辑 /etc/sysctl.conf
sudo nano /etc/sysctl.conf

# 添加以下配置
# 网络连接优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# 文件描述符
fs.file-max = 1000000

# 应用更改
sudo sysctl -p
```

### 6.4 日志优化

**限制日志大小**:

创建 `/etc/systemd/journald.conf.d/rustdesk.conf`:

```ini
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=10M
MaxRetentionSec=1week
```

重启日志服务：

```bash
sudo systemctl restart systemd-journald
```

---

## 7. 故障排除

### 7.1 编译错误

**错误 1**: `error: failed to run custom build command for ...`

```bash
# 解决方案：安装缺失的依赖
sudo apt install -y libssl-dev libxdo-dev protobuf-compiler

# 清理并重新编译
cargo clean
cargo build --release
```

**错误 2**: `error: unable to find native library`

```bash
# 设置 PKG_CONFIG_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# 或安装库到标准位置
sudo ldconfig
```

**错误 3**: `error: linker cc not found`

```bash
# 安装 GCC
sudo apt install -y build-essential

# 或使用 Clang
sudo apt install -y clang
export CC=clang
export CXX=clang++
cargo build --release
```

**错误 4**: 内存不足

```bash
# 减少并行编译数
cargo build --release -j 2

# 或创建交换空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 7.2 服务启动失败

**检查日志**:

```bash
sudo journalctl -u rustdesk-hbbs -n 100 --no-pager
sudo journalctl -u rustdesk-hbrs -n 100 --no-pager
```

**常见问题**:

1. **端口被占用**:
   ```bash
   # 检查端口占用
   sudo ss -tuln | grep 21115
   
   # 停止占用进程或更改端口
   ```

2. **权限不足**:
   ```bash
   # 检查文件权限
   ls -lh /opt/rustdesk/
   
   # 修复权限
   sudo chown -R rustdesk:rustdesk /opt/rustdesk
   sudo chown -R rustdesk:rustdesk /var/lib/rustdesk
   ```

3. **配置错误**:
   ```bash
   # 检查配置文件语法
   /opt/rustdesk/hbbs --help
   
   # 查看工作目录
   sudo ls -la /var/lib/rustdesk/hbbs/
   ```

### 7.3 连接问题

**防火墙阻止**:

```bash
# 检查防火墙状态
sudo ufw status
sudo firewall-cmd --list-all

# 临时关闭防火墙测试
sudo ufw disable
# 或
sudo systemctl stop firewalld

# 测试后重新启用
sudo ufw enable
```

**SELinux 阻止**:

```bash
# 检查 SELinux 状态
getenforce

# 如果是 Enforcing 模式
sudo setsebool -P nis_enabled 1

# 或添加策略
sudo semanage port -a -t http_port_t -p tcp 21115
```

### 7.4 性能问题

**CPU 使用率过高**:

```bash
# 查看进程状态
top -p $(pgrep hbbs)
htop

# 限制 CPU 使用（使用 cpulimit）
sudo apt install -y cpulimit
sudo cpulimit -p $(pgrep hbbs) -l 50
```

**内存泄漏**:

```bash
# 检查内存使用
free -h
ps aux | grep hbbs

# 重启服务
sudo systemctl restart rustdesk-hbbs
```

---

## 8. 验证部署

### 8.1 本地验证

```bash
# 检查进程运行
ps aux | grep -E 'hbbs|hbrs' | grep -v grep

# 检查端口监听
sudo ss -tuln | grep -E '(21115|21116|21117|21118|21119)'

# 检查服务状态
sudo systemctl status rustdesk-hbbs
sudo systemctl status rustdesk-hbrs
```

### 8.2 功能测试

```bash
# 测试 HBBS 连接
nc -zv localhost 21115

# 测试 HBRS 连接
nc -zv localhost 21116
nc -zv localhost 21117

# 查看日志
sudo journalctl -u rustdesk-hbbs -f
sudo journalctl -u rustdesk-hbrs -f
```

### 8.3 远程测试

1. **配置客户端**:
   - 打开 RustDesk 客户端
   - 进入设置 -> 网络
   - 设置 ID 服务器为你的服务器 IP/域名
   - 设置中继服务器为你的服务器 IP/域名

2. **测试连接**:
   - 使用另一台设备尝试连接
   - 检查是否能正常建立连接
   - 测试文件传输功能

3. **验证中继**:
   - 在防火墙后测试
   - 确保 NAT 穿透失败时能走中继
   - 检查中继连接日志

### 8.4 监控设置

**创建监控脚本**:

```bash
#!/bin/bash
# check-rustdesk.sh

HBBS_STATUS=$(systemctl is-active rustdesk-hbbs)
HBRS_STATUS=$(systemctl is-active rustdesk-hbrs)

if [ "$HBBS_STATUS" != "active" ]; then
    echo "ERROR: rustdesk-hbbs is not running"
    exit 1
fi

if [ "$HBRS_STATUS" != "active" ]; then
    echo "ERROR: rustdesk-hbrs is not running"
    exit 1
fi

echo "OK: All RustDesk services are running"
exit 0
```

添加到 cron 定时任务：

```bash
# 编辑 crontab
sudo crontab -e

# 添加监控任务（每 5 分钟检查一次）
*/5 * * * * /opt/rustdesk/scripts/check-rustdesk.sh >> /var/log/rustdesk-check.log 2>&1
```

---

## 相关文档

- [BUILD_PREREQUISITES.md](BUILD_PREREQUISITES.md) - 编译依赖清单
- [BUILD_WINDOWS.md](BUILD_WINDOWS.md) - Windows 编译指南
- [BUILD_MACOS.md](BUILD_MACOS.md) - macOS 编译指南
- [BUILD_CROSS_COMPILE.md](BUILD_CROSS_COMPILE.md) - 交叉编译指南
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署总览
