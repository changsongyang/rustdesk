# RustDesk Windows 平台编译指南

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
| 操作系统 | Windows 10/11 或 Windows Server 2019+ | Windows 11 或 Server 2022 |
| CPU | 4 核 | 8 核或更多 |
| 内存 | 8 GB | 16 GB 或更多 |
| 磁盘空间 | 20 GB | 50 GB 或更多 |
| 架构 | x64 | x64 |

### 1.2 Visual Studio 2022 安装

#### 1.2.1 下载 Visual Studio 2022

访问：https://visualstudio.microsoft.com/downloads/

下载 Community/Professional/Enterprise 版本。

#### 1.2.2 选择工作负载

安装时选择以下工作负载：

- **使用 C++ 的桌面开发**（必需）
- **Windows 11 SDK**（必需）
- **Windows 10 SDK**（可选）

#### 1.2.3 单独组件

在 "单个组件" 选项卡中额外选择：

- **MSVC v143 - VS 2022 C++ x64/x86 生成工具**
- **C++ ATL 用于最新 v143 生成工具 (x86 & x64)**
- **Windows 11 SDK (10.0.22621.0)**

### 1.3 Rust 安装

#### 1.3.1 下载安装器

访问：https://rustup.rs/

或使用 PowerShell：

```powershell
irm https://rustup.rs -OutFile rustup-init.exe
.\rustup-init.exe
```

#### 1.3.2 配置 Rust

```powershell
# 添加 MSVC 目标平台
rustup target add x86_64-pc-windows-msvc

# 可选：添加 32 位支持
rustup target add i686-pc-windows-msvc

# 可选：添加 ARM64 支持
rustup target add aarch64-pc-windows-msvc

# 设置默认工具链
rustup default stable

# 验证安装
rustc --version
cargo --version
```

### 1.4 vcpkg 安装和配置

#### 1.4.1 克隆 vcpkg

```powershell
# 在合适的位置克隆（推荐 C:\vcpkg）
git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
cd C:\vcpkg

# 运行引导脚本
.\bootstrap-vcpkg.bat
```

#### 1.4.2 配置环境变量

```powershell
# 永久设置环境变量
[Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")
[Environment]::SetEnvironmentVariable("VCPKG_DEFAULT_TRIPLET", "x64-windows", "User")

# 将 vcpkg 添加到 PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = "$currentPath;C:\vcpkg"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# 刷新当前会话
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

#### 1.4.3 安装必需依赖

```powershell
cd C:\vcpkg

# 安装 FFmpeg 和相关库
.\vcpkg install ffmpeg:x64-windows `
    libvpx:x64-windows `
    opus:x64-windows `
    libsodium:x64-windows

# 安装其他依赖
.\vcpkg install `
    libxcb:x64-windows `
    libxkbcommon:x64-windows `
    mesa:x64-windows `
    alsa:x64-windows `
    pulseaudio:x64-windows
```

#### 1.4.4 集成到 Visual Studio

```powershell
cd C:\vcpkg
.\vcpkg integrate install
```

### 1.5 Git for Windows

#### 1.5.1 下载安装

访问：https://git-scm.com/download/win

或使用 winget：

```powershell
winget install Git.Git
```

#### 1.5.2 配置 Git

```powershell
git config --global core.autocrlf false
git config --global core.longpaths true
git config --global core.eol lf
```

### 1.6 CMake

#### 1.6.1 下载安装

访问：https://cmake.org/download/

选择 Windows x64 Installer。

#### 1.6.2 添加到 PATH

```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    "$env:Path;C:\Program Files\CMake\bin",
    "User"
)

# 刷新当前会话
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

### 1.7 NASM

某些视频编码需要 NASM。

#### 1.7.1 下载安装

访问：https://www.nasm.us/

#### 1.7.2 配置

```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    "$env:Path;C:\Program Files\NASM",
    "User"
)
```

### 1.8 自动化安装脚本

创建 `install-deps.ps1`：

