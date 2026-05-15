#Requires -Version 5.1
<#
.SYNOPSIS
    RustDesk Android 构建脚本 (Windows PowerShell)
.DESCRIPTION
    构建 Android APK 和 AppBundle，支持代码混淆和调试信息分离
.PARAMETER Mode
    构建模式：release, debug, profile (默认: release)
.PARAMETER StripLibs
    是否剥离原生库符号 (默认: true)
.PARAMETER Obfuscate
    是否启用代码混淆 (默认: true)
.EXAMPLE
    .\build_android.ps1
    .\build_android.ps1 -Mode profile -Obfuscate $false
#>

param(
    [ValidateSet("release", "debug", "profile")]
    [string]$Mode = "release",
    [bool]$StripLibs = $true,
    [bool]$Obfuscate = $true
)

$ErrorActionPreference = "Stop"

Write-Host "=== RustDesk Android Build ===" -ForegroundColor Cyan
Write-Host "Build Mode: $Mode" -ForegroundColor Cyan
Write-Host "Strip Libraries: $StripLibs" -ForegroundColor Cyan
Write-Host "Obfuscate: $Obfuscate" -ForegroundColor Cyan
Write-Host ""

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Error "ERROR: flutter command not found. Please ensure Flutter is in your PATH."
    exit 1
}

if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
    Write-Error "ERROR: ANDROID_HOME or ANDROID_SDK_ROOT environment variable is not set."
    exit 1
}

$androidSdk = $env:ANDROID_HOME ?? $env:ANDROID_SDK_ROOT
Write-Host "Android SDK: $androidSdk"

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

if ($stripCmd -and $StripLibs) {
    Write-Host "NDK found: $ndkPath"
    Write-Host "Stripping native libraries..." -ForegroundColor Yellow
    
    $jniLibsDir = "android\app\src\main\jniLibs"
    $archDirs = @("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
    
    foreach ($arch in $archDirs) {
        $libDir = Join-Path $jniLibsDir $arch
        if (Test-Path $libDir) {
            Write-Host "  Stripping $arch..."
            Get-ChildItem $libDir -Filter "*.so" | ForEach-Object {
                & $stripCmd $_.FullName 2>$null
            }
        }
    }
    Write-Host "Native libraries stripped." -ForegroundColor Green
} elseif (-not $stripCmd) {
    Write-Warning "NDK not found. Skipping native library strip (APK size will be larger)."
    Write-Warning "To strip native libraries, install NDK via SDK Manager."
}

$obfuscateFlags = @()
if ($Obfuscate) {
    $debugInfoDir = "split-debug-info"
    if (Test-Path $debugInfoDir) {
        Write-Host "Cleaning old debug info..."
        Remove-Item $debugInfoDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $debugInfoDir -Force | Out-Null
    $obfuscateFlags = @("--obfuscate", "--split-debug-info", $debugInfoDir)
}

Write-Host ""
Write-Host "=== Building APK (split-per-abi) ===" -ForegroundColor Cyan
flutter build apk --split-per-abi --target-platform android-arm64,android-arm,android-x64 --$Mode @obfuscateFlags

if ($LASTEXITCODE -ne 0) {
    Write-Error "APK build failed!"
    exit 1
}

Write-Host "APK build completed." -ForegroundColor Green

Write-Host ""
Write-Host "=== Building AppBundle ===" -ForegroundColor Cyan
flutter build appbundle --target-platform android-arm64,android-arm --$Mode @obfuscateFlags

if ($LASTEXITCODE -ne 0) {
    Write-Error "AppBundle build failed!"
    exit 1
}

Write-Host "AppBundle build completed." -ForegroundColor Green

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
