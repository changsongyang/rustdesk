# RustDesk 服务管理脚本
# 用于管理 RustDesk 服务的生命周期
# Author: RustDesk Team
# Version: 1.0.0

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "health", "stats", "config", "update", "cleanup")]
    [string]$Command,

    [string]$Service = "all",
    [switch]$Follow,
    [int]$Tail = 100
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
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Test-ProjectFiles {
    if (-not (Test-Path $ProjectHome)) {
        Write-Error "项目目录不存在: $ProjectHome"
        Write-Host "请先运行 install.ps1 进行安装" -ForegroundColor Yellow
        exit 1
    }

    $ComposePath = Join-Path $ProjectHome "docker-compose.yml"
    if (-not (Test-Path $ComposePath)) {
        Write-Error "Docker Compose 文件不存在: $ComposePath"
        Write-Host "请先运行 install.ps1 进行安装" -ForegroundColor Yellow
        exit 1
    }
}

function Start-Services {
    Write-Info "启动 RustDesk 服务..."

    Set-Location $ProjectHome

    try {
        docker compose up -d
        if ($LASTEXITCODE -eq 0) {
            Write-Success "服务启动成功"
            Start-Sleep -Seconds 3
            Get-Status
        } else {
            Write-Error "服务启动失败"
            exit 1
        }
    } catch {
        Write-Error "服务启动失败: $_"
        exit 1
    }
}

function Stop-Services {
    Write-Info "停止 RustDesk 服务..."

    Set-Location $ProjectHome

    try {
        docker compose down
        if ($LASTEXITCODE -eq 0) {
            Write-Success "服务已停止"
        } else {
            Write-Error "服务停止失败"
            exit 1
        }
    } catch {
        Write-Error "服务停止失败: $_"
        exit 1
    }
}

function Restart-Services {
    Write-Info "重启 RustDesk 服务..."

    Stop-Services
    Start-Sleep -Seconds 2
    Start-Services
}

function Get-Status {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "       RustDesk 服务状态" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Test-ProjectFiles

    $HbbsStatus = "停止"
    $HbbrStatus = "停止"
    $HbbsRunning = $false
    $HbbrRunning = $false

    $HbbsContainer = docker ps --filter "name=rustdesk-hbbs" --format "{{.Names}}" 2>&1
    if ($HbbsContainer -eq "rustdesk-hbbs") {
        $HbbsStatus = "运行中"
        $HbbsRunning = $true
    }

    $HbbrContainer = docker ps --filter "name=rustdesk-hbbr" --format "{{.Names}}" 2>&1
    if ($HbbrContainer -eq "rustdesk-hbbr") {
        $HbbrStatus = "运行中"
        $HbbrRunning = $true
    }

    Write-Host "容器状态:"
    Write-Host "  rustdesk-hbbs`t$t(HbbsStatus)"
    Write-Host "  rustdesk-hbbr`t$t(HbbrStatus)"

    if ($HbbsRunning -and $HbbrRunning) {
        Write-Success "`n所有服务运行正常"

        Write-Host "`n容器详情:" -ForegroundColor Green
        docker ps --filter "name=rustdesk" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"

        Write-Host "`n端口监听:" -ForegroundColor Green
        $Connections = Get-NetTCPConnection -LocalPort $HbbsPort, $HbbsTlsPort, $RelayPort, $NatTypeTestPort -ErrorAction SilentlyContinue |
                       Select-Object LocalPort, State |
                       Group-Object LocalPort |
                       ForEach-Object {
                           Write-Host "  端口 $($_.Name): $($_.Group[0].State)"
                       }

        if (-not $Connections) {
            Write-Host "  (无法获取端口信息)" -ForegroundColor Yellow
        }
    } else {
        Write-Error "`n部分服务未运行"
    }
}

function Get-Logs {
    Test-ProjectFiles

    Set-Location $ProjectHome

    $LogsArgs = @("logs")
    if ($Tail -gt 0) {
        $LogsArgs += "--tail=$Tail"
    }
    if ($Follow) {
        $LogsArgs += "-f"
    }

    Write-Info "查看日志 (Service: $Service)..."

    switch ($Service) {
        "hbbs" {
            $Container = "rustdesk-hbbs"
            docker logs $LogsArgs $Container 2>&1
        }
        "hbbr" {
            $Container = "rustdesk-hbbr"
            docker logs $LogsArgs $Container 2>&1
        }
        "all" {
            if (-not $Follow) {
                docker compose logs --tail=$Tail 2>&1
            } else {
                docker compose logs -f 2>&1
            }
        }
        default {
            Write-Error "未知服务: $Service"
            Write-Host "可用服务: hbbs, hbbr, all" -ForegroundColor Yellow
            exit 1
        }
    }
}