```powershell
#Requires -RunAsAdministrator
param(
    [switch]$SkipVS,
    [switch]$SkipRust
)

Write-Host "=== RustDesk Windows 编译环境安装 ===" -ForegroundColor Green

# 1. 安装 Chocolatey
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "安装 Chocolatey..." -ForegroundColor Yellow
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# 2. 安装基础工具
Write-Host "安装基础工具..." -ForegroundColor Yellow
choco install -y git cmake ninja

# 3. 安装 Rust
if (-not $SkipRust -and -not (Get-Command rustup -ErrorAction SilentlyContinue)) {
    Write-Host "安装 Rust..." -ForegroundColor Yellow
    choco install -y rustup
    rustup target add x86_64-pc-windows-msvc
}

# 4. 安装 Visual Studio Build Tools（如果未安装）
if (-not $SkipVS) {
    Write-Host "安装 Visual Studio Build Tools..." -ForegroundColor Yellow
    
    # 下载 Visual Studio Build Tools
    $vs_installer = "$env:TEMP\vs_buildtools.exe"
    Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $vs_installer
    
    # 安装必需组件
    Start-Process -Wait -FilePath $vs_installer -ArgumentList "--quiet", "--wait", "--norestart", "--nocache",
        "--add", "Microsoft.VisualStudio.Workload.VCTools",
        "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "--add", "Microsoft.VisualStudio.Component.Windows11SDK.22621",
        "--add", "Microsoft.VisualStudio.Component.Debugger.Core"
    
    Remove-Item $vs_installer -Force
}

# 5. 克隆并配置 vcpkg
if (-not (Test-Path C:\vcpkg)) {
    Write-Host "克隆 vcpkg..." -ForegroundColor Yellow
    git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
    cd C:\vcpkg
    .\bootstrap-vcpkg.bat
}

# 6. 设置环境变量
[Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")
[Environment]::SetEnvironmentVariable("VCPKG_DEFAULT_TRIPLET", "x64-windows", "User")

# 7. 安装 vcpkg 依赖
Write-Host "安装 vcpkg 依赖..." -ForegroundColor Yellow
cd C:\vcpkg
.\vcpkg install ffmpeg:x64-windows libvpx:x64-windows opus:x64-windows libsodium:x64-windows

# 8. 集成 vcpkg 到 Visual Studio
cd C:\vcpkg
.\vcpkg integrate install

Write-Host ""
Write-Host "=== 安装完成 ===" -ForegroundColor Green
Write-Host "请重启终端以使所有环境变量生效" -ForegroundColor Yellow
```

---

## 2. 源码获取

### 2.1 克隆仓库

```powershell
# 创建工作目录
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\rustdesk-build"
cd "$env:USERPROFILE\rustdesk-build"

# 克隆主仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 初始化子模块
git submodule update --init --recursive
```

### 2.2 选择版本

```powershell
# 查看可用标签
git tag

# 切换到最新稳定版本（以 v1.2.0 为例）
git checkout v1.2.0
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

#### 3.1.1 设置 vcpkg 环境

```powershell
# 如果没有永久设置，手动设置
$env:VCPKG_ROOT = "C:\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
```

#### 3.1.2 设置 Rust 编译选项

```powershell
# 启用 LTO 和单 codegen 单位以优化性能
$env:RUSTFLAGS = "-C lto=fat -C codegen-units=1"

# 可选：设置优化级别
$env:RUSTFLAGS = "-C opt-level=3"

# 可选：设置目标 CPU
$env:RUSTFLAGS = "-C target-cpu=x86-64-v3"
```

#### 3.1.3 永久配置（可选）

创建 PowerShell 配置文件：

```powershell
# 编辑 PowerShell 配置文件
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE
}

Add-Content $PROFILE @"

# RustDesk 编译环境
`$env:VCPKG_ROOT = "C:\vcpkg"
`$env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
`$env:RUSTFLAGS = "-C lto=fat -C codegen-units=1"
"@

# 重新加载配置
. $PROFILE
```

### 3.2 使用 Visual Studio Developer Command Prompt

