param(
  [string]$ServiceName = "LanternSvc",
  [string]$ServiceExe = "build/windows/x64/runner/Release/lanternsvc.exe",
  [string]$InstallerPath = "",
  [string]$TokenPath = "C:\ProgramData\Lantern\ipc-token",
  [string]$TestPath = "integration_test/vpn/windows_connect_smoke_test.dart",
  [int]$WaitSeconds = 30,
  [int]$InstallerTimeoutSeconds = 180,
  [int]$UninstallTimeoutSeconds = 180,
  [int]$HeartbeatSeconds = 15,
  [switch]$EnableIpCheck,
  [switch]$UseInstaller
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Wait-ProcessWithTimeout {
  param(
    [Parameter(Mandatory = $true)]
    [System.Diagnostics.Process]$Process,
    [int]$TimeoutSeconds,
    [int]$PulseSeconds,
    [string]$Description
  )

  $elapsedSeconds = 0
  while (-not $Process.HasExited) {
    if ($elapsedSeconds -ge $TimeoutSeconds) {
      try {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
      } catch {
      }
      throw "$Description timed out after $TimeoutSeconds seconds"
    }

    if ($elapsedSeconds -gt 0 -and ($elapsedSeconds % $PulseSeconds) -eq 0) {
      Write-Step "$Description still running ($elapsedSeconds/$TimeoutSeconds s)"
    }

    Start-Sleep -Seconds 1
    $elapsedSeconds++
    $Process.Refresh()
  }
}

function Invoke-ProcessWithTimeout {
  param(
    [string]$FilePath,
    [string[]]$ArgumentList,
    [int]$TimeoutSeconds,
    [int]$PulseSeconds,
    [string]$Description
  )

  $arguments = $ArgumentList -join " "
  Write-Step ("{0}: {1} {2}" -f $Description, $FilePath, $arguments)
  $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru
  Wait-ProcessWithTimeout -Process $proc -TimeoutSeconds $TimeoutSeconds -PulseSeconds $PulseSeconds -Description $Description
  $proc.Refresh()
  if ($proc.ExitCode -ne 0) {
    throw "$Description failed with exit code $($proc.ExitCode)"
  }
}

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
    Write-Step "Stopping existing Windows service $Name"
    sc.exe stop $Name | Out-Null
    Start-Sleep -Seconds 2
    Write-Step "Deleting existing Windows service $Name"
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
      Write-Step "Windows service $Name is Running"
      return
    }
    if ($i -gt 0 -and ($i % 5) -eq 0) {
      Write-Step "Waiting for service $Name to be Running ($i/$TimeoutSeconds s)"
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
      Write-Step "IPC token detected at $Path"
      return
    }
    if ($i -gt 0 -and ($i % 5) -eq 0) {
      Write-Step "Waiting for IPC token at $Path ($i/$TimeoutSeconds s)"
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
  Invoke-ProcessWithTimeout `
    -FilePath $resolvedInstaller `
    -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-") `
    -TimeoutSeconds $InstallerTimeoutSeconds `
    -PulseSeconds $HeartbeatSeconds `
    -Description "Running installer"

  Write-Step "Waiting for Windows service after installer"
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

  Invoke-ProcessWithTimeout `
    -FilePath $uninstaller.FullName `
    -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-") `
    -TimeoutSeconds $UninstallTimeoutSeconds `
    -PulseSeconds $HeartbeatSeconds `
    -Description "Running uninstaller"
}

try {
  if ($UseInstaller) {
    Write-Step "Smoke setup mode: installer"
    Install-FromInstaller -Path $InstallerPath -TimeoutSeconds $WaitSeconds -Name $ServiceName
  } else {
    Write-Step "Smoke setup mode: direct service binary"
    $resolvedServiceExe = (Resolve-Path $ServiceExe).Path
    Remove-ServiceIfPresent -Name $ServiceName
    Write-Step "Creating Windows service from $resolvedServiceExe"
    sc.exe create $ServiceName binPath= "`"$resolvedServiceExe`"" start= demand DisplayName= "Lantern Service (CI)" | Out-Null
    Write-Step "Starting Windows service $ServiceName"
    sc.exe start $ServiceName | Out-Null
    Wait-ServiceRunning -Name $ServiceName -TimeoutSeconds $WaitSeconds
  }

  Wait-TokenFile -Path $TokenPath -TimeoutSeconds $WaitSeconds

  $flutterArgs = @(
    "test",
    $TestPath,
    "-d",
    "windows",
    "--reporter=expanded",
    "--dart-define=DISABLE_SYSTEM_TRAY=true"
  )
  if ($EnableIpCheck) {
    $flutterArgs += "--dart-define=ENABLE_IP_CHECK=true"
  }

  Write-Step ("Running Windows connect smoke test: flutter {0}" -f ($flutterArgs -join " "))
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Windows connect smoke test failed with exit code $LASTEXITCODE"
  }
}
finally {
  try {
    Write-Step "Starting cleanup"
    if ($UseInstaller) {
      Uninstall-FromInstalledService -Name $ServiceName
    } else {
      Remove-ServiceIfPresent -Name $ServiceName
    }
    Write-Step "Cleanup finished"
  } catch {
    Write-Warning ("Failed to clean up service {0}: {1}" -f $ServiceName, $_)
  }
}
