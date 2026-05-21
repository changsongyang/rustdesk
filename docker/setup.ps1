# RustDesk Docker Quick Start Script (Windows PowerShell)
# RustDesk Docker 快速启动脚本 (Windows PowerShell)

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "cleanup", "help")]
    [string]$Command = "help"
)

# 颜色定义 / Color definitions
$RED = "`e[0;31m"
$GREEN = "`e[0;32m"
$YELLOW = "`e[1;33m"
$BLUE = "`e[0;34m"
$NC = "`e[0m"

# 日志函数 / Logging functions
function Write-LogInfo {
    Write-Host "${BLUE}[INFO]${NC} $args" -NoNewline
    Write-Host ""
}

function Write-LogSuccess {
    Write-Host "${GREEN}[SUCCESS]${NC} $args" -NoNewline
    Write-Host ""
}

function Write-LogWarning {
    Write-Host "${YELLOW}[WARNING]${NC} $args" -NoNewline
    Write-Host ""
}

function Write-LogError {
    Write-Host "${RED}[ERROR]${NC} $args" -NoNewline
    Write-Host ""
}

# 显示横幅 / Show banner
function Show-Banner {
    Write-Host "${GREEN}"
    Write-Host @"
    ____           ____        _      ____                         _
   |  _ \ _ __ ___| __ )  ___ | |_   / ___|  _ __   ___  _ __ ___ | |__   ___ _ __
   | |_) | '__/ _ \  _ \ / _ \| __| | |  _  | '__| / _ \| '_ ` _ \| '_ \ / _ \ '__|
   |  _ <| | | (_) | |_) | (_) | |_  | |_| | | |  | (_) | | | | | | |_) |  __/ |
   |_| \_\_|  \___/|____/ \___/ \__|  \____| |_|   \___/|_| |_| |_|_.__/ \___|_|

    Docker Deployment Script v1.0
"@
    Write-Host "${NC}"
}

# 检查依赖 / Check dependencies
function Check-Dependencies {
    Write-LogInfo "检查依赖... / Checking dependencies..."

    # 检查 Docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-LogError "Docker 未安装 / Docker is not installed"
        exit 1
    }

    # 检查 Docker Compose
    $composeCmd = docker compose version 2>$null
    if (-not $composeCmd) {
        if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
            Write-LogError "Docker Compose 未安装 / Docker Compose is not installed"
            exit 1
        }
    }

    Write-LogSuccess "所有依赖已安装 / All dependencies are installed"
}

# 创建目录结构 / Create directory structure
function Create-Directories {
    Write-LogInfo "创建目录结构... / Creating directory structure..."

    # 创建必要的目录
    $dirs = @(
        "data\hbbs", "data\hbbr",
        "config\hbbs", "config\hbbr",
        "logs\hbbs", "logs\hbbr", "logs\nginx",
        "nginx", "certs", "backups"
    )

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    Write-LogSuccess "目录结构已创建 / Directory structure created"
}

# 配置文件 / Configure environment
function Configure-Environment {
    Write-LogInfo "配置环境变量... / Configuring environment variables..."

    # 复制环境变量文件
    if (-not (Test-Path ".env")) {
        Copy-Item ".env.example" ".env" -Force
        Write-LogSuccess "环境变量文件已创建 / Environment file created"
        Write-Warning "请编辑 .env 文件配置您的环境 / Please edit .env file to configure your environment"
    } else {
        Write-LogWarning ".env 文件已存在，跳过 / .env file already exists, skipping"
    }
}

# 拉取镜像 / Pull images
function Pull-Images {
    Write-LogInfo "拉取 Docker 镜像... / Pulling Docker images..."

    try {
        docker pull rustdesk/rustdesk-server:latest 2>&1 | Out-Null
        Write-LogSuccess "镜像准备完成 / Images ready"
    } catch {
        Write-LogWarning "拉取失败，将使用本地镜像 / Pull failed, will use local image"
    }
}

