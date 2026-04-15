param(
  [string]$ServiceName = "LanternSvc",
  [switch]$Release
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell window."
  }
}

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-Step {
  param(
    [string]$Label,
    [scriptblock]$Action
  )
  Write-Step $Label
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE"
  }
}

function Remove-ServiceIfPresent {
  param([string]$Name)
  $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
  if (-not $service) {
    return
  }

  Write-Step "Stopping existing service '$Name'"
  & sc.exe stop $Name | Out-Host
  Start-Sleep -Seconds 1

  Write-Step "Deleting existing service '$Name'"
  & sc.exe delete $Name | Out-Host
  Start-Sleep -Seconds 2
}

function Install-And-StartService {
  param(
    [string]$Name,
    [string]$BinaryPath
  )
  if (-not (Test-Path $BinaryPath)) {
    throw "Service binary not found: $BinaryPath"
  }

  $quotedPath = "`"$BinaryPath`""
  Write-Step "Creating service '$Name'"
  & sc.exe create $Name binPath= $quotedPath start= auto DisplayName= "Lantern Service (dev)" | Out-Host

  Write-Step "Starting service '$Name'"
  & sc.exe start $Name | Out-Host

  $deadline = (Get-Date).AddSeconds(20)
  while ((Get-Date) -lt $deadline) {
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
      Write-Host "Service '$Name' is running." -ForegroundColor Green
      return
    }
    Start-Sleep -Seconds 1
  }

  & sc.exe query $Name | Out-Host
  throw "Service '$Name' did not reach Running state."
}

Require-Admin
Require-Command "make"
Require-Command "flutter"
Require-Command "dart"
Require-Command "go"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

$serviceBinary = Join-Path $repoRoot "bin\windows-amd64\lanternsvc.exe"
$dllBinary = Join-Path $repoRoot "bin\windows-amd64\liblantern.dll"
$wintunBinary = Join-Path $repoRoot "windows\third_party\wintun\bin\amd64\wintun.dll"

if ($Release) {
  $targetDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
  $appExe = Join-Path $targetDir "lantern.exe"
} else {
  $targetDir = Join-Path $repoRoot "build\windows\x64\runner\Debug"
  $appExe = Join-Path $targetDir "lantern.exe"
}

Invoke-Step "Fetching dependencies and generating code" {
  make pubget gen
}

Invoke-Step "Building Windows native artifacts (liblantern.dll + service + wintun)" {
  make windows-amd64 build-lanternsvc-windows wintun-amd64
}

Invoke-Step "Building Windows app" {
  if ($Release) {
    make build-windows-release
  } else {
    make windows-debug
  }
}

Write-Step "Copying native artifacts into app output folder"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Force $dllBinary (Join-Path $targetDir "liblantern.dll")
Copy-Item -Force $serviceBinary (Join-Path $targetDir "lanternsvc.exe")
Copy-Item -Force $wintunBinary (Join-Path $targetDir "wintun.dll")

Remove-ServiceIfPresent -Name $ServiceName
Install-And-StartService -Name $ServiceName -BinaryPath $serviceBinary

if (-not (Test-Path $appExe)) {
  throw "Lantern app executable not found: $appExe"
}

Write-Step "Launching Lantern app"
Start-Process -FilePath $appExe -WorkingDirectory $targetDir

Write-Host ""
Write-Host "Done." -ForegroundColor Green
