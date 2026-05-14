#Requires -Version 5.1
<#
.SYNOPSIS
    RustDesk Android 构建脚本 (Windows PowerShell)
.DESCRIPTION
    构建 Android APK 和 AppBundle，支持代码混淆和调试信息分离
.PARAMETER Mode
    构建模式：release, debug, profile (默认: release)
.EXAMPLE
    .\build_android.ps1
    .\build_android.ps1 -Mode profile
#>

param(
    [ValidateSet("release", "debug", "profile")]
    [string]$Mode = "release"
)

$ErrorActionPreference = "Stop"

Write-Host "=== RustDesk Android Build ===" -ForegroundColor Cyan
Write-Host "Build Mode: $Mode" -ForegroundColor Cyan
Write-Host ""

# 检查 Flutter 环境
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Error "ERROR: flutter command not found. Please ensure Flutter is in your PATH."
    exit 1
}

# 检查 Android SDK 环境
if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
    Write-Error "ERROR: ANDROID_HOME or ANDROID_SDK_ROOT environment variable is not set."
    exit 1
}

$androidSdk = $env:ANDROID_HOME ?? $env:ANDROID_SDK_ROOT
Write-Host "Android SDK: $androidSdk"

# 尝试查找 NDK 和 llvm-strip
$ndkPath = $null
$stripCmd = $null

$ndkDirs = @(
    "$androidSdk\ndk",
    "$androidSdk\ndk-bundle",
    "$env:LOCALAPPDATA\Android\Sdk\ndk"
)

foreach ($ndkDir in $ndkDirs) {
    if (Test-Path $ndkDir) {
        $ndkVersion = Get-ChildItem $ndkDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($ndkVersion) {
            $potentialStrip = "$ndkVersion\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-strip.exe"
            if (Test-Path $potentialStrip) {
                $ndkPath = $ndkVersion.FullName
                $stripCmd = $potentialStrip
                break
            }
        }
    }
}

if ($stripCmd) {
    Write-Host "NDK found: $ndkPath"
    Write-Host "Stripping native libraries..." -ForegroundColor Yellow
    
    $jniLibsDir = "android\app\src\main\jniLibs"
    $archDirs = @("arm64-v8a", "armeabi-v7a")
    
    foreach ($arch in $archDirs) {
        $libDir = Join-Path $jniLibsDir $arch
        if (Test-Path $libDir) {
            Write-Host "  Stripping $arch..."
            & $stripCmd (Get-ChildItem $libDir -File | Select-Object -ExpandProperty FullName) 2>$null
        }
    }
    Write-Host "Native libraries stripped." -ForegroundColor Green
} else {
    Write-Warning "NDK not found. Skipping native library strip (APK size will be larger)."
    Write-Warning "To strip native libraries, install NDK via SDK Manager."
}

# 清理旧的构建产物
$debugInfoDir = "split-debug-info"
if (Test-Path $debugInfoDir) {
    Write-Host "Cleaning old debug info..."
    Remove-Item $debugInfoDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $debugInfoDir -Force | Out-Null

# 构建 APK (split-per-abi)
Write-Host ""
Write-Host "=== Building APK (split-per-abi) ===" -ForegroundColor Cyan
flutter build apk --split-per-abi --target-platform android-arm64,android-arm --$Mode --obfuscate --split-debug-info $debugInfoDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "APK build failed!"
    exit 1
}

Write-Host "APK build completed." -ForegroundColor Green

# 构建 AppBundle
Write-Host ""
Write-Host "=== Building AppBundle ===" -ForegroundColor Cyan
flutter build appbundle --target-platform android-arm64,android-arm --$Mode --obfuscate --split-debug-info $debugInfoDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "AppBundle build failed!"
    exit 1
}

Write-Host "AppBundle build completed." -ForegroundColor Green

# 输出构建产物路径
Write-Host ""
Write-Host "=== Build Artifacts ===" -ForegroundColor Cyan
Write-Host "APK files:" -ForegroundColor Yellow
Get-ChildItem "android\app\build\outputs\flutter-apk\*.apk" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  $_"
}

Write-Host "AppBundle:" -ForegroundColor Yellow
Get-ChildItem "android\app\build\outputs\bundle\*\*.aab" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  $_"
}

Write-Host ""
Write-Host "=== Build completed successfully ===" -ForegroundColor Green
