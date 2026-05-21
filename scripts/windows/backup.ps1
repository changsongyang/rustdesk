# RustDesk 备份恢复脚本
# 用于备份和恢复 RustDesk 配置和数据
# Author: RustDesk Team
# Version: 1.0.0

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "list", "verify", "restore", "delete", "cleanup", "schedule")]
    [string]$Command,

    [string]$Name,
    [switch]$Encrypt,
    [ValidateSet("gzip", "bzip2", "xz")]
    [string]$CompressType = "gzip",
    [int]$RetentionDays = 30
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

$BackupNamePrefix = "rustdesk-backup"

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

function Initialize-BackupDirectory {
    if (-not (Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
        Write-Info "创建备份目录: $BackupDir"
    }

    if (-not (Test-Path $ProjectHome)) {
        Write-Error "项目目录不存在: $ProjectHome"
        exit 1
    }
}

function Get-BackupName {
    param([string]$CustomName)

    if ($CustomName) {
        return "${CustomName}_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    } else {
        return "$BackupNamePrefix`_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
}

function New-Backup {
    param([string]$CustomName)

    $BackupName = Get-BackupName -CustomName $CustomName

    Write-Info "创建备份: $BackupName"

    Initialize-BackupDirectory

    $BackupPath = Join-Path $BackupDir $BackupName
    $BackupData = Join-Path $BackupPath "data"

    New-Item -Path $BackupData -ItemType Directory -Force | Out-Null

    Write-Info "备份配置文件..."
    $ComposePath = Join-Path $ProjectHome "docker-compose.yml"
    if (Test-Path $ComposePath) {
        Copy-Item $ComposePath $BackupData -Force
    }

    $EnvPath = Join-Path $ConfigDir ".env"
    if (Test-Path $EnvPath) {
        Copy-Item $EnvPath $BackupData -Force
    }

    Write-Info "备份数据目录..."
    if (Test-Path $DataDir) {
        Copy-Item -Path $DataDir -Destination (Join-Path $BackupData "data") -Recurse -Force
    }

    Write-Info "备份日志目录..."
    if (Test-Path $LogDir) {
        Copy-Item -Path $LogDir -Destination $BackupData -Recurse -Force
    }

    $Metadata = @{
        name = $BackupName
        created_at = (Get-Date -Format "o")
        hostname = $env:COMPUTERNAME
        project_home = $ProjectHome
        compress_type = $CompressType
        encrypted = $Encrypt.IsPresent
        version = $ScriptVersion
        files = @()
    }

    if (Test-Path $BackupData) {
        $Metadata.files = (Get-ChildItem $BackupData -Recurse).Name
    }

    $MetadataPath = Join-Path $BackupPath "metadata.json"
    $Metadata | ConvertTo-Json -Depth 10 | Set-Content $MetadataPath

    Write-Info "压缩备份..."

    $TempArchive = Join-Path $BackupDir "$BackupName.tar"
    $TempData = Join-Path $BackupPath "*"

    switch ($CompressType) {
        "gzip" {
            $FinalArchive = Join-Path $BackupDir "$BackupName.tar.gz"
        }
        "bzip2" {
            $FinalArchive = Join-Path $BackupDir "$BackupName.tar.bz2"
        }
        "xz" {
            $FinalArchive = Join-Path $BackupDir "$BackupName.tar.xz"
        }
    }

    tar -cf $TempArchive -C $BackupPath .
    Remove-Item -Path $BackupPath -Recurse -Force

    switch ($CompressType) {
        "gzip" {
            tar -czf $FinalArchive -C $BackupDir "$BackupName.tar"
        }
        "bzip2" {
            tar -cjf $FinalArchive -C $BackupDir "$BackupName.tar"
        }
        "xz" {
            tar -cJf $FinalArchive -C $BackupDir "$BackupName.tar"
        }
    }

    Remove-Item -Path $TempArchive -Force

    if ($Encrypt) {
        Write-Info "加密备份..."

        if (Get-Command openssl -ErrorAction SilentlyContinue) {
            $EncryptPass = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
            $EncryptedArchive = "$FinalArchive.enc"

            & openssl enc -aes-256-cbc -salt -pbkdf2 -in $FinalArchive -out $EncryptedArchive -k $EncryptPass

            Remove-Item $FinalArchive -Force

            $KeyFile = "$EncryptedArchive.key"
            Set-Content -Path $KeyFile -Value $EncryptPass -NoNewline

            Write-Warn "重要: 请妥善保管解密密钥!"
            Write-Host "密钥文件: $KeyFile" -ForegroundColor Yellow

            $FinalArchive = $EncryptedArchive
        } else {
            Write-Error "openssl 未安装，无法加密备份"
            return
        }
    }

    $BackupSize = (Get-Item $FinalArchive).Length / 1MB
    Write-Success "备份创建成功"
    Write-Host "  备份文件: $FinalArchive"
    Write-Host "  备份大小: $([math]::Round($BackupSize, 2)) MB"
    Write-Host "  创建时间: $(Get-Date)"
}

function Get-BackupList {
    Write-Info "列出备份..."

    Initialize-BackupDirectory

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "       RustDesk 备份列表" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $Backups = Get-ChildItem -Path $BackupDir -File | Where-Object {
        $_.Name -match '\.(tar\.gz|tar\.bz2|tar\.xz|enc)$'
    }

    $Count = 0
    $TotalSize = 0

    foreach ($Backup in $Backups) {
        $Filename = $Backup.Name
        $Size = [math]::Round($Backup.Length / 1MB, 2)
        $Date = $Backup.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

        $Encrypted = ""
        if ($Filename -match '\.enc$') {
            $Encrypted = " [加密]"
        }

        Write-Host "备份: $Filename$Encrypted"
        Write-Host "  大小: $Size MB"
        Write-Host "  日期: $Date"

        if ($Filename -match '\.enc$') {
            $KeyFile = "$($Backup.FullName).key"
            if (Test-Path $KeyFile) {
                Write-Host "  密钥: $KeyFile"
            }
        }

        Write-Host ""
        $TotalSize += $Backup.Length
        $Count++
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "总计: $Count 个备份"
    Write-Host "总大小: $([math]::Round($TotalSize / 1MB, 2)) MB"
    Write-Host "========================================`n" -ForegroundColor Cyan

    if ($Count -eq 0) {
        Write-Info "没有找到备份文件"
    }
}

function Test-BackupIntegrity {
    param([string]$BackupName)

    if (-not $BackupName) {
        Write-Error "请指定备份文件名"
        exit 1
    }

    $BackupPath = Join-Path $BackupDir $BackupName

    if (-not (Test-Path $BackupPath)) {
        $Found = Get-ChildItem -Path $BackupDir -Filter "*$BackupName*" -File | Select-Object -First 1
        if ($Found) {
            $BackupPath = $Found.FullName
        } else {
            Write-Error "备份文件不存在: $BackupName"
            exit 1
        }
    }

    Write-Info "验证备份: $([System.IO.Path]::GetFileName($BackupPath))"

    if ([System.IO.Path]::GetExtension($BackupPath) -eq ".enc") {
        Write-Info "备份已加密，跳过完整性检查"

        $KeyFile = "$BackupPath.key"
        if (Test-Path $KeyFile) {
            Write-Success "密钥文件存在"
        } else {
            Write-Error "密钥文件不存在"
            return 1
        }
        return 0
    }

    try {
        switch ([System.IO.Path]::GetExtension($BackupPath)) {
            ".gz" {
                & tar -tzf $BackupPath 2>&1 | Out-Null
            }
            ".bz2" {
                & tar -tjf $BackupPath 2>&1 | Out-Null
            }
            ".xz" {
                & tar -tJf $BackupPath 2>&1 | Out-Null
            }
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Success "备份完整性验证通过"
            return 0
        } else {
            Write-Error "备份完整性验证失败"
            return 1
        }
    } catch {
        Write-Error "备份完整性验证失败: $_"
        return 1
    }
}

function Restore-Backup {
    param([string]$BackupName)

    if (-not $BackupName) {
        Write-Error "请指定备份文件名"
        exit 1
    }

    $BackupPath = Join-Path $BackupDir $BackupName

    if (-not (Test-Path $BackupPath)) {
        $Found = Get-ChildItem -Path $BackupDir -Filter "*$BackupName*" -File | Select-Object -First 1
        if ($Found) {
            $BackupPath = $Found.FullName
        } else {
            Write-Error "备份文件不存在: $BackupName"
            exit 1
        }
    }

    Write-Warn "即将恢复备份，这可能会覆盖当前配置"
    $Response = Read-Host "确定要继续吗? (yes/no)"

    if ($Response -ne "yes") {
        Write-Info "恢复已取消"
        return
    }

    Write-Info "停止服务..."
    Set-Location $ProjectHome
    docker compose down 2>&1 | Out-Null

    $TempDir = Join-Path $BackupDir "temp_restore_$(Get-Random)"
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

    Write-Info "解压备份..."

    $SourcePath = $BackupPath

    if ([System.IO.Path]::GetExtension($BackupPath) -eq ".enc") {
        if (-not (Test-Path "$BackupPath.key")) {
            Write-Error "密钥文件不存在: $BackupPath.key"
            Remove-Item -Path $TempDir -Recurse -Force
            return
        }

        Write-Info "解密备份..."
        $DecryptPass = Get-Content "$BackupPath.key" -Raw
        $TempArchive = Join-Path $TempDir "backup.tar.gz"

        & openssl enc -aes-256-cbc -d -pbkdf2 -in $BackupPath -out $TempArchive -k $DecryptPass
        $SourcePath = $TempArchive
    }

    Write-Info "提取备份..."

    switch ([System.IO.Path]::GetExtension($SourcePath)) {
        ".gz" {
            tar -xzf $SourcePath -C $TempDir
        }
        ".bz2" {
            tar -xjf $SourcePath -C $TempDir
        }
        ".xz" {
            tar -xJf $SourcePath -C $TempDir
        }
    }

    Write-Info "恢复配置文件..."

    $ComposePath = Join-Path $TempDir "docker-compose.yml"
    if (Test-Path $ComposePath) {
        Copy-Item $ComposePath (Join-Path $ProjectHome "docker-compose.yml") -Force
        Write-Host "  docker-compose.yml 已恢复"
    }

    $EnvPath = Join-Path $TempDir ".env"
    if (Test-Path $EnvPath) {
        if (-not (Test-Path $ConfigDir)) {
            New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null
        }
        Copy-Item $EnvPath (Join-Path $ConfigDir ".env") -Force
        Write-Host "  .env 已恢复"
    }

    $DataBackup = Join-Path $TempDir "data"
    if (Test-Path $DataBackup) {
        $DataTarget = Join-Path $TempDir "data"
        $DataDest = Join-Path $DataBackup "data"

        if (Test-Path $DataDest) {
            if (Test-Path $DataDir) {
                Remove-Item $DataDir -Recurse -Force
            }
            Copy-Item $DataDest $DataDir -Recurse -Force
            Write-Host "  数据目录已恢复"
        }
    }

    Remove-Item -Path $TempDir -Recurse -Force

    Write-Info "重启服务..."
    docker compose up -d 2>&1 | Out-Null

    Write-Success "备份恢复完成"
}

function Remove-Backup {
    param([string]$BackupName)

    if (-not $BackupName) {
        Write-Error "请指定备份文件名"
        exit 1
    }

    $BackupPath = Join-Path $BackupDir $BackupName

    if (-not (Test-Path $BackupPath)) {
        $Found = Get-ChildItem -Path $BackupDir -Filter "*$BackupName*" -File | Select-Object -First 1
        if ($Found) {
            $BackupPath = $Found.FullName
        } else {
            Write-Error "备份文件不存在: $BackupName"
            exit 1
        }
    }

    Write-Warn "即将删除备份: $([System.IO.Path]::GetFileName($BackupPath))"
    $Response = Read-Host "确定要删除吗? (yes/no)"

    if ($Response -eq "yes") {
        Remove-Item $BackupPath -Force

        $KeyFile = "$BackupPath.key"
        if (Test-Path $KeyFile) {
            Remove-Item $KeyFile -Force
        }

        Write-Success "备份已删除"
    } else {
        Write-Info "删除已取消"
    }
}

function Clear-OldBackups {
    Write-Info "清理过期备份..."
    Write-Host "保留最近 $RetentionDays 天的备份" -ForegroundColor Cyan

    Initialize-BackupDirectory

    $Count = 0
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)

    $Backups = Get-ChildItem -Path $BackupDir -File | Where-Object {
        $_.Name -match '\.(tar\.gz|tar\.bz2|tar\.xz|enc)$'
    }

    foreach ($Backup in $Backups) {
        if ($Backup.LastWriteTime -lt $CutoffDate) {
            Write-Host "删除过期备份: $($Backup.Name) ($([math]::Round(((Get-Date) - $Backup.LastWriteTime).TotalDays, 0)) 天前)"
            Remove-Item $Backup.FullName -Force

            $KeyFile = "$($Backup.FullName).key"
            if (Test-Path $KeyFile) {
                Remove-Item $KeyFile -Force
            }

            $Count++
        }
    }

    if ($Count -eq 0) {
        Write-Info "没有过期的备份需要清理"
    } else {
        Write-Success "已删除 $Count 个过期备份"
    }
}

function Set-BackupSchedule {
    param([string]$ScheduleType = "daily")

    Write-Info "设置定时备份任务..."

    $CronEntry = switch ($ScheduleType) {
        "hourly" { "0 * * * *" }
        "daily" { "0 2 * * *" }
        "weekly" { "0 2 * * 0" }
        "monthly" { "0 2 1 * *" }
        default {
            Write-Error "不支持的备份频率: $ScheduleType"
            Write-Host "支持的频率: hourly, daily, weekly, monthly"
            exit 1
        }
    }

    $ScheduleDescription = switch ($ScheduleType) {
        "hourly" { "每小时执行一次备份" }
        "daily" { "每天凌晨 2:00 执行备份" }
        "weekly" { "每周日凌晨 2:00 执行备份" }
        "monthly" { "每月 1 日凌晨 2:00 执行备份" }
    }

    Write-Host "计划任务配置:" -ForegroundColor Cyan
    Write-Host "$ScheduleDescription"
    Write-Host ""

    $ScriptPath = Join-Path $PSScriptRoot "backup.ps1"

    try {
        $Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File `"$ScriptPath`" -Command create"
        $Trigger = switch ($ScheduleType) {
            "hourly" { New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) }
            "daily" { New-ScheduledTaskTrigger -Daily -At "2:00AM" }
            "weekly" { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "2:00AM" }
            "monthly" { New-ScheduledTaskTrigger -Daily -At "2:00AM" }
        }
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

        $TaskName = "RustDesk_Backup"

        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($ExistingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }

        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "RustDesk 自动备份任务" | Out-Null

        Write-Success "定时备份任务已设置"
        Write-Host "`n查看任务:" -ForegroundColor Cyan
        Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
    } catch {
        Write-Error "设置定时任务失败: $_"
    }
}

function Main {
    switch ($Command) {
        "create" { New-Backup -CustomName $Name }
        "list" { Get-BackupList }
        "verify" { Test-BackupIntegrity -BackupName $Name }
        "restore" { Restore-Backup -BackupName $Name }
        "delete" { Remove-Backup -BackupName $Name }
        "cleanup" { Clear-OldBackups }
        "schedule" { Set-BackupSchedule }
    }
}

Main
