# RustDesk 环境检测脚本
# 用于检测系统环境是否满足部署要求
# Author: RustDesk Team
# Version: 1.0.0

param(
    [switch]$Silent
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
$MinCpuCores = [int]($env:MIN_CPU_CORES ?: 2)
$MinMemoryGB = [int]($env:MIN_MEMORY_GB ?: 2)
$MinDiskSpaceGB = [int]($env:MIN_DISK_SPACE_GB ?: 10)

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

function Check-OS {
    Write-Info "检测操作系统..."

    $OS = Get-CimInstance Win32_OperatingSystem
    $OSName = $OS.Caption
    $OSVersion = $OS.Version
    $OSBuild = $OS.BuildNumber
    $Architecture = $OS.OSArchitecture

    Write "  操作系统: $OSName"
    Write "  版本: $OSVersion (Build $OSBuild)"
    Write "  架构: $Architecture"

    if ($OSBuild -lt 17763) {
        Write-Warn "Windows 版本过低，建议 Windows 10 1809 或更高版本"
    }
}

function Check-Docker {
    Write-Info "检测 Docker..."

    try {
        $DockerVersion = docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write "  Docker 版本: $DockerVersion"

            $DockerComposeVersion = docker compose version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write "  Docker Compose 版本: $DockerComposeVersion"
            } else {
                Write-Warn "Docker Compose 未安装"
            }

            $DockerInfo = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Docker 服务运行正常"
            } else {
                Write-Error "Docker 服务未运行"
            }
        } else {
            Write-Error "Docker 未安装或未正确配置"
        }
    } catch {
        Write-Error "Docker 检测失败: $_"
    }
}

function Check-Ports {
    Write-Info "检测端口可用性..."

    $Ports = @{
        21115 = "HBBDS"
        21116 = "HBBDS_TLS"
        21117 = "RELAY"
        21118 = "NAT_TEST"
        21119 = "STATUS"
        21120 = "HEALTH"
    }

    foreach ($Port in $Ports.Keys) {
        $Connection = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction SilentlyContinue
        if ($Connection.TcpTestSucceeded) {
            Write-Host "  端口 $Port ($($Ports[$Port])): " -NoNewline
            Write-Host "已被占用" -ForegroundColor Red
        } else {
            Write-Host "  端口 $Port ($($Ports[$Port])): " -NoNewline
            Write-Host "可用" -ForegroundColor Green
        }
    }
}

function Check-SystemResources {
    Write-Info "检测系统资源..."

    $OS = Get-CimInstance Win32_OperatingSystem
    $TotalMemoryGB = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 2)
    $FreeMemoryGB = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)

    Write "  总内存: ${TotalMemoryGB}GB"
    Write "  可用内存: ${FreeMemoryGB}GB"

    if ($TotalMemoryGB -lt $MinMemoryGB) {
        Write-Error "内存不足 (要求: ${MinMemoryGB}GB)"
    } else {
        Write-Success "内存检查: 通过"
    }

    $Processor = Get-CimInstance Win32_Processor
    $CpuCores = $Processor.NumberOfCores
    $CpuLogicalProcessors = $Processor.NumberOfLogicalProcessors

    Write "  CPU 核心数: $CpuCores (逻辑处理器: $CpuLogicalProcessors)"

    if ($CpuCores -lt $MinCpuCores) {
        Write-Error "CPU 核心数不足 (要求: ${MinCpuCores})"
    } else {
        Write-Success "CPU 检查: 通过"
    }

    $Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $FreeDiskGB = [math]::Round($Disk.FreeSpace / 1GB, 2)

    Write "  C 盘可用空间: ${FreeDiskGB}GB"

    if ($FreeDiskGB -lt $MinDiskSpaceGB) {
        Write-Error "磁盘空间不足 (要求: ${MinDiskSpaceGB}GB)"
    } else {
        Write-Success "磁盘检查: 通过"
    }
}

function Check-Network {
    Write-Info "检测网络连通性..."

    $Endpoints = @(
        @{Url = "https://github.com"; Name = "GitHub"},
        @{Url = "https://hub.docker.com"; Name = "Docker Hub"},
        @{Url = "https://github.com/rustdesk/rustdesk/releases"; Name = "RustDesk 下载"}
    )

    foreach ($Endpoint in $Endpoints) {
        Write-Host "  $($Endpoint.Name): " -NoNewline
        try {
            $Response = Invoke-WebRequest -Uri $Endpoint.Url -Method Head -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($Response.StatusCode -eq 200 -or $Response.StatusCode -eq 301 -or $Response.StatusCode -eq 302) {
                Write-Host "可达" -ForegroundColor Green
            } else {
                Write-Host "不可达" -ForegroundColor Red
            }
        } catch {
            Write-Host "不可达" -ForegroundColor Red
        }
    }

    Write-Host "  DNS 解析: " -NoNewline
    try {
        $DNS = Resolve-DnsName "github.com" -ErrorAction SilentlyContinue
        if ($DNS) {
            Write-Host "正常" -ForegroundColor Green
        } else {
            Write-Host "异常" -ForegroundColor Red
        }
    } catch {
        Write-Host "异常" -ForegroundColor Red
    }
}

