param(
  [string]$ServiceName = "LanternSvc",
  [string]$ServiceExe = "build/windows/x64/runner/Release/lanternsvc.exe",
  [string]$InstallerPath = "",
  [string]$TokenPath = "C:\ProgramData\Lantern\ipc-token",
  [string]$TestPath = "integration_test/vpn/windows_connect_smoke_test.dart",
  [int]$WaitSeconds = 30,
  [switch]$EnableIpCheck,
  [switch]$UseInstaller
)

$ErrorActionPreference = "Stop"

function Get-ServicePathName {
  param([string]$Name)

  $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
  if (-not $svc) {
    return $null
  }
  return $svc.PathName
}

function Get-ServiceExecutablePath {
  param([string]$PathName)

  if ([string]::IsNullOrWhiteSpace($PathName)) {
    return $null
  }
  $trimmed = $PathName.Trim()
  if ($trimmed.StartsWith('"')) {
    $end = $trimmed.IndexOf('"', 1)
    if ($end -gt 1) {
      return $trimmed.Substring(1, $end - 1)
    }
  }
  return ($trimmed -split '\s+')[0]
}

function Remove-ServiceIfPresent {
  param([string]$Name)

  if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
    sc.exe stop $Name | Out-Null
    Start-Sleep -Seconds 2
    sc.exe delete $Name | Out-Null
    Start-Sleep -Seconds 2
  }
}

function Wait-ServiceRunning {
  param(
    [string]$Name,
    [int]$TimeoutSeconds
  )

  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
      return
    }
    Start-Sleep -Seconds 1
  }

  sc.exe query $Name
  throw "Windows service did not reach Running state"
}

function Wait-TokenFile {
  param(
    [string]$Path,
    [int]$TimeoutSeconds
  )

  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Path $Path) {
      return
    }
    Start-Sleep -Seconds 1
  }
  throw "IPC token file not found at $Path"
}

function Install-FromInstaller {
  param(
    [string]$Path,
    [int]$TimeoutSeconds,
    [string]$Name
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "InstallerPath must be set when -UseInstaller is enabled"
  }
  $resolvedInstaller = (Resolve-Path $Path).Path
  $proc = Start-Process -FilePath $resolvedInstaller `
    -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-" `
    -PassThru -Wait
  if ($proc.ExitCode -ne 0) {
    throw "Installer exited with code $($proc.ExitCode)"
  }

  Wait-ServiceRunning -Name $Name -TimeoutSeconds $TimeoutSeconds
}

function Uninstall-FromInstalledService {
  param(
    [string]$Name
  )

  $pathName = Get-ServicePathName -Name $Name
  $svcExe = Get-ServiceExecutablePath -PathName $pathName
  if (-not $svcExe) {
    return
  }

  $installDir = Split-Path -Path $svcExe -Parent
  if (-not (Test-Path $installDir)) {
    return
  }

  $uninstaller = Get-ChildItem -Path $installDir -Filter "unins*.exe" -ErrorAction SilentlyContinue |
    Sort-Object -Property Name |
    Select-Object -First 1

  if (-not $uninstaller) {
    return
  }

  $proc = Start-Process -FilePath $uninstaller.FullName `
    -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-" `
    -PassThru -Wait
  if ($proc.ExitCode -ne 0) {
    throw "Uninstaller exited with code $($proc.ExitCode)"
  }
}

try {
  if ($UseInstaller) {
    Install-FromInstaller -Path $InstallerPath -TimeoutSeconds $WaitSeconds -Name $ServiceName
  } else {
    $resolvedServiceExe = (Resolve-Path $ServiceExe).Path
    Remove-ServiceIfPresent -Name $ServiceName
    sc.exe create $ServiceName binPath= "`"$resolvedServiceExe`"" start= demand DisplayName= "Lantern Service (CI)" | Out-Null
    sc.exe start $ServiceName | Out-Null
    Wait-ServiceRunning -Name $ServiceName -TimeoutSeconds $WaitSeconds
  }

  Wait-TokenFile -Path $TokenPath -TimeoutSeconds $WaitSeconds

  $flutterArgs = @(
    "test",
    $TestPath,
    "-d",
    "windows",
    "--dart-define=DISABLE_SYSTEM_TRAY=true"
  )
  if ($EnableIpCheck) {
    $flutterArgs += "--dart-define=ENABLE_IP_CHECK=true"
  }

  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  try {
    if ($UseInstaller) {
      Uninstall-FromInstalledService -Name $ServiceName
    } else {
      Remove-ServiceIfPresent -Name $ServiceName
    }
  } catch {
    Write-Warning ("Failed to clean up service {0}: {1}" -f $ServiceName, $_)
  }
}