function Test-Health {
    Write-Info "执行健康检查..."

    $OverallHealth = $true

    Write-Host "`n=== 容器健康检查 ===" -ForegroundColor Cyan

    $Containers = @("rustdesk-hbbs", "rustdesk-hbbr")

    foreach ($Container in $Containers) {
        $Running = docker ps --filter "name=$Container" --format "{{.Names}}" 2>&1

        if ($Running -eq $Container) {
            $Health = docker inspect --format='{{.State.Health.Status}}' $Container 2>$null
            $Status = docker inspect --format='{{.State.Status}}' $Container 2>$null
            $StartedAt = docker inspect --format='{{.State.StartedAt}}' $Container 2>$null

            Write-Host "`n$Container :"
            Write-Host "  状态: $Status"
            Write-Host "  健康: $($Health ?? 'none')"
            Write-Host "  启动时间: $StartedAt"

            if ($Status -ne "running") {
                $OverallHealth = $false
            }
        } else {
            Write-Host "`n$Container : " -NoNewline
            Write-Host "未运行" -ForegroundColor Red
            $OverallHealth = $false
        }
    }

    Write-Host "`n=== 端口可用性检查 ===" -ForegroundColor Cyan

    $Ports = @{
        $HbbsPort = "HBBDS"
        $HbbsTlsPort = "HBBDS_TLS"
        $RelayPort = "RELAY"
        $NatTypeTestPort = "NAT_TEST"
    }

    foreach ($Port in $Ports.Keys) {
        $Connection = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction SilentlyContinue
        Write-Host "  端口 $Port ($($Ports[$Port])): " -NoNewline
        if ($Connection.TcpTestSucceeded) {
            Write-Host "监听中" -ForegroundColor Green
        } else {
            Write-Host "未监听" -ForegroundColor Red
            $OverallHealth = $false
        }
    }

    Write-Host "`n=== 资源使用情况 ===" -ForegroundColor Cyan

    foreach ($Container in $Containers) {
        $Running = docker ps --filter "name=$Container" --format "{{.Names}}" 2>&1
        if ($Running -eq $Container) {
            Write-Host "`n$Container :"
            docker stats --no-stream --format "  CPU: {{.CPUPerc}}  内存: {{.MemUsage}}  网络: {{.NetIO}}" $Container
        }
    }

    if ($OverallHealth) {
        Write-Success "`n健康检查: 全部通过"
        return 0
    } else {
        Write-Error "`n健康检查: 部分失败"
        return 1
    }
}

function Get-Stats {
    Write-Info "获取连接统计..."

    Write-Host "`n=== Docker 统计 ===" -ForegroundColor Cyan

    $Containers = @()
    $Hbbs = docker ps --filter "name=rustdesk-hbbs" --format "{{.Names}}" 2>&1
    $Hbbr = docker ps --filter "name=rustdesk-hbbr" --format "{{.Names}}" 2>&1

    if ($Hbbs -eq "rustdesk-hbbs") { $Containers += "rustdesk-hbbs" }
    if ($Hbbr -eq "rustdesk-hbbr") { $Containers += "rustdesk-hbbr" }

    if ($Containers.Count -gt 0) {
        docker stats --no-stream --format "table {{.Name}}`t{{.CPUPerc}}`t{{.MemUsage}}`t{{.NetIO}}`t{{.BlockIO}}" $Containers
    }

    Write-Host "`n=== 连接统计 ===" -ForegroundColor Cyan

    Write-Host "`n活动连接:"
    $ConnectionCount = (Get-NetTCPConnection -LocalPort $HbbsPort, $HbbsTlsPort, $RelayPort, $NatTypeTestPort -State Established -ErrorAction SilentlyContinue).Count
    Write-Host "  总连接数: $ConnectionCount"

    Write-Host "`n按端口统计:"
    foreach ($Port in @($HbbsPort, $HbbsTlsPort, $RelayPort, $NatTypeTestPort)) {
        $Count = (Get-NetTCPConnection -LocalPort $Port -State Established -ErrorAction SilentlyContinue).Count
        Write-Host "  端口 $Port: $Count 连接"
    }

    Write-Host "`n=== 容器资源限制 ===" -ForegroundColor Cyan

    foreach ($Container in $Containers) {
        Write-Host "`n$Container :"
        $MemoryLimit = docker inspect --format='{{.HostConfig.Memory}}' $Container 2>$null
        $CpuQuota = docker inspect --format='{{.HostConfig.CpuQuota}}' $Container 2>$null

        if ($MemoryLimit -and $MemoryLimit -ne 0) {
            Write-Host "  内存限制: $([math]::Round($MemoryLimit / 1MB, 2))MB"
        } else {
            Write-Host "  内存限制: 无限制"
        }

        if ($CpuQuota -and $CpuQuota -ne 0) {
            Write-Host "  CPU限制: $CpuQuota"
        } else {
            Write-Host "  CPU限制: 无限制"
        }
    }
}