function Check-Dependencies {
    Write-Info "检测依赖项..."

    $RequiredDeps = @("curl", "git", "wget", "openssl")
    $OptionalDeps = @("jq", "7z", "tar")

    Write "  必需依赖:"
    foreach ($Dep in $RequiredDeps) {
        $Command = Get-Command $Dep -ErrorAction SilentlyContinue
        if ($Command) {
            Write-Host "    $Dep: " -NoNewline
            Write-Host "已安装" -ForegroundColor Green
        } else {
            Write-Host "    $Dep: " -NoNewline
            Write-Host "未安装" -ForegroundColor Red
        }
    }

    Write "  可选依赖:"
    foreach ($Dep in $OptionalDeps) {
        $Command = Get-Command $Dep -ErrorAction SilentlyContinue
        if ($Command) {
            Write-Host "    $Dep: " -NoNewline
            Write-Host "已安装" -ForegroundColor Green
        } else {
            Write-Host "    $Dep: " -NoNewline
            Write-Host "未安装" -ForegroundColor Yellow
        }
    }
}

function Check-Firewall {
    Write-Info "检测防火墙..."

    $FirewallProfiles = Get-NetFirewallProfile

    foreach ($Profile in $FirewallProfiles) {
        Write "  $($Profile.Name) 防火墙: " -NoNewline
        if ($Profile.Enabled) {
            Write-Host "已启用" -ForegroundColor Yellow
        } else {
            Write-Host "已禁用" -ForegroundColor Green
        }
    }

    $OpenPorts = Get-NetFirewallRule | Where-Object {
        $_.DisplayName -match "RustDesk" -or $_.DisplayName -match "2111[5-9]|2120"
    } | Select-Object DisplayName, Enabled, Direction

    if ($OpenPorts) {
        Write "  已配置的 RustDesk 规则:"
        $OpenPorts | ForEach-Object {
            Write "    $($_.DisplayName) ($($_.Direction)): " -NoNewline
            if ($_.Enabled) {
                Write-Host "已启用" -ForegroundColor Green
            } else {
                Write-Host "已禁用" -ForegroundColor Red
            }
        }
    } else {
        Write-Warn "未检测到 RustDesk 防火墙规则"
        Write "  需要开放的端口: 21115-21120/TCP"
    }
}

function Check-HyperV {
    Write-Info "检测 Hyper-V..."

    $HyperV = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -ErrorAction SilentlyContinue

    if ($HyperV -and $HyperV.State -eq "Enabled") {
        Write-Success "Hyper-V 已启用"
    } else {
        Write-Warn "Hyper-V 未启用 (Docker Desktop 需要)"
    }
}

function Check-WSL {
    Write-Info "检测 WSL..."

    $WSL = Get-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -ErrorAction SilentlyContinue

    if ($WSL -and $WSL.State -eq "Enabled") {
        Write-Success "WSL 已启用"
    } else {
        Write-Warn "WSL 未启用 (可选，用于 Linux 容器)"
    }
}

function Print-Summary {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "         环境检测报告汇总" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $OS = Get-CimInstance Win32_OperatingSystem
    Write-Host "操作系统: $($OS.Caption) $($OS.OSArchitecture)" -ForegroundColor Green
    Write-Host "系统资源: CPU: $CpuCores 核, 内存: ${TotalMemoryGB}GB, 磁盘: ${FreeDiskGB}GB" -ForegroundColor Green

    try {
        $DockerVersion = docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker: $DockerVersion" -ForegroundColor Green
        }
    } catch {
        Write-Host "Docker: 未安装" -ForegroundColor Red
    }

    Write-Host "`n注意事项:" -ForegroundColor Yellow
    Write-Host "  1. 确保所有必需端口未被占用"
    Write-Host "  2. 如使用防火墙，请开放 21115-21120/TCP"
    Write-Host "  3. Docker Desktop 需要 Hyper-V 支持"
    Write-Host "  4. 确保网络可以访问 Docker Hub 和 GitHub"

    Write-Host "`n下一步:" -ForegroundColor Cyan
    Write-Host "  运行 .\install.ps1 开始安装部署"
    Write-Host ""
}

function Main {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "   RustDesk 环境检测脚本 v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    Check-OS
    Check-Docker
    Check-Ports
    Check-SystemResources
    Check-Network
    Check-Dependencies
    Check-Firewall
    Check-HyperV
    Check-WSL

    Print-Summary
}

Main