# 启动服务 / Start services
function Start-Services {
    Write-LogInfo "启动 Docker 服务... / Starting Docker services..."

    $composeVersion = docker compose version 2>$null
    if ($composeVersion) {
        docker compose up -d
    } else {
        docker-compose up -d
    }

    Write-LogSuccess "服务已启动 / Services started"
}

# 停止服务 / Stop services
function Stop-Services {
    Write-LogInfo "停止 Docker 服务... / Stopping Docker services..."

    $composeVersion = docker compose version 2>$null
    if ($composeVersion) {
        docker compose down
    } else {
        docker-compose down
    }

    Write-LogSuccess "服务已停止 / Services stopped"
}

# 查看状态 / View status
function View-Status {
    $composeVersion = docker compose version 2>$null
    if ($composeVersion) {
        docker compose ps
    } else {
        docker-compose ps
    }
}

# 查看日志 / View logs
function View-Logs {
    param([string]$Service)

    $composeVersion = docker compose version 2>$null
    if ($composeVersion) {
        if ($Service) {
            docker compose logs -f $Service
        } else {
            docker compose logs -f
        }
    } else {
        if ($Service) {
            docker-compose logs -f $Service
        } else {
            docker-compose logs -f
        }
    }
}

# 重启服务 / Restart services
function Restart-Services {
    Write-LogInfo "重启 Docker 服务... / Restarting Docker services..."

    $composeVersion = docker compose version 2>$null
    if ($composeVersion) {
        docker compose restart
    } else {
        docker-compose restart
    }

    Write-LogSuccess "服务已重启 / Services restarted"
}

# 清理环境 / Cleanup environment
function Cleanup-Environment {
    Write-LogWarning "清理 Docker 环境... / Cleaning up Docker environment..."

    $composeVersion = docker compose version 2>$null
    if ($composeVersion) {
        docker compose down -v
    } else {
        docker-compose down -v
    }

    Write-LogSuccess "环境已清理 / Environment cleaned"
}

# 显示帮助 / Show help
function Show-Help {
    Show-Banner
    Write-Host @"
使用说明 / Usage:
    .\setup.ps1 [command]

命令 / Commands:
    start       启动所有服务 / Start all services
    stop        停止所有服务 / Stop all services
    restart     重启所有服务 / Restart all services
    status      查看服务状态 / View service status
    logs [svc]  查看日志 (可选服务名) / View logs (optional service name)
    cleanup     清理所有数据 / Clean up all data
    help        显示此帮助 / Show this help

示例 / Examples:
    .\setup.ps1 start              # 启动服务 / Start services
    .\setup.ps1 logs hbbs          # 查看 hbbs 日志 / View hbbs logs
    .\setup.ps1 restart            # 重启服务 / Restart services
    .\setup.ps1 cleanup            # 清理环境 / Cleanup environment

"@
}

# 主函数 / Main function
function Main {
    # 获取脚本所在目录
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $ScriptDir

    switch ($Command) {
        "start" {
            Show-Banner
            Check-Dependencies
            Create-Directories
            Configure-Environment
            Pull-Images
            Start-Services
            Write-Host ""
            Write-LogSuccess "RustDesk Docker 服务已启动 / RustDesk Docker services started"
            Write-Host ""
            Write-Host "访问地址 / Access:"
            Write-Host "  hbbs: http://localhost:21115"
            Write-Host "  hbbr: http://localhost:21116"
            Write-Host ""
            Write-Host "查看日志 / View logs: .\setup.ps1 logs"
        }
        "stop" {
            Stop-Services
        }
        "restart" {
            Restart-Services
        }
        "status" {
            View-Status
        }
        "logs" {
            View-Logs -Service $args[0]
        }
        "cleanup" {
            Cleanup-Environment
        }
        "help" {
            Show-Help
        }
        default {
            Write-LogError "未知命令: $Command / Unknown command: $Command"
            Show-Help
            exit 1
        }
    }
}

# 执行主函数 / Execute main function
Main
