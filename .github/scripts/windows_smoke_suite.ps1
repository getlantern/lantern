param(
  [string]$ServiceName = "LanternSvc",
  [string]$ServiceExe = "build/windows/x64/runner/Release/lanternd.exe",
  [string]$InstallerPath = "",
  [string]$TestPath = "integration_test/vpn/windows_connect_smoke_test.dart",
  [string]$SplitTunnelWebsiteTestPath = "integration_test/vpn/split_tunneling_website_smoke_test.dart",
  [string]$ConfigUrlApiTestPath = "integration_test/vpn/windows_config_url_api_smoke_test.dart",
  [string]$ConfigUrlUiTestPath = "integration_test/vpn/windows_config_url_smoke_test.dart",
  [string]$DefaultConfigServerName = "ci-config-url-smoke",
  [int]$WaitSeconds = 30,
  [int]$InstallerTimeoutSeconds = 180,
  [int]$UninstallTimeoutSeconds = 180,
  [int]$HeartbeatSeconds = 15,
  [bool]$RunConnectSmoke = $true,
  [switch]$EnableIpCheck,
  [switch]$ForceFullTunnel,
  [switch]$RunSplitTunnelWebsiteSmoke,
  [switch]$RunConfigUrlSmoke,
  [switch]$UseInstaller
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Invoke-ScCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$ArgumentList,
    [int[]]$AllowedExitCodes = @(0),
    [string]$Description = ""
  )

  $desc = if ([string]::IsNullOrWhiteSpace($Description)) {
    "sc.exe $($ArgumentList -join ' ')"
  } else {
    $Description
  }
  Write-Step $desc
  $output = & sc.exe @ArgumentList 2>&1
  $exitCode = $LASTEXITCODE
  if ($output) {
    $output | ForEach-Object { Write-Host $_ }
  }
  if ($AllowedExitCodes -notcontains $exitCode) {
    throw "$desc failed with exit code $exitCode"
  }
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

function Invoke-LanterndCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(Mandatory = $true)]
    [string[]]$ArgumentList,
    [string]$Description
  )

  $desc = if ([string]::IsNullOrWhiteSpace($Description)) {
    "$FilePath $($ArgumentList -join ' ')"
  } else {
    $Description
  }

  Write-Step $desc
  $output = & $FilePath @ArgumentList 2>&1
  $exitCode = $LASTEXITCODE
  if ($output) {
    $output | ForEach-Object { Write-Host $_ }
  }
  if ($exitCode -ne 0) {
    throw "$desc failed with exit code $exitCode"
  }
}

function Invoke-FlutterSmokeTest {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Description,
    [switch]$EnableIpCheck,
    [switch]$ForceFullTunnel
  )

  $args = @(
    "test",
    $Path,
    "-d",
    "windows",
    "--reporter=expanded",
    "--dart-define=DISABLE_SYSTEM_TRAY=true"
  )

  if ($EnableIpCheck) {
    $args += "--dart-define=ENABLE_IP_CHECK=true"
  }

  if ($ForceFullTunnel) {
    $args += "--dart-define=SMOKE_FORCE_FULL_TUNNEL=true"
  }

  Write-Step ("Running {0}: flutter {1}" -f $Description, ($args -join " "))
  & flutter @args
  if ($LASTEXITCODE -ne 0) {
    throw "$Description failed with exit code $LASTEXITCODE"
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
    Invoke-ScCommand -ArgumentList @("stop", $Name) -AllowedExitCodes @(0, 1062)
    Start-Sleep -Seconds 2
    Write-Step "Deleting existing Windows service $Name"
    Invoke-ScCommand -ArgumentList @("delete", $Name) -AllowedExitCodes @(0, 1060)
    Start-Sleep -Seconds 2
  }
}