function Show-Config {
    param([string]$Action = "show")

    switch ($Action) {
        "show" {
            Write-Info "显示当前配置..."

            Write-Host "`n=== 项目配置 ===" -ForegroundColor Cyan
            Write-Host "项目目录: $ProjectHome"
            Write-Host "数据目录: $env:DATA_DIR"
            Write-Host "日志目录: $env:LOG_DIR"
            Write-Host "配置目录: $env:CONFIG_DIR"
            Write-Host "备份目录: $env:BACKUP_DIR"

            Write-Host "`n=== 服务端口 ===" -ForegroundColor Cyan
            Write-Host "HBBDS 端口: $HbbsPort"
            Write-Host "HBBDS TLS 端口: $HbbsTlsPort"
            Write-Host "Relay 端口: $RelayPort"
            Write-Host "NAT Type Test 端口: $NatTypeTestPort"
            Write-Host "Status 端口: $StatusPort"

            Write-Host "`n=== Docker Compose 配置 ===" -ForegroundColor Cyan
            $ComposePath = Join-Path $ProjectHome "docker-compose.yml"
            if (Test-Path $ComposePath) {
                Get-Content $ComposePath
            } else {
                Write-Error "配置文件不存在"
            }
        }
        "edit" {
            Write-Info "编辑配置..."
            $ComposePath = Join-Path $ProjectHome "docker-compose.yml"
            Write-Host "请手动编辑: $ComposePath"
            Start-Process notepad.exe $ComposePath
        }
        "reload" {
            Write-Info "重载配置..."
            Restart-Services
        }
        "backup-config" {
            Write-Info "备份配置..."

            $BackupDir = $env:BACKUP_DIR ?: "$ProjectHome\backups"
            if (-not (Test-Path $BackupDir)) {
                New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
            }

            $BackupFile = Join-Path $BackupDir "config_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"

            $ComposePath = Join-Path $ProjectHome "docker-compose.yml"
            if (Test-Path $ComposePath) {
                Compress-Archive -Path $ComposePath -DestinationPath $BackupFile -Force
                Write-Success "配置已备份到: $BackupFile"
            } else {
                Write-Error "备份失败: 配置文件不存在"
            }
        }
        default {
            Write-Error "未知配置操作: $Action"
            Write-Host "可用操作: show, edit, reload, backup-config" -ForegroundColor Yellow
        }
    }
}

function Update-Services {
    Write-Info "更新 RustDesk 服务..."

    Write-Host "确定要更新服务吗? 这将重启所有容器." -ForegroundColor Yellow
    $Response = Read-Host "(y/n)"

    if ($Response -ne "y" -and $Response -ne "Y") {
        Write-Info "更新已取消"
        return
    }

    Write-Info "拉取最新镜像..."
    docker pull rustdesk/rustdesk-server:latest

    Write-Info "重启服务..."
    Restart-Services

    Write-Success "更新完成"
}

function Clear-Resources {
    Write-Info "清理资源..."

    Write-Host "这将清理未使用的 Docker 资源" -ForegroundColor Yellow
    $Response = Read-Host "确定要继续吗? (y/n)"

    if ($Response -ne "y" -and $Response -ne "Y") {
        Write-Info "清理已取消"
        return
    }

    Write-Info "清理未使用的镜像..."
    docker image prune -f

    Write-Info "清理未使用的卷..."
    docker volume prune -f

    Write-Info "清理未使用的网络..."
    docker network prune -f

    Write-Info "清理构建缓存..."
    docker builder prune -f

    Write-Success "清理完成"
}

function Main {
    switch ($Command) {
        "start" { Start-Services }
        "stop" { Stop-Services }
        "restart" { Restart-Services }
        "status" { Get-Status }
        "logs" { Get-Logs }
        "health" { Test-Health }
        "stats" { Get-Stats }
        "config" { Show-Config }
        "update" { Update-Services }
        "cleanup" { Clear-Resources }
    }
}

Main
