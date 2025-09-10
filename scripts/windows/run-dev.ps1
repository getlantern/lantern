<#  Run Lantern in "dev" mode on Windows (separate pipe/token from the installed service)

    Usage:
      scripts\run-dev.ps1
      scripts\run-dev.ps1 -BackendExe C:\path\to\lantern-core.exe

    Notes:
      - Uses \\.\pipe\LanternService.dev and %LOCALAPPDATA%\Lantern\ipc-token.dev
#>

param(
  [string]$BackendExe = "",
  [string]$FlutterDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$NoFlutter,
  [switch]$NoBackend
)

$ErrorActionPreference = "Stop"

# ---- Dev environment settings (separate from installed service) ----
$env:LANTERN_PIPE_NAME = "\\.\pipe\LanternService.dev"
$env:LANTERN_TOKEN_PATH = Join-Path $env:LOCALAPPDATA "Lantern\ipc-token.dev"
$env:LANTERN_DATA_DIR   = Join-Path $env:LOCALAPPDATA "Lantern\dev"
$env:LANTERN_LOG_DIR    = Join-Path $env:LOCALAPPDATA "Lantern\logs\dev"
$env:LANTERN_LOCALE     = $env:LANTERN_LOCALE ?? "en-US"

$dirs = @($env:LANTERN_DATA_DIR, $env:LANTERN_LOG_DIR, (Split-Path $env:LANTERN_TOKEN_PATH -Parent))
foreach ($d in $dirs) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }

Write-Host "Dev pipe:   $($env:LANTERN_PIPE_NAME)"
Write-Host "Dev token:  $($env:LANTERN_TOKEN_PATH)"
Write-Host "Dev data:   $($env:LANTERN_DATA_DIR)"
Write-Host "Dev logs:   $($env:LANTERN_LOG_DIR)"
Write-Host ""

# ---- Start backend in console mode ----
$backendProc = $null
if (-not $NoBackend) {
  if (-not $BackendExe) {
    $candidates = @(
      (Join-Path $PSScriptRoot "..\lantern-core.exe"),
      (Join-Path $PSScriptRoot "..\bin\lantern-core.exe"),
      (Join-Path $PSScriptRoot "..\build\lantern-core.exe")
    )
    foreach ($c in $candidates) {
      if (Test-Path $c) { $BackendExe = (Resolve-Path $c).Path; break }
    }
  }

  if ($BackendExe -and (Test-Path $BackendExe)) {
    Write-Host "Starting backend: $BackendExe (console/dev mode)" -ForegroundColor Cyan
    $backendArgs = @(
      "-console",
      "-pipe",   $env:LANTERN_PIPE_NAME,
      "-data",   $env:LANTERN_DATA_DIR,
      "-log",    $env:LANTERN_LOG_DIR,
      "-token",  $env:LANTERN_TOKEN_PATH,
      "-locale", $env:LANTERN_LOCALE
    )
    $backendProc = Start-Process -FilePath $BackendExe -ArgumentList $backendArgs -PassThru
  }
  else {
    if (Get-Command go -ErrorAction SilentlyContinue) {
      $backendDirGuess = Resolve-Path (Join-Path $PSScriptRoot "..") | Select-Object -ExpandProperty Path
      Write-Host "Binary not found. Running 'go run' from: $backendDirGuess" -ForegroundColor Yellow
      Push-Location $backendDirGuess
      try {
        $backendProc = Start-Process -FilePath "go" -ArgumentList @(
          "run",".",
          "-console",
          "-pipe",$env:LANTERN_PIPE_NAME,
          "-data",$env:LANTERN_DATA_DIR,
          "-log",$env:LANTERN_LOG_DIR,
          "-token",$env:LANTERN_TOKEN_PATH,
          "-locale",$env:LANTERN_LOCALE
        ) -PassThru
      } finally {
        Pop-Location
      }
    } else {
      throw "Backend exe not found and 'go' is not available. Provide -BackendExe or build the binary."
    }
  }
}

# ---- Start Flutter app ----
$flutterProc = $null
if (-not $NoFlutter) {
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Warning "Flutter not found on PATH. Skipping Flutter app launch."
  } else {
    if (-not (Test-Path $FlutterDir)) { throw "FlutterDir not found: $FlutterDir" }
    Write-Host "Launching Flutter app from: $FlutterDir (device: windows)" -ForegroundColor Cyan
    Push-Location $FlutterDir
    try {
      $flutterProc = Start-Process -FilePath "flutter" -ArgumentList @("run","-d","windows") -PassThru
    } finally {
      Pop-Location
    }
  }
}

Write-Host ""
Write-Host "Dev environment started." -ForegroundColor Green
if ($backendProc) { Write-Host "  Backend PID: $($backendProc.Id)" }
if ($flutterProc) { Write-Host "  Flutter PID: $($flutterProc.Id)" }
Write-Host ""
Write-Host "To stop: close the backend console window and Ctrl+C the Flutter run, or use scripts\stop-dev.ps1" -ForegroundColor DarkGray