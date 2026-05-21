# RustDesk 自动安装脚本
# 用于快速部署 RustDesk 服务器
# Author: RustDesk Team
# Version: 1.0.0

param(
    [switch]$Silent,
    [switch]$Force,
    [switch]$SkipDependencies,
    [ValidateSet("docker", "kubernetes", "source")]
    [string]$Mode = "docker"
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ParentDir = Split-Path -Parent $ScriptDir
$CommonDir = Join-Path $ParentDir "common"

if (Test-Path (Join-Path $CommonDir "config.env")) {
    Get-Content (Join-Path $CommonDir "config.env") | ForEach-Object {
        if ($_ -match "^(.+)=(.+)$") {
            Set-Content -Path "env:$($matches[1])" -Value $matches[2] -ErrorAction SilentlyContinue
        }
    }
}

$ProjectHome = $env:PROJECT_HOME ?: "C:\Program Files\RustDesk"
$DataDir = $env:DATA_DIR ?: "$ProjectHome\data"
$LogDir = $env:LOG_DIR ?: "$ProjectHome\logs"
$ConfigDir = $env:CONFIG_DIR ?: "$ProjectHome\config"
$BackupDir = $env:BACKUP_DIR ?: "$ProjectHome\backups"

$HbbsPort = [int]($env:HBBDS_PORT ?: 21115)
$HbbsTlsPort = [int]($env:HBBDS_TLS_PORT ?: 21116)
$RelayPort = [int]($env:RELAY_PORT ?: 21117)
$NatTypeTestPort = [int]($env:NAT_TYPE_TEST_PORT ?: 21118)
$StatusPort = [int]($env:STATUS_PORT ?: 21119)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Test-Administrator {
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Docker {
    Write-Info "检查 Docker..."

    try {
        $DockerVersion = docker --version 2>&1
        if ($LASTEXITCODE -eq 0 -and -not $Force) {
            Write-Success "Docker 已安装: $DockerVersion"
            return
        }
    } catch {
        Write-Info "Docker 未安装，开始安装..."
    }

    if ($Force) {
        Write-Warn "Docker 已安装，强制重新安装..."
    }

    Write-Info "安装 Docker Desktop..."

    $DockerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
    $InstallerPath = "$env:TEMP\DockerDesktopInstaller.exe"

    if (-not (Test-Path $InstallerPath)) {
        Write-Info "下载 Docker Desktop 安装程序..."
        try {
            Invoke-WebRequest -Uri $DockerUrl -OutFile $InstallerPath -UseBasicParsing
        } catch {
            Write-Error "下载 Docker Desktop 失败: $_"
        }
    }

    Write-Info "运行 Docker Desktop 安装程序..."
    Start-Process -FilePath $InstallerPath -ArgumentList "install --quiet" -Wait

    Write-Info "等待 Docker Desktop 启动..."
    Start-Sleep -Seconds 30

    $MaxAttempts = 12
    $Attempt = 0
    while ($Attempt -lt $MaxAttempts) {
        try {
            docker info 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Docker 安装成功"
                return
            }
        } catch {
        }
        Write-Info "等待 Docker Desktop 启动... ($($Attempt + 1)/$MaxAttempts)"
        Start-Sleep -Seconds 10
        $Attempt++
    }

    Write-Warn "Docker 启动可能需要手动确认，请检查 Docker Desktop 窗口"
}

function Install-DockerCompose {
    Write-Info "检查 Docker Compose..."

    try {
        $ComposeVersion = docker compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose 已安装: $ComposeVersion"
            return
        }
    } catch {
        Write-Info "Docker Compose 未安装"
    }

    Write-Info "Docker Compose v2 已内置于 Docker Desktop，无需单独安装"
}

function Install-WSL {
    Write-Info "检查 WSL..."

    $WSL = Get-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -ErrorAction SilentlyContinue

    if ($WSL -and $WSL.State -eq "Enabled") {
        Write-Success "WSL 已启用"
        return
    }

    Write-Info "启用 WSL..."
    try {
        wsl --install --no-distribution 2>&1 | Out-Null
        Write-Success "WSL 启用成功，需要重启系统"
    } catch {
        Write-Warn "WSL 启用失败，请手动启用"
    }
}

