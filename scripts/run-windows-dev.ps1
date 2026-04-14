param(
    [string]$ServiceName = "lanternsvc",
    [string]$AppExe = "build\windows\x64\runner\Debug\lantern.exe",
    [switch]$Release
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Assert-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        throw "This script must be run from an elevated PowerShell window."
    }
}

function Require-Command($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $name"
    }
}

function Get-ServiceSafe($name) {
    Get-Service -Name $name -ErrorAction SilentlyContinue
}

function Stop-And-Delete-Service($name) {
    $svc = Get-ServiceSafe $name
    if ($svc) {
        Write-Step "Stopping existing service '$name'"
        try {
            if ($svc.Status -ne "Stopped") {
                Stop-Service -Name $name -Force -ErrorAction Stop
                $svc.WaitForStatus("Stopped", "00:00:15")
            }
        } catch {
            Write-Warning "Failed stopping service cleanly: $($_.Exception.Message)"
        }

        Write-Step "Deleting existing service '$name'"
        & sc.exe delete $name | Out-Host

        Start-Sleep -Seconds 2
    }
}

function Install-Service($name, $binPath) {
    Write-Step "Creating service '$name'"
    & sc.exe create $name binPath= "`"$binPath`"" start= auto | Out-Host
}

function Start-And-Verify-Service($name) {
    Write-Step "Starting service '$name'"
    & sc.exe start $name | Out-Host

    $svc = Get-ServiceSafe $name
    if (-not $svc) {
        throw "Service '$name' was not found after creation."
    }

    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        $svc.Refresh()
        if ($svc.Status -eq "Running") {
            Write-Host "Service '$name' is running." -ForegroundColor Green
            return
        }
        Start-Sleep -Seconds 1
    }

    throw "Service '$name' did not reach Running state. Current state: $($svc.Status)"
}

Assert-Admin
Require-Command make
Require-Command flutter

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$debugDir = Join-Path $repoRoot "build\windows\x64\runner\Debug"
$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"

$serviceBinary = Join-Path $repoRoot "bin\windows-amd64\lanternsvc.exe"
$dllBinary = Join-Path $repoRoot "bin\windows-amd64\liblantern.dll"
$wintunBinary = Join-Path $repoRoot "windows\third_party\wintun\bin\amd64\wintun.dll"

if ($Release) {
    $targetDir = $releaseDir
    $appExePath = Join-Path $repoRoot "build\windows\x64\runner\Release\lantern.exe"
} else {
    $targetDir = $debugDir
    $appExePath = Join-Path $repoRoot $AppExe
}

Write-Step "Fetching Dart/Flutter deps"
& flutter pub get

Write-Step "Generating code"
& dart run build_runner build --delete-conflicting-outputs

Write-Step "Building Windows liblantern.dll"
& make windows-amd64
if ($LASTEXITCODE -ne 0) { throw "make windows-amd64 failed" }

Write-Step "Building Windows service"
& make build-lanternsvc-windows
if ($LASTEXITCODE -ne 0) { throw "make build-lanternsvc-windows failed" }

Write-Step "Fetching/building wintun"
& make wintun-amd64
if ($LASTEXITCODE -ne 0) { throw "make wintun-amd64 failed" }

Write-Step "Building Flutter Windows app"
if ($Release) {
    & flutter build windows --release --verbose
} else {
    & flutter build windows --debug
}
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

Write-Step "Copying native artifacts into app folder"
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Force $dllBinary (Join-Path $targetDir "liblantern.dll")
Copy-Item -Force $serviceBinary (Join-Path $targetDir "lanternsvc.exe")
Copy-Item -Force $wintunBinary (Join-Path $targetDir "wintun.dll")

Stop-And-Delete-Service -name $ServiceName
Install-Service -name $ServiceName -binPath $serviceBinary
Start-And-Verify-Service -name $ServiceName

if (-not (Test-Path $appExePath)) {
    throw "App executable not found: $appExePath"
}

Write-Step "Launching Lantern app"
Start-Process -FilePath $appExePath -WorkingDirectory (Split-Path $appExePath -Parent)

Write-Host ""
Write-Host "Done." -ForegroundColor Green