推荐使用 Visual Studio Developer Command Prompt，它会自动配置 MSVC 环境。

#### 3.2.1 打开 Developer Command Prompt

方法 1：开始菜单
- 搜索 "Developer Command Prompt for VS 2022"
- 右键选择 "以管理员身份运行"

方法 2：快捷方式
```
C:\Program Files\Microsoft Visual Studio\2022\<Edition>\Common7\Tools\Launch-VsDevShell.ps1
```

方法 3：通过 PowerShell
```powershell
# 加载 Visual Studio 环境
$msvcPath = "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build"
Import-Module "$msvcPath\Microsoft.VisualStudio.DevEnv.dll"
vsdevcmd.bat -arch=x64
```

### 3.3 纯 Rust 编译（仅服务端）

如果你只需要编译服务端（hbbs 和 hbrs），无需 Flutter：

```powershell
# 进入项目目录
cd rustdesk

# 编译 Release 版本
cargo build --release

# 或编译 Debug 版本（更快但性能较差）
cargo build

# 编译后的二进制文件位于：
# target\release\hbbs.exe   - RustDesk ID/HBBS 服务器
# target\release\hbrs.exe   - RustDesk 中继服务器
```

### 3.4 完整编译（包括 Flutter UI）

```powershell
# 1. 编译 Rust 服务端
cargo build --release

# 2. 安装 Flutter 依赖
cd flutter

# 确保启用了 Windows 桌面支持
flutter config --enable-windows-desktop

# 获取依赖
flutter pub get

# 3. 编译 Windows 版本
flutter build windows --release

# 编译产物位于：
# flutter\build\windows\runner\Release\
```

### 3.5 指定目标架构

**x86_64 (默认)**:

```powershell
cargo build --release --target x86_64-pc-windows-msvc
```

**x86 (32 位)**:

```powershell
# 先添加目标平台
rustup target add i686-pc-windows-msvc

# 编译
cargo build --release --target i686-pc-windows-msvc
```

**ARM64**:

```powershell
# 先添加目标平台
rustup target add aarch64-pc-windows-msvc

# 编译
cargo build --release --target aarch64-pc-windows-msvc
```

### 3.6 编译选项

**最小化编译（减少二进制大小）**:

```powershell
# 设置剥离符号和优化
$env:RUSTFLAGS = "-C strip=symbols -C lto=fat -C codegen-units=1"

cargo build --release
```

**调试编译**:

```powershell
cargo build

# 调试符号位于：
# target\debug\hbbs.pdb
# target\debug\hbrs.pdb
```

### 3.7 编译脚本

创建 `build-server.ps1`：

```powershell
param(
    [ValidateSet("release", "debug")]
    [string]$BuildType = "release"
)

Write-Host "=== RustDesk 服务端编译脚本 ===" -ForegroundColor Green

# 设置变量
$BuildDir = "$env:USERPROFILE\rustdesk-build"
$ProjectDir = "$BuildDir\rustdesk"

# 检查 Rust
if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    Write-Host "错误: Rust 未安装，请先安装 Rust" -ForegroundColor Red
    exit 1
}

# 进入项目目录
Set-Location $ProjectDir

# 设置编译选项
$env:RUSTFLAGS = "-C lto=fat -C codegen-units=1 -C opt-level=3"

# 清理旧构建（可选）
if ($args -contains "clean") {
    Write-Host "清理构建目录..." -ForegroundColor Yellow
    cargo clean
}

# 编译
Write-Host "开始编译 RustDesk 服务端 ($BuildType)..." -ForegroundColor Yellow
if ($BuildType -eq "release") {
    cargo build --release
} else {
    cargo build
}

# 复制二进制文件
$OutputDir = "$BuildDir\output"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if ($BuildType -eq "release") {
    Copy-Item "target\release\hbbs.exe" -Destination $OutputDir
    Copy-Item "target\release\hbrs.exe" -Destination $OutputDir
} else {
    Copy-Item "target\debug\hbbs.exe" -Destination $OutputDir
    Copy-Item "target\debug\hbrs.exe" -Destination $OutputDir
}

Write-Host ""
Write-Host "编译完成！" -ForegroundColor Green
Write-Host "二进制文件位于: $OutputDir" -ForegroundColor Green
Get-ChildItem $OutputDir | Format-Table Name, Length -AutoSize
```