function Install-HyperV {
    Write-Info "检查 Hyper-V..."

    $HyperV = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -ErrorAction SilentlyContinue

    if ($HyperV -and $HyperV.State -eq "Enabled") {
        Write-Success "Hyper-V 已启用"
        return
    }

    Write-Info "启用 Hyper-V..."
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart -WarningAction SilentlyContinue | Out-Null
        Write-Success "Hyper-V 启用成功，需要重启系统"
    } catch {
        Write-Warn "Hyper-V 启用失败，请手动启用或使用 Docker Desktop WSL2 后端"
    }
}

function Install-Dependencies {
    if ($SkipDependencies) {
        Write-Info "跳过依赖检查"
        return
    }

    Write-Info "检查系统依赖..."

    $RequiredDeps = @{
        "git" = "Git"
        "curl" = "curl"
        "wget" = "wget"
    }

    foreach ($Dep in $RequiredDeps.Keys) {
        $Command = Get-Command $Dep -ErrorAction SilentlyContinue
        if (-not $Command) {
            Write-Warn "$($RequiredDeps[$Dep]) 未安装"
        }
    }
}

function New-Directories {
    Write-Info "创建目录结构..."

    $Dirs = @($ProjectHome, $DataDir, $LogDir, $ConfigDir, $BackupDir)

    foreach ($Dir in $Dirs) {
        if (-not (Test-Path $Dir)) {
            New-Item -Path $Dir -ItemType Directory -Force | Out-Null
            Write "  创建: $Dir"
        }
    }

    Write-Success "目录创建完成"
}

function New-DockerComposeFile {
    Write-Info "生成 Docker Compose 配置..."

    $ComposeContent = @"
version: '3.8'

services:
  hbbs:
    container_name: rustdesk-hbbs
    image: rustdesk/rustdesk-server:latest
    command: hbbs -k _
    ports:
      - "${HbbsPort}:${HbbsPort}"
      - "${HbbsTlsPort}:${HbbsTlsPort}"
      - "${NatTypeTestPort}:${NatTypeTestPort}"
    volumes:
      - ./data:/data
    environment:
      - RUST_LOG=info
    restart: unless-stopped
    network_mode: host

  hbbr:
    container_name: rustdesk-hbbr
    image: rustdesk/rustdesk-server:latest
    command: hbbr -k _
    ports:
      - "${RelayPort}:${RelayPort}"
    volumes:
      - ./data:/data
    environment:
      - RUST_LOG=info
    restart: unless-stopped
    network_mode: host
    depends_on:
      - hbbs

networks: {}
"@

    $ComposePath = Join-Path $ProjectHome "docker-compose.yml"
    Set-Content -Path $ComposePath -Value $ComposeContent -Force

    Write-Success "Docker Compose 配置已生成"
}

function New-EnvFile {
    Write-Info "生成环境配置文件..."

    $EnvContent = @"
PROJECT_HOME=$ProjectHome
DATA_DIR=$DataDir
LOG_DIR=$LogDir
CONFIG_DIR=$ConfigDir
BACKUP_DIR=$BackupDir

HBBDS_PORT=$HbbsPort
HBBDS_TLS_PORT=$HbbsTlsPort
RELAY_PORT=$RelayPort
NAT_TYPE_TEST_PORT=$NatTypeTestPort
STATUS_PORT=$StatusPort

DOCKER_IMAGE=rustdesk/rustdesk-server
ENABLE_TLS=true
LOG_LEVEL=info
"@

    $EnvPath = Join-Path $ConfigDir ".env"
    Set-Content -Path $EnvPath -Value $EnvContent -Force

    Write-Success "环境配置文件已生成"
}

function Start-Services {
    Write-Info "启动 RustDesk 服务..."

    Set-Location $ProjectHome

    try {
        docker compose up -d
        if ($LASTEXITCODE -eq 0) {
            Write-Info "等待服务启动..."
            Start-Sleep -Seconds 10
            Test-ServiceStatus
        } else {
            Write-Error "服务启动失败"
        }
    } catch {
        Write-Error "服务启动失败: $_"
    }
}

