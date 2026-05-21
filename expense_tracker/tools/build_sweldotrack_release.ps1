$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

function Assert-RequiredEnvVar {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable '$Name' is missing. Set it in PowerShell before running this script."
    }
}

function Invoke-FlutterStep {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host ""
    Write-Host "Running: flutter $($Arguments -join ' ')" -ForegroundColor Cyan
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter command failed: flutter $($Arguments -join ' ')"
    }
}

Assert-RequiredEnvVar -Name 'SWELDOTRACK_PREMIUM_VERIFY_URL'
Assert-RequiredEnvVar -Name 'SWELDOTRACK_PREMIUM_VERIFY_AUTH'

Push-Location $projectRoot
try {
    Invoke-FlutterStep -Arguments @('clean')
    Invoke-FlutterStep -Arguments @('pub', 'get')
    Invoke-FlutterStep -Arguments @('analyze')
    Invoke-FlutterStep -Arguments @('test')
    Invoke-FlutterStep -Arguments @(
        'build',
        'apk',
        '--release',
        "--dart-define=SWELDOTRACK_PREMIUM_VERIFY_URL=$env:SWELDOTRACK_PREMIUM_VERIFY_URL",
        "--dart-define=SWELDOTRACK_PREMIUM_VERIFY_AUTH=$env:SWELDOTRACK_PREMIUM_VERIFY_AUTH"
    )
    Invoke-FlutterStep -Arguments @(
        'build',
        'appbundle',
        '--release',
        "--dart-define=SWELDOTRACK_PREMIUM_VERIFY_URL=$env:SWELDOTRACK_PREMIUM_VERIFY_URL",
        "--dart-define=SWELDOTRACK_PREMIUM_VERIFY_AUTH=$env:SWELDOTRACK_PREMIUM_VERIFY_AUTH"
    )

    Write-Host ""
    Write-Host "Build outputs:" -ForegroundColor Green
    Write-Host "APK: build\\app\\outputs\\flutter-apk\\app-release.apk"
    Write-Host "AAB: build\\app\\outputs\\bundle\\release\\app-release.aab"
    Write-Host ""
    Write-Host "APK is for local install and developer testing." -ForegroundColor Yellow
    Write-Host "AAB is for Google Play Console upload." -ForegroundColor Yellow
}
finally {
    Pop-Location
}
