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

function Invoke-Step([string]$label, [scriptblock]$block) {
    Write-Step $label
    & $block
    if ($LASTEXITCODE -ne 0) {
        throw "$label failed with exit code $LASTEXITCODE"
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

function Get-PubspecVersion($pubspecPath) {
    $versionLine = Get-Content $pubspecPath | Where-Object { $_ -match '^version:' } | Select-Object -First 1
    if (-not $versionLine) {
        throw "Could not find version: in $pubspecPath"
    }

    $raw = ($versionLine -replace '^version:\s*', '').Trim()
    if (-not $raw) {
        throw "pubspec version line is empty"
    }

    return $raw
}

function Set-GoBuildEnv([hashtable]$vars) {
    $previous = @{}
    foreach ($key in $vars.Keys) {
        $previous[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, $vars[$key], "Process")
    }
    return $previous
}

function Restore-GoBuildEnv([hashtable]$previous) {
    foreach ($key in $previous.Keys) {
        [Environment]::SetEnvironmentVariable($key, $previous[$key], "Process")
    }
}

function Build-Liblantern($repoRoot, $outputPath, $extraLdflags) {
    $dartInclude = Join-Path $repoRoot "dart_api_dl\include"
    $normalizedRepoRoot = $repoRoot.Path -replace '\\', '/'

    $envBackup = Set-GoBuildEnv @{
        "GOOS" = "windows"
        "GOARCH" = "amd64"
        "CGO_ENABLED" = "1"
        "CGO_CFLAGS" = "-I$normalizedRepoRoot/dart_api_dl/include"
        "CGO_LDFLAGS" = "-static-libgcc -static-libstdc++ -static -lwinpthread"
    }

    try {
        & go build -v -trimpath -buildmode=c-shared `
            "-tags=with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_grpc,with_conntrack,with_dhcp,with_acme,with_tailscale" `
            "-ldflags=-w -s $extraLdflags" `
            "-o" $outputPath `
            "./lantern-core/ffi"
        if ($LASTEXITCODE -ne 0) {
            throw "go build for liblantern.dll failed"
        }
    }
    finally {
        Restore-GoBuildEnv $envBackup
    }
}

function Build-WindowsService($outputPath, $extraLdflags) {
    $envBackup = Set-GoBuildEnv @{
        "GOOS" = "windows"
        "GOARCH" = "amd64"
        "CGO_ENABLED" = "0"
    }

    try {
        & go build -v -trimpath `
            "-tags=with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_grpc,with_conntrack,with_dhcp,with_acme,with_tailscale" `
            "-ldflags=$extraLdflags" `
            "-o" $outputPath `
            "./lantern-core/cmd/lanternsvc"
        if ($LASTEXITCODE -ne 0) {
            throw "go build for lanternsvc.exe failed"
        }
    }
    finally {
        Restore-GoBuildEnv $envBackup
    }
}

function Ensure-Wintun($wintunDllPath, $version) {
    if (Test-Path $wintunDllPath) {
        Write-Host "Wintun already present at $wintunDllPath"
        return
    }

    $outDir = Split-Path $wintunDllPath -Parent
    $zipPath = Join-Path $outDir "wintun-$version.zip"
    $unzipDir = Join-Path $outDir "_unz"
    $url = "https://www.wintun.net/builds/wintun-$version.zip"

    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    if (Test-Path $unzipDir) {
        Remove-Item -Recurse -Force $unzipDir
    }
    New-Item -ItemType Directory -Force -Path $unzipDir | Out-Null

    Write-Host "Downloading Wintun $version from $url"
    Invoke-WebRequest -Uri $url -OutFile $zipPath

    Expand-Archive -Force -LiteralPath $zipPath -DestinationPath $unzipDir

    $extractedDll = Join-Path $unzipDir "wintun\bin\amd64\wintun.dll"
    if (-not (Test-Path $extractedDll)) {
        throw "Could not find extracted wintun.dll at $extractedDll"
    }

    Copy-Item -Force $extractedDll $wintunDllPath
    Remove-Item -Recurse -Force $unzipDir
}

Assert-Admin
Require-Command go
Require-Command flutter
Require-Command dart

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$debugDir = Join-Path $repoRoot "build\windows\x64\runner\Debug"
$releaseDir = Join-Path $repoRoot "build\windows\x64\runner\Release"

$serviceBinary = Join-Path $repoRoot "bin\windows-amd64\lanternsvc.exe"
$dllBinary = Join-Path $repoRoot "bin\windows-amd64\liblantern.dll"
$wintunBinary = Join-Path $repoRoot "windows\third_party\wintun\bin\amd64\wintun.dll"

New-Item -ItemType Directory -Force -Path (Split-Path $serviceBinary -Parent) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $dllBinary -Parent) | Out-Null

$pubspecVersion = Get-PubspecVersion (Join-Path $repoRoot "pubspec.yaml")
$appVersionPubspec = ($pubspecVersion -split '\+')[0]
$extraLdflags = "-X github.com/getlantern/radiance/common.Version=$appVersionPubspec"

if ($Release) {
    $targetDir = $releaseDir
    $appExePath = Join-Path $repoRoot "build\windows\x64\runner\Release\lantern.exe"
} else {
    $targetDir = $debugDir
    $appExePath = Join-Path $repoRoot $AppExe
}

Invoke-Step "Fetching Dart/Flutter deps" {
    flutter pub get
}

Invoke-Step "Generating code" {
    dart run build_runner build --delete-conflicting-outputs
}

Invoke-Step "Building Windows liblantern.dll" {
    Build-Liblantern -repoRoot $repoRoot -outputPath $dllBinary -extraLdflags $extraLdflags
}

Invoke-Step "Building Windows service" {
    Build-WindowsService -outputPath $serviceBinary -extraLdflags $extraLdflags
}

Invoke-Step "Fetching/building wintun" {
    Ensure-Wintun -wintunDllPath $wintunBinary -version "0.14.1"
}

Invoke-Step "Building Flutter Windows app" {
    if ($Release) {
        flutter build windows --release --verbose
    } else {
        flutter build windows --debug
    }
}

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