function Show-LanterndInstallDiagnostics {
  $lanterndPath = "C:\Program Files\Lantern\lanternd.exe"
  if (Test-Path $lanterndPath) {
    Write-Step "lanternd.exe exists at $lanterndPath"
    & $lanterndPath version 2>&1 | ForEach-Object { Write-Step "  version: $_" }
    return
  }

  Write-Step "lanternd.exe NOT found at $lanterndPath"
  Write-Step "Contents of C:\Program Files\Lantern\:"
  Get-ChildItem "C:\Program Files\Lantern\" -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Step "  $($_.Name)" }
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
  Show-LanterndInstallDiagnostics
  throw "Windows service did not reach Running state"
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

  $lanterndPath = "C:\Program Files\Lantern\lanternd.exe"
  $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
  if (-not $svc -and (Test-Path $lanterndPath)) {
    Invoke-LanterndCommand `
      -FilePath $lanterndPath `
      -ArgumentList @("install") `
      -Description "Service not found after installer; running lanternd install manually for diagnostics"
  }

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
    Invoke-LanterndCommand `
      -FilePath $resolvedServiceExe `
      -ArgumentList @("install") `
      -Description "Installing lanternd service from $resolvedServiceExe"
    Wait-ServiceRunning -Name $ServiceName -TimeoutSeconds $WaitSeconds
  }

  if ($RunConnectSmoke) {
    Invoke-FlutterSmokeTest `
      -Path $TestPath `
      -Description "Windows connect smoke test" `
      -EnableIpCheck:$EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel
  } else {
    Write-Step "Skipping Windows connect smoke test."
  }

  if ($RunSplitTunnelWebsiteSmoke) {
    Invoke-FlutterSmokeTest `
      -Path $SplitTunnelWebsiteTestPath `
      -Description "Website split tunneling smoke test" `
      -EnableIpCheck:$EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel
  } else {
    Write-Step "Skipping website split tunneling smoke test."
  }

  if (-not $RunConfigUrlSmoke) {
    Write-Step "Skipping config URL smoke tests."
  } else {
    $configUrls = $env:JOIN_SERVER_CONFIG_URLS
    if ([string]::IsNullOrWhiteSpace($configUrls)) {
      Write-Step "Skipping config URL smoke tests (JOIN_SERVER_CONFIG_URLS is not set)."
    } else {
      $generatedDefaultConfigServerName = $DefaultConfigServerName
      if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ID)) {
        $runAttempt = if ([string]::IsNullOrWhiteSpace($env:GITHUB_RUN_ATTEMPT)) { "1" } else { $env:GITHUB_RUN_ATTEMPT }
        $generatedDefaultConfigServerName = "ci-config-url-smoke-$($env:GITHUB_RUN_ID)-$runAttempt"
      }
      $configServerBaseName = $env:JOIN_SERVER_CONFIG_SERVER_NAME
      if ([string]::IsNullOrWhiteSpace($configServerBaseName)) {
        $configServerBaseName = $generatedDefaultConfigServerName
      }
      if ([string]::IsNullOrWhiteSpace($env:JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION)) {
        $env:JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION = "true"
      }

      $env:JOIN_SERVER_CONFIG_SERVER_NAME = "$configServerBaseName-api"
      Invoke-FlutterSmokeTest `
        -Path $ConfigUrlApiTestPath `
        -Description "Windows config URL API smoke test" `
        -ForceFullTunnel:$ForceFullTunnel

      $env:JOIN_SERVER_CONFIG_SERVER_NAME = "$configServerBaseName-ui"
      Invoke-FlutterSmokeTest `
        -Path $ConfigUrlUiTestPath `
        -Description "Windows config URL UI smoke test" `
        -ForceFullTunnel:$ForceFullTunnel
    }
  }
}
finally {
  try {
    Write-Step "Starting cleanup"
    if ($UseInstaller) {
      Uninstall-FromInstalledService -Name $ServiceName
    } else {
      $resolvedServiceExe = (Resolve-Path $ServiceExe -ErrorAction SilentlyContinue).Path
      if ($resolvedServiceExe) {
        Invoke-LanterndCommand `
          -FilePath $resolvedServiceExe `
          -ArgumentList @("uninstall") `
          -Description "Uninstalling lanternd service from $resolvedServiceExe"
      } else {
        Remove-ServiceIfPresent -Name $ServiceName
      }
    }
    Write-Step "Cleanup finished"
  } catch {
    Write-Warning ("Failed to clean up service {0}: {1}" -f $ServiceName, $_)
  }
}