使用方式：

```powershell
# Release 编译
.\build-server.ps1 release

# Debug 编译
.\build-server.ps1 debug

# 清理并重新编译
.\build-server.ps1 release clean
```

---

## 4. 服务配置

### 4.1 创建服务用户

#### 4.1.1 使用本地用户和组

```powershell
# 以管理员身份运行 PowerShell

# 创建专用用户
$password = ConvertTo-SecureString "YourStrongPassword123!" -AsPlainText -Force
New-LocalUser -Name "rustdesk" -Password $password -Description "RustDesk Service Account" -PasswordNeverExpires

# 将用户添加到 Administrators 组（可选，视需求而定）
Add-LocalGroupMember -Group "Administrators" -Member "rustdesk"
```

#### 4.1.2 创建数据目录

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\rustdesk\hbbs"
New-Item -ItemType Directory -Force -Path "C:\ProgramData\rustdesk\hbrs"

# 设置权限（可选）
# icacls "C:\ProgramData\rustdesk" /grant "rustdesk:(OI)(CI)F"
```

### 4.2 部署二进制文件

```powershell
# 创建部署目录
New-Item -ItemType Directory -Force -Path "C:\Program Files\RustDesk"

# 复制二进制文件
Copy-Item "$env:USERPROFILE\rustdesk-build\output\hbbs.exe" "C:\Program Files\RustDesk\"
Copy-Item "$env:USERPROFILE\rustdesk-build\output\hbrs.exe" "C:\Program Files\RustDesk\"

# 设置权限
icacls "C:\Program Files\RustDesk" /grant "rustdesk:RX"
icacls "C:\Program Files\RustDesk\hbbs.exe" /grant "rustdesk:RX"
icacls "C:\Program Files\RustDesk\hbrs.exe" /grant "rustdesk:RX"
```

### 4.3 使用 NSSM 创建服务

#### 4.3.1 下载 NSSM

NSSM（非阻塞服务管理器）是一个实用的工具，可以将任何可执行文件包装为 Windows 服务。

下载地址：https://nssm.cc/download

或使用 Chocolatey：

```powershell
choco install nssm
```

#### 4.3.2 创建 HBBS 服务

```powershell
# 以管理员身份运行

# 创建服务
nssm install rustdesk-hbbs "C:\Program Files\RustDesk\hbbs.exe"

# 设置工作目录
nssm set rustdesk-hbbs AppDirectory "C:\ProgramData\rustdesk\hbbs"

# 设置日志文件
nssm set rustdesk-hbbs AppStdout "C:\ProgramData\rustdesk\hbbs\logs\hbbs.log"
nssm set rustdesk-hbbs AppStderr "C:\ProgramData\rustdesk\hbbs\logs\hbbs-error.log"

# 自动重启
nssm set rustdesk-hbbs AppRestartDelay 5000

# 启动类型
nssm set rustdesk-hbbs Start SERVICE_AUTO_START

# 创建日志目录
New-Item -ItemType Directory -Force -Path "C:\ProgramData\rustdesk\hbbs\logs"
```

#### 4.3.3 创建 HBRS 服务

```powershell
# 以管理员身份运行

# 创建服务
nssm install rustdesk-hbrs "C:\Program Files\RustDesk\hbrs.exe"

# 设置工作目录
nssm set rustdesk-hbrs AppDirectory "C:\ProgramData\rustdesk\hbrs"

# 设置日志文件
nssm set rustdesk-hbrs AppStdout "C:\ProgramData\rustdesk\hbrs\logs\hbrs.log"
nssm set rustdesk-hbrs AppStderr "C:\ProgramData\rustdesk\hbrs\logs\hbrs-error.log"

