param(
  [string]$ServiceName = "LanternSvc",
  [switch]$Release,
  [int]$LogTailLines = 120,
  [switch]$SkipBuildStateReset,
  [switch]$LaunchElevated
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

function Normalize-CMakeEnvironment {
  $cmakeEnvVars = @(
    "CMAKE_GENERATOR",
    "CMAKE_GENERATOR_PLATFORM",
    "CMAKE_GENERATOR_TOOLSET",
    "CMAKE_MAKE_PROGRAM"
  )
  $cleared = $false

  foreach ($name in $cmakeEnvVars) {
    $path = "Env:$name"
    if (Test-Path $path) {
      $value = (Get-Item $path).Value
      Write-Host "Clearing $name=$value" -ForegroundColor Yellow
      Remove-Item $path
      $cleared = $true
    }
  }

  if ($cleared) {
    Write-Host "Cleared CMake generator environment overrides for this session." -ForegroundColor Green
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

  $deadline = (Get-Date).AddSeconds(20)
  while ((Get-Date) -lt $deadline) {
    if (-not (Get-Service -Name $Name -ErrorAction SilentlyContinue)) {
      Write-Host "Service '$Name' removed." -ForegroundColor Green
      return
    }
    Start-Sleep -Seconds 1
  }

  throw "Service '$Name' still exists after delete."
}

function Install-LanterndService {
  param(
    [string]$Name,
    [string]$BinaryPath
  )
  if (-not (Test-Path $BinaryPath)) {
    throw "Service binary not found: $BinaryPath"
  }

  Write-Step "Installing service '$Name' from '$BinaryPath'"
  & $BinaryPath install | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to install service '$Name' from $BinaryPath"
  }

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

function Show-ServiceStatus {
  param([string]$Name)
  Write-Step "Service diagnostics for '$Name'"
  & sc.exe qc $Name | Out-Host
  & sc.exe query $Name | Out-Host
}

function Show-ServiceLogs {
  param([int]$TailLines)

  $logPath = Join-Path $env:PUBLIC "Lantern\logs\lantern.log"
  if (-not (Test-Path $logPath)) {
    Write-Warning "Service log not found at $logPath"
    return
  }

  Write-Step "Recent Lantern log lines (tail $TailLines)"
  Get-Content -Path $logPath -Tail $TailLines | Out-Host
}

function Reset-WindowsBuildState {
  param([string]$RepoRoot)

  $paths = @(
    (Join-Path $RepoRoot "build\windows"),
    (Join-Path $RepoRoot "windows\flutter\ephemeral"),
    (Join-Path $RepoRoot ".dart_tool\flutter_build")
  )

  foreach ($path in $paths) {
    if (Test-Path $path) {
      Write-Host "Removing stale build path: $path" -ForegroundColor Yellow
      Remove-Item -Recurse -Force $path
    }
  }
}

function Stop-StaleBuildProcesses {
  $processNames = @("lantern", "flutter_tester", "dart")
  foreach ($name in $processNames) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if (-not $procs) {
      continue
    }

    foreach ($proc in $procs) {
      Write-Host "Stopping stale process: $($proc.ProcessName) (PID $($proc.Id))" -ForegroundColor Yellow
      Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
  }
}

function Clear-AppDiscoveryCache {
  $paths = @(
    (Join-Path $env:PUBLIC "Lantern\data\apps_cache.json"),
    (Join-Path $env:ProgramData "Lantern\data\apps_cache.json"),
    (Join-Path $env:LOCALAPPDATA "Lantern\data\apps_cache.json"),
    (Join-Path $env:APPDATA "Lantern\data\apps_cache.json")
  )

  foreach ($path in $paths) {
    if (Test-Path $path) {
      Write-Host "Removing app cache: $path" -ForegroundColor Yellow
      Remove-Item -Force $path
    }
  }
}

function Show-AppDiscoveryContext {
  Write-Step "App discovery context"
  Write-Host "USERNAME: $env:USERNAME"
  Write-Host "APPDATA: $env:APPDATA"
  Write-Host "LOCALAPPDATA: $env:LOCALAPPDATA"
  Write-Host "ProgramData Start Menu: $env:ProgramData\\Microsoft\\Windows\\Start Menu\\Programs"
}

function Show-BuildArtifactInfo {
  param(
    [string]$Path,
    [string]$Label
  )
  if (-not (Test-Path $Path)) {
    throw "$Label not found: $Path"
  }

  $item = Get-Item -Path $Path
  Write-Host "$Label => $($item.FullName)" -ForegroundColor Green
  Write-Host "  LastWriteTime: $($item.LastWriteTime.ToString("u"))"
  Write-Host "  Length: $($item.Length) bytes"
}

Require-Admin
Require-Command "make"
Require-Command "flutter"
Require-Command "dart"
Require-Command "go"
Normalize-CMakeEnvironment

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

Write-Step "Stopping stale Lantern/Flutter processes"
Stop-StaleBuildProcesses

if (-not $SkipBuildStateReset) {
  Write-Step "Resetting Windows build state"
  Reset-WindowsBuildState -RepoRoot $repoRoot
}

$serviceBinary = Join-Path $repoRoot "bin\windows-amd64\lanternd.exe"
$dllBinary = Join-Path $repoRoot "bin\windows-amd64\liblantern.dll"

if ($Release) {
  $targetDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
  $appExe = Join-Path $targetDir "lantern.exe"
} else {
  $targetDir = Join-Path $repoRoot "build\windows\x64\runner\Debug"
  $appExe = Join-Path $targetDir "lantern.exe"
}
$serviceOutputBinary = Join-Path $targetDir "lanternd.exe"

Remove-ServiceIfPresent -Name $ServiceName

Invoke-Step "Fetching dependencies and generating code" {
  make pubget gen
}

Invoke-Step "Building Windows native artifacts (liblantern.dll + lanternd)" {
  make windows-amd64 lanternd-windows-amd64
}

Invoke-Step "Building Windows app" {
  if ($Release) {
    make build-windows-release
  } else {
    make windows-debug
  }
}

Invoke-Step "Copying lanternd into app output folder" {
  if ($Release) {
    make copy-lanternd-release
  } else {
    make copy-lanternd-debug
  }
}

Write-Step "Copying native artifacts into app output folder"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Force $dllBinary (Join-Path $targetDir "liblantern.dll")

Write-Step "Build artifact diagnostics"
Show-BuildArtifactInfo -Path $dllBinary -Label "liblantern.dll"
Show-BuildArtifactInfo -Path $serviceOutputBinary -Label "lanternd.exe"
Show-BuildArtifactInfo -Path $appExe -Label "lantern.exe"

Install-LanterndService -Name $ServiceName -BinaryPath $serviceOutputBinary
Show-ServiceStatus -Name $ServiceName
Show-ServiceLogs -TailLines $LogTailLines
Show-AppDiscoveryContext
Clear-AppDiscoveryCache

if (-not (Test-Path $appExe)) {
  throw "Lantern app executable not found: $appExe"
}

Write-Step "Launching Lantern app"
if ($LaunchElevated) {
  Start-Process -FilePath $appExe -WorkingDirectory $targetDir
} else {
  $explorerExe = Join-Path $env:WINDIR "explorer.exe"
  Start-Process -FilePath $explorerExe -ArgumentList "`"$appExe`""
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
