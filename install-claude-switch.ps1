param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\claude-switch\bin"
)

$CompatBinDir = Join-Path $HOME '.local\bin'

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host ">>> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host ">>> $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host ">>> $Message" -ForegroundColor Yellow
}

function Add-ToUserPath {
    param([Parameter(Mandatory = $true)][string]$Dir)

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $parts = $current.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
    }

    $exists = $false
    foreach ($part in $parts) {
        if ([string]::Equals($part.Trim(), $Dir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $exists = $true
            break
        }
    }

    if (-not $exists) {
        $newPath = if ([string]::IsNullOrWhiteSpace($current)) { $Dir } else { "$current;$Dir" }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Warn "$Dir 已加入用户 PATH，重开终端后生效。"
    }
}

$SourceScript = Join-Path $PSScriptRoot 'claude-switch.ps1'
if (-not (Test-Path $SourceScript -PathType Leaf)) {
    throw "未找到主脚本: $SourceScript"
}

Write-Info "安装目录: $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$TargetScript = Join-Path $InstallDir 'claude-switch.ps1'
Copy-Item -Force -Path $SourceScript -Destination $TargetScript

$CmdWrapperPath = Join-Path $InstallDir 'claude-switch.cmd'
$CmdWrapper = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-switch.ps1" %*
"@
Set-Content -Path $CmdWrapperPath -Encoding ASCII -Value $CmdWrapper

$AliasPath = Join-Path $InstallDir 'cs.cmd'
$AliasWrapper = @"
@echo off
"%~dp0claude-switch.cmd" %*
"@
Set-Content -Path $AliasPath -Encoding ASCII -Value $AliasWrapper

Add-ToUserPath -Dir $InstallDir

# Additional compatibility shims for environments that prioritize ~/.local/bin
New-Item -ItemType Directory -Force -Path $CompatBinDir | Out-Null

$CompatClaudeSwitch = Join-Path $CompatBinDir 'claude-switch.cmd'
$CompatClaudeSwitchContent = @"
@echo off
"$CmdWrapperPath" %*
"@
Set-Content -Path $CompatClaudeSwitch -Encoding ASCII -Value $CompatClaudeSwitchContent

$CompatCs = Join-Path $CompatBinDir 'cs.cmd'
$CompatCsContent = @"
@echo off
"$AliasPath" %*
"@
Set-Content -Path $CompatCs -Encoding ASCII -Value $CompatCsContent

Add-ToUserPath -Dir $CompatBinDir

Write-Ok "安装完成。"
Write-Host ""
Write-Host "可用命令:"
Write-Host "  claude-switch"
Write-Host "  cs"
Write-Host ""
Write-Host "首次使用示例:"
Write-Host "  cs login main"
Write-Host "  cs"