# 自动重启
nssm set rustdesk-hbrs AppRestartDelay 5000

# 启动类型
nssm set rustdesk-hbrs Start SERVICE_AUTO_START

# 创建日志目录
New-Item -ItemType Directory -Force -Path "C:\ProgramData\rustdesk\hbrs\logs"
```

#### 4.3.4 使用 Windows Service Wrapper (alternatives)

另一种方法是使用 winsw：

下载地址：https://github.com/wincraco/winsw/releases

创建 `hbbs.xml`：

```xml
<service>
  <id>rustdesk-hbbs</id>
  <name>RustDesk HBBS Server</name>
  <description>RustDesk ID/HBBS Server</description>
  <executable>C:\Program Files\RustDesk\hbbs.exe</executable>
  <workingdirectory>C:\ProgramData\rustdesk\hbbs</workingdirectory>
  <logpath>C:\ProgramData\rustdesk\hbbs\logs</logpath>
  <logmode>rotate</logmode>
  <autoRestart>true</autoRestart>
  <startmode>Automatic</startmode>
</service>
```

注册服务：

```powershell
.\winsw.exe install rustdesk-hbbs.xml
.\winsw.exe start rustdesk-hbbs
```

### 4.4 服务管理命令

```powershell
# 启动服务
Start-Service rustdesk-hbbs
Start-Service rustdesk-hbrs

# 停止服务
Stop-Service rustdesk-hbbs
Stop-Service rustdesk-hbrs

# 重启服务
Restart-Service rustdesk-hbbs
Restart-Service rustdesk-hbrs

# 查看服务状态
Get-Service rustdesk-hbbs
Get-Service rustdesk-hbrs

# 查看详细状态
Get-Service rustdesk-hbbs | Format-List *

# 设置开机自启
Set-Service -Name rustdesk-hbbs -StartupType Automatic
Set-Service -Name rustdesk-hbrs -StartupType Automatic
```

### 4.5 HBBS/HBRS 配置

#### 4.5.1 命令行参数

```powershell
# 查看帮助
.\hbbs.exe --help
.\hbrs.exe --help
```

常用参数：
- `-k <file>` - 私钥文件路径（用于加密通信）
- `-r <addr>` - 中继服务器地址
- `-l <port>` - 监听端口
- `--help` - 显示帮助信息

#### 4.5.2 日志配置

使用 NSSM 时，日志文件位置已在创建服务时设置。

默认日志位置：
- HBBS: `C:\ProgramData\rustdesk\hbbs\logs\`
- HBRS: `C:\ProgramData\rustdesk\hbrs\logs\`

---

## 5. 防火墙配置

### 5.1 必需端口

| 端口 | 协议 | 用途 | 服务 |
|------|------|------|------|
| 21115 | TCP | ID/HBBS 服务 | hbbs |
| 21116 | TCP/UDP | 中继连接 | hbrs |
| 21117 | TCP | RUDP 中继 | hbrs |
| 21118 | TCP | 测试端口 | - |
| 21119 | TCP | WebSocket | hbbs |

### 5.2 使用 Windows Defender 防火墙

#### 5.2.1 PowerShell 方式

```powershell
# 以管理员身份运行

# 允许入站连接
New-NetFirewallRule -DisplayName "RustDesk HBBS (21115)" -Direction Inbound -Protocol TCP -LocalPort 21115 -Action Allow
New-NetFirewallRule -DisplayName "RustDesk HBRS TCP (21116)" -Direction Inbound -Protocol TCP -LocalPort 21116 -Action Allow
New-NetFirewallRule -DisplayName "RustDesk HBRS UDP (21116)" -Direction Inbound -Protocol UDP -LocalPort 21116 -Action Allow
New-NetFirewallRule -DisplayName "RustDesk HBRS RUDP (21117)" -Direction Inbound -Protocol TCP -LocalPort 21117 -Action Allow
New-NetFirewallRule -DisplayName "RustDesk Test (21118)" -Direction Inbound -Protocol TCP -LocalPort 21118 -Action Allow
New-NetFirewallRule -DisplayName "RustDesk WebSocket (21119)" -Direction Inbound -Protocol TCP -LocalPort 21119 -Action Allow

