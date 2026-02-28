param(
    [string]$OutputDir = (Join-Path $PSScriptRoot 'dist')
)

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

$packageName = 'claude-switch-tool'
$packDir = Join-Path $OutputDir $packageName
$zipPath = Join-Path $OutputDir "$packageName.zip"

$requiredFiles = @(
    'README.md',
    'claude-switch',
    'claude-switch.ps1',
    'install-claude-switch.sh',
    'install-claude-switch.ps1',
    'install-claude-switch.cmd',
    'pack-claude-switch.sh'
)

Write-Info "Preparing output directory: $OutputDir"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if (Test-Path $packDir) {
    Remove-Item -Recurse -Force $packDir
}
New-Item -ItemType Directory -Force -Path $packDir | Out-Null

foreach ($file in $requiredFiles) {
    $src = Join-Path $PSScriptRoot $file
    if (-not (Test-Path $src -PathType Leaf)) {
        throw "Missing required file: $src"
    }

    Write-Info "Copying $file"
    Copy-Item -Path $src -Destination (Join-Path $packDir $file) -Force
}

Write-Info 'Copying Windows pack script itself'
Copy-Item -Path $PSCommandPath -Destination (Join-Path $packDir 'pack-claude-switch.ps1') -Force

if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Write-Info 'Creating zip archive...'
Compress-Archive -Path (Join-Path $packDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

Write-Ok "Package directory created: $packDir"
Write-Ok "Zip created: $zipPath"

Write-Host ''
Write-Host 'Contents:'
Get-ChildItem -Path $packDir | Select-Object Name, Length | Format-Table -AutoSize

Write-Host ''
Write-Host 'On Windows target machine:'
Write-Host '1. Unzip the package'
Write-Host '2. Run .\install-claude-switch.cmd'
Write-Host '3. Use cs'