function Test-ServiceStatus {
    Write-Info "检查服务状态..."

    $Hbbs = docker ps --filter "name=rustdesk-hbbs" --format "{{.Names}}" 2>&1
    $Hbbr = docker ps --filter "name=rustdesk-hbbr" --format "{{.Names}}" 2>&1

    if ($Hbbs -eq "rustdesk-hbbs" -and $Hbbr -eq "rustdesk-hbbr") {
        Write-Success "RustDesk 服务启动成功"

        Write-Host "`n服务状态:" -ForegroundColor Green
        docker ps --filter "name=rustdesk"

        Write-Host "`n访问地址:" -ForegroundColor Green
        Write-Host "  H BBS: ${HbbsPort} (TCP)"
        Write-Host "  H BBS TLS: ${HbbsTlsPort} (TCP)"
        Write-Host "  Relay: ${RelayPort} (TCP)"
        Write-Host "  NAT Type Test: ${NatTypeTestPort} (TCP)"

        Write-Host "`n查看日志:" -ForegroundColor Cyan
        Write-Host "  docker compose logs -f"
        Write-Host "  docker logs rustdesk-hbbs -f"
        Write-Host "  docker logs rustdesk-hbbr -f"

        Write-Host "`n服务管理:" -ForegroundColor Cyan
        Write-Host "  启动: cd $ProjectHome; docker compose start"
        Write-Host "  停止: cd $ProjectHome; docker compose stop"
        Write-Host "  重启: cd $ProjectHome; docker compose restart"
    } else {
        Write-Error "服务启动失败，请检查日志"
        Write-Host "查看日志: docker compose logs" -ForegroundColor Yellow
    }
}

function Test-Installation {
    Write-Info "验证安装..."

    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker 服务未运行"
            return $false
        }
    } catch {
        Write-Error "Docker 不可用"
        return $false
    }

    if (-not (Test-Path (Join-Path $ProjectHome "docker-compose.yml"))) {
        Write-Error "Docker Compose 配置文件不存在"
        return $false
    }

    Write-Success "安装验证通过"
    return $true
}

function Show-NextSteps {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "         安装完成！" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Write-Host "下一步操作:" -ForegroundColor Green
    Write-Host "  1. 获取公钥:"
    Write-Host "     docker logs rustdesk-hbbs 2>&1 | Select-String 'public key'"
    Write-Host ""
    Write-Host "  2. 配置 RustDesk 客户端:"
    Write-Host "     - 打开 RustDesk 客户端"
    Write-Host "     - 设置 ID 服务器为您的服务器地址"
    Write-Host "     - 填入上面获取的公钥"
    Write-Host ""
    Write-Host "  3. 管理服务:"
    Write-Host "     cd $ProjectHome"
    Write-Host "     .\manage.ps1 -Command status    # 查看状态"
    Write-Host "     .\manage.ps1 -Command logs       # 查看日志"
    Write-Host "     .\manage.ps1 -Command restart    # 重启服务"
    Write-Host ""
    Write-Host "  4. 备份配置:"
    Write-Host "     .\backup.ps1 -Command create    # 创建备份"
    Write-Host "     .\backup.ps1 -Command list      # 查看备份"
    Write-Host ""

    Write-Host "故障排查:" -ForegroundColor Yellow
    Write-Host "  - 查看日志: docker compose logs"
    Write-Host "  - 检查端口: netstat -an | Select-String '211'"
    Write-Host "  - 重启 Docker: Restart-Service com.docker.service"
    Write-Host "  - 检查 WSL: wsl -l -v"
    Write-Host ""
}

function Main {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "   RustDesk 自动安装脚本 v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    if (-not $Silent) {
        Write-Host "即将开始安装 RustDesk 服务器" -ForegroundColor Yellow
        Write-Host "部署模式: $Mode"
        Write-Host ""

        $Response = Read-Host "是否继续? (y/n)"
        if ($Response -ne "y" -and $Response -ne "Y") {
            Write-Info "安装已取消"
            return
        }
    }

    if (-not (Test-Administrator)) {
        Write-Error "此脚本需要管理员权限运行"
        Write-Host "请使用 '以管理员身份运行' 打开 PowerShell"
        return
    }

    if ($Mode -eq "docker") {
        Install-Dependencies
        Install-WSL
        Install-HyperV
        Install-Docker
        Install-DockerCompose
        New-Directories
        New-DockerComposeFile
        New-EnvFile
        Start-Services

        if (Test-Installation) {
            Show-NextSteps
        }
    } elseif ($Mode -eq "kubernetes") {
        Write-Info "Kubernetes 部署模式 (待实现)"
        Write-Host "请参考 docs/kubernetes.md 或使用 Helm"
    } elseif ($Mode -eq "source") {
        Write-Info "源码编译部署模式 (待实现)"
        Write-Host "请参考 docs/compile.md"
    }

    Write-Host "`n安装完成！" -ForegroundColor Green
}

Main