# 允许出站连接（通常默认允许）
New-NetFirewallRule -DisplayName "RustDesk HBBS Out" -Direction Outbound -Protocol TCP -LocalPort 21115 -Action Allow
New-NetFirewallRule -DisplayName "RustDesk HBRS Out" -Direction Outbound -Protocol TCP -LocalPort 21116,21117 -Action Allow
```

#### 5.2.2 图形界面方式

1. 打开 "Windows Defender 防火墙"
2. 点击 "高级设置"
3. 选择 "入站规则" -> "新建规则"
4. 选择 "端口" -> "TCP" -> 输入 "21115-21119"
5. 允许连接 -> 勾选所有配置文件
6. 命名规则并完成

### 5.3 使用 netsh（备用）

```powershell
# 以管理员身份运行

# 开放端口
netsh advfirewall firewall add rule name="RustDesk HBBS" dir=in action=allow protocol=TCP localport=21115
netsh advfirewall firewall add rule name="RustDesk HBRS TCP" dir=in action=allow protocol=TCP localport=21116
netsh advfirewall firewall add rule name="RustDesk HBRS UDP" dir=in action=allow protocol=UDP localport=21116
netsh advfirewall firewall add rule name="RustDesk HBRS RUDP" dir=in action=allow protocol=TCP localport=21117
netsh advfirewall firewall add rule name="RustDesk Test" dir=in action=allow protocol=TCP localport=21118
netsh advfirewall firewall add rule name="RustDesk WebSocket" dir=in action=allow protocol=TCP localport=21119

# 查看规则
netsh advfirewall firewall show rule name="RustDesk HBBS"
```

### 5.4 云服务器特殊配置

**阿里云/腾讯云**:

1. 登录云服务器控制台
2. 找到 "安全组" 或 "防火墙"
3. 添加入站规则，开放 21115-21119 端口的 TCP/UDP 流量

**AWS EC2**:

1. 打开 EC2 控制台
2. 选择你的实例 -> 点击 "安全" 选项卡
3. 点击安全组链接
4. 编辑入站规则，添加：
   - 类型：自定义 TCP
   - 端口：21115-21119
   - 来源：0.0.0.0/0

```powershell
# AWS CLI 方式
aws ec2 authorize-security-group-ingress \
    --group-id <security-group-id> \
    --ip-permissions IpProtocol=tcp,FromPort=21115,ToPort=21119,IpRanges=[{CidrIp=0.0.0.0/0}]
```

### 5.5 验证防火墙配置

```powershell
# 检查端口是否开放
netstat -an | findstr "21115"
netstat -an | findstr "21116"
netstat -an | findstr "21117"

# 测试端口监听
Test-NetConnection -ComputerName localhost -Port 21115
Test-NetConnection -ComputerName localhost -Port 21116

# 检查防火墙规则
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*RustDesk*" } | Format-Table DisplayName, Enabled, Direction
```

---

## 6. 性能优化

### 6.1 编译优化

**启用 LTO（链接时优化）**:

```powershell
$env:RUSTFLAGS = "-C lto=fat -C codegen-units=1"
cargo build --release
```

**目标 CPU 优化**:

```powershell
# SSE4.2 + POPCNT（大多数现代 CPU）
$env:RUSTFLAGS = "-C target-cpu=haswell"

# 或使用 x86-64-v3（支持 AVX2）
$env:RUSTFLAGS = "-C target-cpu=x86-64-v3"

cargo build --release
```

### 6.2 服务优化

#### 6.2.1 调整进程优先级

```powershell
# 设置为高优先级
(Get-WmiObject Win32_Service -Filter "Name='rustdesk-hbbs'").Change(, , , , , "High", , , )

