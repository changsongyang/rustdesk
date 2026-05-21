# 中国镜像加速方案

本文档提供在中国部署 RustDesk 时使用的镜像加速方案，包括 Rust、Cargo、Docker 和 GitHub 的镜像配置。

## 目录

- [Rust/Cargo 镜像配置](#1-rustcargo-镜像配置)
  - [镜像源列表](#11-镜像源列表)
  - [配置方法](#12-配置方法)
  - [自动配置脚本](#13-自动配置脚本)
- [Docker 镜像加速](#2-docker-镜像加速)
  - [镜像加速器配置](#21-镜像加速器配置)
  - [daemon.json 配置](#22-daemonjson-配置)
  - [镜像源选择建议](#23-镜像源选择建议)
- [GitHub 镜像加速](#3-github-镜像加速)
  - [镜像列表](#31-镜像列表)
  - [Git 协议优化](#32-git-协议优化)
  - [SSH 配置优化](#33-ssh-配置优化)
- [Flutter/Dart 镜像](#4-flutterdart-镜像)
- [故障排查](#5-故障排查)
- [性能测试](#6-性能测试)

---

## 1. Rust/Cargo 镜像配置

### 1.1 镜像源列表

#### 1.1.1 rsproxy（推荐）

| 类型 | 地址 | 说明 |
|------|------|------|
| 稀疏索引 | `sparse+https://rsproxy.cn/index/` | 最新推荐的稀疏索引方式 |
| Git 索引 | `https://rsproxy.cn/crates.io-index` | 传统 git 索引方式 |

#### 1.1.2 中科大镜像

| 类型 | 地址 | 说明 |
|------|------|------|
| 稀疏索引 | `sparse+https://mirrors.ustc.edu.cn/crates.io-index/` | 稀疏索引方式 |
| Git 索引 | `https://mirrors.ustc.edu.cn/crates.io-index` | 传统 git 索引方式 |

#### 1.1.3 清华大学镜像

| 类型 | 地址 | 说明 |
|------|------|------|
| 稀疏索引 | `sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/` | 稀疏索引方式 |
| Git 索引 | `https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index` | 传统 git 索引方式 |

#### 1.1.4 阿里云镜像

| 类型 | 地址 | 说明 |
|------|------|------|
| 稀疏索引 | `sparse+https://mirrors.aliyun.com/crates.io-index/` | 稀疏索引方式 |
| Git 索引 | `https://mirrors.aliyun.com/git/crates.io-index` | 传统 git 索引方式 |

### 1.2 配置方法

#### 1.2.1 稀疏索引配置（推荐）

稀疏索引是 Cargo 1.68+ 引入的新特性，显著提升下载速度。

创建或编辑 `~/.cargo/config.toml`（Linux/macOS）或 `C:\Users\用户名\.cargo\config.toml`（Windows）：

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

#### 1.2.2 Git 索引配置（传统方式）

```toml
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"

[net]
git-fetch-with-cli = true
```

#### 1.2.3 多镜像配置（故障转移）

```toml
[source.crates-io]
replace-with = 'mirror'

[source.mirror]
registry = "sparse+https://rsproxy.cn/index/"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"

[source.tuna]
registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"

[source.aliyun]
registry = "sparse+https://mirrors.aliyun.com/crates.io-index/"

[net]
git-fetch-with-cli = true
```

#### 1.2.4 环境变量配置

除了配置文件，也可以通过环境变量设置：

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

### 1.3 自动配置脚本

使用项目提供的自动配置脚本：

```bash
# 下载并运行自动配置脚本
curl -fSL https://raw.githubusercontent.com/rustdesk/rustdesk/master/tools/mirror/auto-mirror.sh -o /tmp/auto-mirror.sh
chmod +x /tmp/auto-mirror.sh
/tmp/auto-mirror.sh --all

# 或者只配置 Rust/Cargo
/tmp/auto-mirror.sh --cargo
```

---

## 2. Docker 镜像加速

### 2.1 镜像加速器配置

#### 2.1.1 阿里云镜像加速器

阿里云为中国开发者提供免费镜像加速服务。

1. 访问 [阿里云容器镜像服务](https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors)
2. 登录后获取专属加速器地址，格式如：`https://xxx.mirror.aliyuncs.com`
3. 配置 Docker daemon

#### 2.1.2 腾讯云镜像加速器

1. 访问 [腾讯云容器镜像服务](https://console.cloud.tencent.com/tke2/registry)
2. 获取加速器地址

#### 2.1.3 Docker Hub 官方镜像

| 加速器 | 地址 | 备注 |
|--------|------|------|
| Docker Hub | `docker.io` | 官方镜像库 |
| GCR (Google Container Registry) | `gcr.io` | Google 镜像 |
| Quay | `quay.io` | Red Hat 镜像库 |
| GitHub Container Registry | `ghcr.io` | GitHub 镜像 |

### 2.2 daemon.json 配置

编辑 Docker 配置文件（Linux: `/etc/docker/daemon.json`，Windows: `%PROGRAMDATA%\Docker\config\daemon.json`）：

```json
{
  "registry-mirrors": [
    "https://<your-id>.mirror.aliyuncs.com",
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "insecure-registries": [],
  "experimental": false,
  "debug": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "data-root": "/var/lib/docker",
  "storage-driver": "overlay2"
}
```

#### 多平台配置示例

**Windows (Docker Desktop)**

```json
{
  "registry-mirrors": [
    "https://docker.rainbond.cc",
    "https://docker.m.daocloud.io"
  ],
  "insecure-registries": [],
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
```

**Linux**

```json
{
  "registry-mirrors": [
    "https://docker.rainbond.cc",
    "https://docker.m.daocloud.io",
    "https://registry.docker-cn.com"
  ],
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
```

### 2.3 镜像源选择建议

| 场景 | 推荐镜像 | 说明 |
|------|----------|------|
| 通用场景 | 阿里云/腾讯云 | 速度快，稳定性好 |
| 企业内网 | 中科大镜像 | 适合内网部署 |
| 境外服务器 | DaoCloud | 跨境加速 |

#### 镜像源可用性测试

```bash
# 测试镜像源响应速度
curl -I https://docker.rainbond.cc
curl -I https://docker.m.daocloud.io
curl -I https://registry.docker-cn.com

# 验证配置是否生效
docker info | grep -A 10 "Registry Mirrors"
```

---

## 3. GitHub 镜像加速

### 3.1 镜像列表

| 镜像名称 | 地址 | 说明 |
|----------|------|------|
| fastgit | `https://hub.fastgit.xyz/` | 全球 CDN 加速 |
| ghproxy | `https://ghproxy.com/` | 提供代理加速 |
| gitclone | `https://gitclone.com/` | 国内镜像 |
| mirror.ghproxy | `https://ghproxy.cn/` | 代理镜像 |

### 3.2 Git 协议优化

#### 使用 HTTPS 替换 SSH

```bash
# 全局替换 GitHub 协议
git config --global url."https://hub.fastgit.xyz/".insteadOf "https://github.com"
git config --global url."https://hub.fastgit.xyz/".insteadOf "git@github.com:"

# 使用 ghproxy 代理
git config --global url."https://ghproxy.com/".insteadOf "https://github.com"
git config --global url."https://ghproxy.com/".insteadOf "git@github.com:"
```

#### 恢复原始配置

```bash
git config --global --unset url."https://hub.fastgit.xyz/".insteadOf
git config --global --unset url."https://ghproxy.com/".insteadOf
```

### 3.3 SSH 配置优化

编辑 `~/.ssh/config`（Linux/macOS）或 `C:\Users\用户名\.ssh\config`（Windows）：

```
Host github.com
    HostName github.com
    User git
    ProxyCommand connect -H 127.0.0.1:7890 %h %p
    # 或使用 nc（如果已安装）
    # ProxyCommand nc -X 5 -x 127.0.0.1:7890 %h %p
```

#### Windows SSH 配置示例

```
Host github.com
    HostName ssh.github.com
    User git
    Port 443
    ProxyCommand C:\Windows\System32\connect.exe -H 127.0.0.1:7890 %h %p
```

### 3.4 GitHub CLI 加速

```bash
# 设置 GitHub CLI 使用代理
gh config set git_protocol https

# 或使用镜像
export GH_PROXY=https://ghproxy.com
gh repo clone rustdesk/rustdesk
```

---

## 4. Flutter/Dart 镜像

### 4.1 Flutter 社区镜像

| 镜像名称 | 地址 | 说明 |
|----------|------|------|
| Flutter 社区 | `https://flutter-io.cn` | Flutter 中文社区 |
| 上海交通大学 | `https://mirror.sjtu.edu.cn/` | 上海交大镜像 |

### 4.2 配置方法

```bash
# 设置 Flutter 镜像
flutter config --global pub url https://pub.flutter-io.cn

# 设置 Dart 镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### 4.3 pub.dev 镜像

```bash
# 使用 rsproxy pub
export PUB_HOSTED_URL=https://rsproxy.cn
```

---

## 5. 故障排查

### 5.1 Rust/Cargo 问题

#### 问题：Cargo 下载超时

**解决方案：**
1. 检查网络连接
2. 尝试更换镜像源
3. 使用环境变量配置代理

```bash
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
cargo build
```

#### 问题：稀疏索引配置不生效

**解决方案：**
1. 确认 Cargo 版本 >= 1.68
2. 检查配置文件路径
3. 验证配置文件格式

```bash
# 检查 Cargo 版本
cargo --version

# 查看当前配置
cat ~/.cargo/config.toml
```

### 5.2 Docker 问题

#### 问题：镜像拉取失败

**解决方案：**
1. 重启 Docker 服务
2. 检查 daemon.json 配置
3. 清理缓存

```bash
# Linux
sudo systemctl restart docker
sudo docker system prune -a

# Windows
# 重启 Docker Desktop
docker system prune -a
```

#### 问题：配置不生效

**解决方案：**
1. 确认配置文件路径正确
2. 检查 JSON 格式有效性
3. 重启 Docker daemon

```bash
# 验证 JSON 格式
cat /etc/docker/daemon.json | python3 -m json.tool

# 重新加载配置
sudo systemctl reload docker
```

### 5.3 GitHub 问题

#### 问题：Git 克隆失败

**解决方案：**
1. 检查 SSH key 配置
2. 使用 HTTPS 代替 SSH
3. 配置代理

```bash
# 测试 SSH 连接
ssh -T git@github.com

# 使用 HTTPS
git remote set-url origin https://github.com/rustdesk/rustdesk.git
```

### 5.4 通用排查步骤

1. **检查网络连接**
   ```bash
   ping -c 4 github.com
   curl -I https://crates.io
   ```

2. **检查 DNS 解析**
   ```bash
   nslookup rsproxy.cn
   nslookup mirrors.ustc.edu.cn
   ```

3. **测试代理连接**
   ```bash
   curl -v --proxy http://127.0.0.1:7890 https://github.com
   ```

4. **查看详细日志**
   ```bash
   cargo build -vv 2>&1 | tee build.log
   docker pull <image> --debug
   ```

---

## 6. 性能测试

### 6.1 测试脚本

使用项目提供的测速脚本：

```bash
# 运行镜像测速
./tools/mirror/test-mirror-speed.sh

# 输出示例
Rust/Cargo 镜像测速:
- rsproxy:        23ms  ✓ 推荐
- 中科大:         45ms  ✓
- 清华大学:       52ms  ✓
- 阿里云:         18ms  ✓ 最快

Docker 镜像测速:
- 阿里云:         15ms  ✓ 推荐
- 腾讯云:         28ms  ✓
- DaoCloud:      42ms  ✓

GitHub 镜像测速:
- fastgit:       120ms ✓ 推荐
- ghproxy:       89ms  ✓
- gitclone:      150ms ✓
```

### 6.2 手动测速命令

```bash
# Rust/Cargo 镜像测速
time cargo fetch
time rustup update

# Docker 镜像测速
time docker pull rustdesk/rustdesk:latest

# GitHub 克隆测速
time git clone https://github.com/rustdesk/rustdesk.git
```

### 6.3 性能优化建议

1. **优先使用稀疏索引**
   - Cargo 1.68+ 支持，显著提升索引下载速度

2. **使用最近的镜像源**
   - 根据地理位置选择最近的镜像
   - 定期测试并更新配置

3. **配置代理**
   - 对于企业内网，配置代理可以显著提升速度
   - 代理需要支持 HTTPS

4. **缓存优化**
   - Docker 使用本地镜像缓存
   - Cargo 缓存目录保持在本地

---

## 附录 A：完整配置示例

### A.1 完整的 .cargo/config.toml

```toml
[source.crates-io]
replace-with = 'mirror'

[source.mirror]
registry = "sparse+https://rsproxy.cn/index/"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"

[source.tuna]
registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"

[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"

[net]
git-fetch-with-cli = true

[build]
jobs = 4

[term]
verbose = false
```

### A.2 完整的 daemon.json

```json
{
  "registry-mirrors": [
    "https://docker.rainbond.cc",
    "https://docker.m.daocloud.io"
  ],
  "insecure-registries": [],
  "experimental": false,
  "debug": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "features": {
    "buildkit": true
  }
}
```

### A.3 完整的 Git 全局配置

```bash
# ~/.gitconfig

[url "https://hub.fastgit.xyz/"]
    insteadOf = https://github.com
    insteadOf = git@github.com:

[url "https://ghproxy.com/"]
    insteadOf = https://github.com
    insteadOf = git@github.com:

[http]
    postBuffer = 524288000
    timeout = 60

[https]
    postBuffer = 524288000
    timeout = 60

[pull]
    rebase = false

[core]
    autocrlf = input
    compression = 9
```

---

## 附录 B：快速开始

### 一键配置所有镜像（推荐）

```bash
# 下载并运行一键配置脚本
curl -fSL https://raw.githubusercontent.com/rustdesk/rustdesk/master/tools/mirror/auto-mirror.sh -o /tmp/auto-mirror.sh
chmod +x /tmp/auto-mirror.sh
sudo /tmp/auto-mirror.sh --all
```

### 手动逐个配置

1. **配置 Rust/Cargo**
   ```bash
   ./tools/mirror/set-rust-mirror.sh rsproxy
   ```

2. **配置 Docker**
   ```bash
   sudo ./tools/mirror/set-docker-mirror.sh aliyun
   ```

3. **配置 GitHub**
   ```bash
   ./tools/mirror/set-github-mirror.sh fastgit
   ```

4. **测试配置**
   ```bash
   ./tools/mirror/test-mirror-speed.sh
   ```

---

## 相关资源

- [Rust 官方文档](https://doc.rust-lang.org/cargo/)
- [Docker 官方文档](https://docs.docker.com/)
- [GitHub 加速指南](https://ghproxy.com/)
- [中科大开源镜像](https://mirrors.ustc.edu.cn/)
- [清华大学开源镜像](https://mirrors.tuna.tsinghua.edu.cn/)

---

*本文档由 RustDesk 团队维护，最后更新于 2024 年。*