# 或使用任务管理器手动调整
```

#### 6.2.2 内存限制

使用 NSSM 设置内存限制：

```powershell
nssm set rustdesk-hbbs AppMemory 2GB
nssm set rustdesk-hbrs AppMemory 2GB
```

#### 6.2.3 CPU 亲和性

```powershell
# 限制服务只使用特定 CPU 核心（以管理员身份）
Set-ProcessAffinityMask -Name hbbs.exe -AffinityMask 0x03  # 使用前两个核心
```

### 6.3 Windows 性能优化

#### 6.3.1 电源设置

确保服务器使用高性能电源计划：

```powershell
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
```

#### 6.3.2 调整注册表（可选）

```powershell
# 增加网络缓冲区
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpTimedWaitDelay" -Value 30 -Type DWord
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxUserPort" -Value 65534 -Type DWord
```

### 6.4 日志优化

#### 6.4.1 限制日志文件大小

使用 NSSM 配置日志轮换：

```powershell
nssm set rustdesk-hbbs AppRotateFiles 1
nssm set rustdesk-hbbs AppRotateSeconds 86400
nssm set rustdesk-hbbs AppRotateBytes 10485760
```

#### 6.4.2 定期清理日志

创建定时任务：

```powershell
# 创建清理脚本 cleanup-logs.ps1
$LogDirs = @("C:\ProgramData\rustdesk\hbbs\logs", "C:\ProgramData\rustdesk\hbrs\logs")
$DaysToKeep = 7

foreach ($Dir in $LogDirs) {
    if (Test-Path $Dir) {
        Get-ChildItem -Path $Dir -Filter "*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$DaysToKeep) } | Remove-Item
    }
}

# 添加到任务计划程序
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\Scripts\cleanup-logs.ps1"
$Trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
Register-ScheduledTask -TaskName "Cleanup-RustDesk-Logs" -Action $Action -Trigger $Trigger -RunLevel Highest
```

---

## 7. 故障排除

### 7.1 编译错误

**错误 1**: `LINK : fatal error LNK1181: cannot open input file`

```powershell
# 确保 vcpkg 已安装依赖
cd C:\vcpkg
.\vcpkg install ffmpeg:x64-windows libvpx:x64-windows opus:x64-windows

# 集成到 Visual Studio
.\vcpkg integrate install

# 清理并重新编译
cargo clean
cargo build --release
```

**错误 2**: `error: unable to find native library`

```powershell
# 设置 vcpkg 环境变量
$env:VCPKG_ROOT = "C:\vcpkg"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows"

# 清理并重新编译
cargo clean
cargo build --release
```

**错误 3**: `error: MSB8020: The build tools for v143 cannot be found`

```powershell
# 修复 Visual Studio
# 打开 Visual Studio Installer
# 修改 -> 工作负载 -> 确保 "使用 C++ 的桌面开发" 已选中
# 重新启动 Developer Command Prompt
```

**错误 4**: 内存不足

```powershell
# 减少并行编译数
$env:CARGO_BUILD_JOBS = "2"

# 或在 Cargo.toml 中设置
[profile.release]
jobs = 2
```

### 7.2 服务启动失败

**检查日志**:

```powershell
# 使用 NSSM 查看日志
notepad C:\ProgramData\rustdesk\hbbs\logs\hbbs.log
notepad C:\ProgramData\rustdesk\hbrs\logs\hbrs.log

# 使用事件查看器
eventvwr.msc
# 应用程序日志中查看 rustdesk 相关错误
```

**常见问题**:

1. **端口被占用**:
   ```powershell
   # 检查端口占用
   netstat -ano | findstr "21115"
   
   # 停止占用进程或更改端口
   ```

2. **权限不足**:
   ```powershell
   # 检查文件权限
   icacls "C:\Program Files\RustDesk\*"
   
   # 授予完全控制权限
   icacls "C:\Program Files\RustDesk" /grant "rustdesk:F"
   icacls "C:\ProgramData\rustdesk" /grant "rustdesk:F"
   ```

3. **依赖缺失**:
   ```powershell
   # 检查 VC++ 运行时
   # 下载并安装 VC++ Redistributable
   # https://aka.ms/vs/17/release/vc_redist.x64.exe
   ```

### 7.3 连接问题

**防火墙阻止**:

```powershell
# 临时关闭防火墙测试
Set-NetFirewallProfile -Profile Domain,Public -Enabled False

# 测试后重新启用
Set-NetFirewallProfile -Profile Domain,Public -Enabled True
```

**端口未监听**:

```powershell
# 检查服务是否运行
Get-Service rustdesk-hbbs
Get-Service rustdesk-hbrs

# 手动启动服务
Start-Service rustdesk-hbbs
Start-Service rustdesk-hbrs

# 检查端口
netstat -ano | findstr "21115"
```

### 7.4 性能问题

**CPU 使用率过高**:

```powershell
# 查看进程
Get-Process | Where-Object { $_.Name -like "*hbbs*" -or $_.Name -like "*hbrs*" }

# 限制 CPU 使用
# 使用 NSSM
nssm set rustdesk-hbbs AppPriority HIGH
```

**内存泄漏**:

```powershell
# 检查内存使用
Get-Process | Where-Object { $_.Name -like "*hbbs*" -or $_.Name -like "*hbrs*" } | Select-Object Name, @{N='Memory(MB)';E={[math]::Round($_.WS/1MB,2)}}

# 重启服务
Restart-Service rustdesk-hbbs
Restart-Service rustdesk-hbrs
```

---

## 8. 验证部署

### 8.1 本地验证

```powershell
# 检查服务状态
Get-Service rustdesk-hbbs
Get-Service rustdesk-hbrs

# 检查端口监听
netstat -ano | Select-String "21115|21116|21117|21118|21119"

# 检查进程
Get-Process | Where-Object { $_.Name -like "*hbbs*" -or $_.Name -like "*hbrs*" }
```

### 8.2 功能测试

```powershell
# 测试 HBBS 连接
Test-NetConnection -ComputerName localhost -Port 21115

# 测试 HBRS 连接
Test-NetConnection -ComputerName localhost -Port 21116
Test-NetConnection -ComputerName localhost -Port 21117

# 查看日志
Get-Content "C:\ProgramData\rustdesk\hbbs\logs\hbbs.log" -Tail 50 -Wait
Get-Content "C:\ProgramData\rustdesk\hbrs\logs\hbrs.log" -Tail 50 -Wait
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

创建监控脚本 `check-rustdesk.ps1`：

```powershell
# 检查服务状态
$hbbsStatus = Get-Service -Name rustdesk-hbbs -ErrorAction SilentlyContinue
$hbrsStatus = Get-Service -Name rustdesk-hbrs -ErrorAction SilentlyContinue

if ($hbbsStatus.Status -ne "Running") {
    Write-Host "ERROR: rustdesk-hbbs is not running"
    exit 1
}

if ($hbrsStatus.Status -ne "Running") {
    Write-Host "ERROR: rustdesk-hbrs is not running"
    exit 1
}

Write-Host "OK: All RustDesk services are running"
exit 0
```

添加到任务计划程序：

```powershell
# 创建任务
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\check-rustdesk.ps1"
$Trigger = New-ScheduledTaskTrigger -Once -RepetitionInterval (New-TimeSpan -Minutes 5) -At (Get-Date)
$Settings = New-ScheduledTaskSettingsSet -RunBetween (New-TimeSpan -Hours 0) (New-TimeSpan -Hours 23)

Register-ScheduledTask -TaskName "RustDesk-Monitor" -Action $Action -Trigger $Trigger -Settings $Settings -RunLevel Highest
```

---

## 相关文档

- [BUILD_PREREQUISITES.md](BUILD_PREREQUISITES.md) - 编译依赖清单
- [BUILD_LINUX.md](BUILD_LINUX.md) - Linux 编译指南
- [BUILD_MACOS.md](BUILD_MACOS.md) - macOS 编译指南
- [BUILD_CROSS_COMPILE.md](BUILD_CROSS_COMPILE.md) - 交叉编译指南
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署总览
