param(
  [string]$ServiceName = "LanternSvc",
  [string]$ServiceExe = "build/windows/x64/runner/Release/lanternsvc.exe",
  [string]$InstallerPath = "",
  [string]$TokenPath = "C:\ProgramData\Lantern\ipc-token",
  [string]$TestPath = "integration_test/vpn/windows_connect_smoke_test.dart",
  [string]$SplitTunnelWebsiteTestPath = "integration_test/vpn/split_tunneling_website_smoke_test.dart",
  [string]$SplitTunnelAppsTestPath = "integration_test/vpn/split_tunneling_apps_smoke_test.dart",
  [string]$SplitTunnelAppsRouteTestPath = "integration_test/vpn/split_tunneling_apps_smoke_test.dart",
  [string]$ConfigUrlApiTestPath = "integration_test/vpn/windows_config_url_api_smoke_test.dart",
  [string]$ConfigUrlUiTestPath = "integration_test/vpn/windows_config_url_smoke_test.dart",
  [string]$DefaultConfigServerName = "ci-config-url-smoke",
  [string]$SplitTunnelSmokeAppWingetId = "Anthropic.Claude",
  [string]$SplitTunnelSmokeAppDisplayName = "Claude",
  [string]$SplitTunnelSmokeAppExecutableHint = "Claude.exe",
  [string]$SplitTunnelRouteAppDisplayName = "Microsoft Edge",
  [string]$SplitTunnelRouteAppExecutableHint = "msedge.exe",
  [string]$SplitTunnelRouteBrowserPath = "",
  [string]$SplitTunnelRouteBypassEndpoint = "https://api64.ipify.org",
  [string]$SplitTunnelRouteRegularEndpoint = "https://icanhazip.com",
  [string]$SmokeDebugDir = "",
  [int]$WaitSeconds = 30,
  [int]$InstallerTimeoutSeconds = 180,
  [int]$UninstallTimeoutSeconds = 180,
  [int]$HeartbeatSeconds = 15,
  [bool]$RunConnectSmoke = $true,
  [switch]$EnableIpCheck,
  [switch]$ForceFullTunnel,
  [switch]$RunSplitTunnelWebsiteSmoke,
  [switch]$RunSplitTunnelAppsSmoke,
  [switch]$RunSplitTunnelAppsRouteSmoke,
  [switch]$RunConfigUrlSmoke,
  [switch]$InstallSmokeAppForSplitTunnel,
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

function Invoke-FlutterSmokeTest {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Description,
    [switch]$EnableIpCheck,
    [switch]$ForceFullTunnel,
    [string[]]$ExtraDartDefines = @()
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

  foreach ($dartDefine in $ExtraDartDefines) {
    if (-not [string]::IsNullOrWhiteSpace($dartDefine)) {
      $args += "--dart-define=$dartDefine"
    }
  }

  Write-Step ("Running {0}: flutter {1}" -f $Description, ($args -join " "))
  $output = & flutter @args 2>&1
  $exitCode = $LASTEXITCODE

  if ($output) {
    $output | ForEach-Object { Write-Host $_ }
  }

  if ($null -eq $exitCode) {
    return 0
  }
  return [int]$exitCode
}

function Invoke-FlutterSmokeTestWithPolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Description,
    [switch]$EnableIpCheck,
    [switch]$ForceFullTunnel,
    [string[]]$ExtraDartDefines = @(),
    [int]$RetryOnExitCode = -1,
    [int]$MaxAttempts = 1
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $exitCode = [int](Invoke-FlutterSmokeTest `
      -Path $Path `
      -Description $Description `
      -EnableIpCheck:$EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel `
      -ExtraDartDefines $ExtraDartDefines)

    if ($exitCode -eq 0) {
      return
    }

    $canRetry = (
      $RetryOnExitCode -ge 0 -and
      $exitCode -eq $RetryOnExitCode -and
      $attempt -lt $MaxAttempts
    )
    if ($canRetry) {
      Write-Step (
        "{0} exited with code {1} (attempt {2}/{3}); retrying once" -f
          $Description, $exitCode, $attempt, $MaxAttempts
      )
      Start-Sleep -Seconds 2
      continue
    }

    throw "$Description failed with exit code $exitCode"
  }
}

function Stop-LanternClientProcesses {
  param([string]$Reason = "")

  $clientProcs = Get-Process -Name "lantern" -ErrorAction SilentlyContinue
  if (-not $clientProcs) {
    return
  }

  if ([string]::IsNullOrWhiteSpace($Reason)) {
    Write-Step "Stopping lingering lantern.exe processes"
  } else {
    Write-Step "Stopping lingering lantern.exe processes ($Reason)"
  }

  foreach ($proc in $clientProcs) {
    try {
      Stop-Process -Id $proc.Id -Force -ErrorAction Stop
    } catch {
      Write-Warning ("Failed to stop lantern.exe process {0}: {1}" -f $proc.Id, $_)
    }
  }
  Start-Sleep -Seconds 1
}

function Invoke-IsolatedFlutterSmokeTest {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Description,
    [switch]$EnableIpCheck,
    [switch]$ForceFullTunnel,
    [string[]]$ExtraDartDefines = @(),
    [int]$RetryOnExitCode = -1,
    [int]$MaxAttempts = 1
  )

  Stop-LanternClientProcesses -Reason ("before {0}" -f $Description)
  try {
    Invoke-FlutterSmokeTestWithPolicy `
      -Path $Path `
      -Description $Description `
      -EnableIpCheck:$EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel `
      -ExtraDartDefines $ExtraDartDefines `
      -RetryOnExitCode $RetryOnExitCode `
      -MaxAttempts $MaxAttempts
  }
  finally {
    Stop-LanternClientProcesses -Reason ("after {0}" -f $Description)
  }
}

function Initialize-SmokeDebugDirectory {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
      $Path = Join-Path $env:RUNNER_TEMP "windows-smoke-debug"
    } else {
      $Path = Join-Path $PSScriptRoot "..\..\tmp\windows-smoke-debug"
    }
  }
  New-Item -ItemType Directory -Path $Path -Force | Out-Null
  return (Resolve-Path $Path).Path
}

function Write-SmokeDebugSnapshot {
  param(
    [string]$Path,
    [string]$SmokeAppDisplayName
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return
  }

  New-Item -ItemType Directory -Path $Path -Force | Out-Null
  $snapshotPath = Join-Path $Path "smoke-runtime-snapshot.txt"
  $lines = @()
  $lines += "timestamp=$(Get-Date -Format o)"
  $lines += "smoke_app_display_name=$SmokeAppDisplayName"
  $lines += ""

  $candidateFiles = @(
    "C:\Users\Public\Lantern\data\apps_cache.json",
    "C:\Users\Public\Lantern\data\split-tunnel.json",
    "C:\ProgramData\Lantern\ipc-token"
  )
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $candidateFiles += "$env:LOCALAPPDATA\Lantern\data\apps_cache.json"
    $candidateFiles += "$env:LOCALAPPDATA\Lantern\data\split-tunnel.json"
  }

  foreach ($candidate in $candidateFiles) {
    if (-not (Test-Path $candidate)) {
      $lines += "missing=$candidate"
      continue
    }

    $safeName = $candidate -replace '[\\/:*?"<>|]', '_'
    $copyPath = Join-Path $Path $safeName
    Copy-Item -Path $candidate -Destination $copyPath -Force
    $lines += "copied=$candidate -> $copyPath"
  }

  $logDirs = @("C:\Users\Public\Lantern\logs")
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $logDirs += "$env:LOCALAPPDATA\Lantern\logs"
  }

  foreach ($logDir in $logDirs) {
    if (-not (Test-Path $logDir)) {
      $lines += "missing_log_dir=$logDir"
      continue
    }

    $recentLogs = Get-ChildItem -Path $logDir -Filter "*.log" -File -ErrorAction SilentlyContinue |
      Sort-Object -Property LastWriteTime -Descending |
      Select-Object -First 6

    if (-not $recentLogs) {
      $lines += "no_logs_found=$logDir"
      continue
    }

    foreach ($logFile in $recentLogs) {
      $safeName = ($logFile.FullName -replace '[\\/:*?"<>|]', '_')
      $copyPath = Join-Path $Path $safeName
      Copy-Item -Path $logFile.FullName -Destination $copyPath -Force
      $lines += "copied_log=$($logFile.FullName) -> $copyPath"
    }
  }

  try {
    $serviceInfo = sc.exe query LanternSvc 2>&1
    $lines += ""
    $lines += "sc_query_lanternsvc:"
    $lines += $serviceInfo
  } catch {
    $lines += ""
    $lines += "sc_query_error=$($_.Exception.Message)"
  }

  Set-Content -Path $snapshotPath -Value $lines -Encoding UTF8
  Write-Step "Smoke runtime snapshot written to $snapshotPath"
}

function Get-ServicePathName {
  param([string]$Name)

  $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
  if (-not $svc) {
    return $null
  }
  return $svc.PathName
}

function Assert-ServiceRuntimeState {
  param(
    [string]$Name,
    [bool]$ExpectInstalledPath
  )

  $pathName = Get-ServicePathName -Name $Name
  if ([string]::IsNullOrWhiteSpace($pathName)) {
    throw "Windows service $Name is not registered."
  }

  $servicePathNameLower = $pathName.ToLowerInvariant()

  if ($ExpectInstalledPath) {
    $programFilesDirs = @(
      $env:ProgramFiles,
      ${env:ProgramFiles(x86)}
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    $expectedServicePaths = @()
    foreach ($baseDir in $programFilesDirs) {
      $expectedServicePaths += (Join-Path $baseDir "Lantern\\lanternsvc.exe")
      $expectedServicePaths += (Join-Path $baseDir "Lantern\\arm64\\lanternsvc.exe")
    }

    $existingExpectedPath = $null
    foreach ($candidatePath in $expectedServicePaths) {
      if (Test-Path $candidatePath) {
        $existingExpectedPath = $candidatePath
        break
      }
    }
    if ($null -eq $existingExpectedPath) {
      throw "No installed Lantern service executable found under Program Files."
    }

    $existingExpectedPathLower = $existingExpectedPath.ToLowerInvariant()
    if (-not $servicePathNameLower.Contains($existingExpectedPathLower)) {
      throw (
        "LanternSvc points to unexpected path. " +
        "Expected reference to: $existingExpectedPath ; actual PathName: $pathName"
      )
    }

    Write-Step "Service runtime path validated: $existingExpectedPath"
    return
  }

  $servicePathMatch = [regex]::Match(
    $pathName,
    '(?i)([A-Za-z]:\\[^"]*\\lanternsvc\.exe|\\\\[^\\]+\\[^\\]+\\[^"]*\\lanternsvc\.exe)'
  )
  if (-not $servicePathMatch.Success) {
    throw "Could not parse LanternSvc executable path from '$pathName'."
  }

  $serviceExe = $servicePathMatch.Groups[1].Value
  if (-not (Test-Path $serviceExe)) {
    throw "Service executable path does not exist: $serviceExe"
  }

  Write-Step "Service runtime path validated: $serviceExe"
}

function Write-DataPathDiagnostics {
  $lines = @()
  $candidateDataDirs = @("C:\Users\Public\Lantern\data")
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $candidateDataDirs += "$env:LOCALAPPDATA\Lantern\data"
  }

  foreach ($dir in $candidateDataDirs) {
    if (-not (Test-Path $dir)) {
      $lines += "missing_data_dir=$dir"
      continue
    }

    $lines += "data_dir=$dir"
    foreach ($name in @("split-tunnel.json", "apps_cache.json", "local.json")) {
      $filePath = Join-Path $dir $name
      if (Test-Path $filePath) {
        $size = (Get-Item $filePath).Length
        $lines += "  file=$filePath size=$size"
      } else {
        $lines += "  missing_file=$filePath"
      }
    }
  }

  if ($lines.Count -eq 0) {
    return
  }
  Write-Step "Windows data-path diagnostics:"
  $lines | ForEach-Object { Write-Host $_ }
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
      try {
        $token = (Get-Content -Path $Path -Raw -ErrorAction Stop).Trim()
      } catch {
        $token = ""
      }
      if (-not [string]::IsNullOrWhiteSpace($token)) {
        Write-Step "IPC token detected at $Path with content"
        return
      }
    }
    if ($i -gt 0 -and ($i % 5) -eq 0) {
      Write-Step "Waiting for non-empty IPC token at $Path ($i/$TimeoutSeconds s)"
    }
    Start-Sleep -Seconds 1
  }
  throw "IPC token file missing or empty at $Path"
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

$SmokeDebugDir = Initialize-SmokeDebugDirectory -Path $SmokeDebugDir
Write-Step "Smoke debug directory: $SmokeDebugDir"

try {
  if ($UseInstaller) {
    Write-Step "Smoke setup mode: installer"
    Install-FromInstaller -Path $InstallerPath -TimeoutSeconds $WaitSeconds -Name $ServiceName
  } else {
    Write-Step "Smoke setup mode: direct service binary"
    $resolvedServiceExe = (Resolve-Path $ServiceExe).Path
    Remove-ServiceIfPresent -Name $ServiceName
    Invoke-ScCommand `
      -ArgumentList @(
        "create",
        $ServiceName,
        "binPath= `"$resolvedServiceExe`"",
        "start= demand",
        "DisplayName= Lantern Service (CI)"
      ) `
      -Description "Creating Windows service from $resolvedServiceExe"
    Invoke-ScCommand `
      -ArgumentList @("start", $ServiceName) `
      -AllowedExitCodes @(0, 1056) `
      -Description "Starting Windows service $ServiceName"
    Wait-ServiceRunning -Name $ServiceName -TimeoutSeconds $WaitSeconds
  }

  Wait-TokenFile -Path $TokenPath -TimeoutSeconds $WaitSeconds
  Assert-ServiceRuntimeState -Name $ServiceName -ExpectInstalledPath:$UseInstaller
  Write-DataPathDiagnostics

  if ($RunSplitTunnelAppsSmoke -and [string]::IsNullOrWhiteSpace($SplitTunnelSmokeAppDisplayName)) {
    throw "SplitTunnelSmokeAppDisplayName must be set when apps split tunneling smoke is enabled."
  }

  if ($InstallSmokeAppForSplitTunnel) {
    & "$PSScriptRoot/windows_install_smoke_app.ps1" `
      -WingetId $SplitTunnelSmokeAppWingetId `
      -DisplayName $SplitTunnelSmokeAppDisplayName `
      -ExecutableHint $SplitTunnelSmokeAppExecutableHint `
      -OutputDir $SmokeDebugDir
    if ($LASTEXITCODE -ne 0) {
      throw "Smoke app install helper failed with exit code $LASTEXITCODE"
    }
  } elseif ($RunSplitTunnelAppsSmoke) {
    Write-Step "Apps split tunneling smoke is enabled without app install helper."
  }

  if ($RunConnectSmoke) {
    Invoke-IsolatedFlutterSmokeTest `
      -Path $TestPath `
      -Description "Windows connect smoke test" `
      -EnableIpCheck:$EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel
  } else {
    Write-Step "Skipping Windows connect smoke test."
  }

  if ($RunSplitTunnelWebsiteSmoke) {
    Invoke-IsolatedFlutterSmokeTest `
      -Path $SplitTunnelWebsiteTestPath `
      -Description "Website split tunneling smoke test" `
      -EnableIpCheck:$EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel
  } else {
    Write-Step "Skipping website split tunneling smoke test."
  }

  if ($RunSplitTunnelAppsSmoke) {
    $appsSmokeDefines = @(
      "SPLIT_TUNNEL_SMOKE_APP_NAME=$SplitTunnelSmokeAppDisplayName",
      "SPLIT_TUNNEL_SMOKE_APP_EXECUTABLE_HINT=$SplitTunnelSmokeAppExecutableHint"
    )

    Invoke-IsolatedFlutterSmokeTest `
      -Path $SplitTunnelAppsTestPath `
      -Description "Apps split tunneling smoke test" `
      -EnableIpCheck:$EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel `
      -ExtraDartDefines $appsSmokeDefines `
      -RetryOnExitCode 79 `
      -MaxAttempts 2
  } else {
    Write-Step "Skipping apps split tunneling smoke test."
  }

  if ($RunSplitTunnelAppsRouteSmoke) {
    if ([string]::IsNullOrWhiteSpace($SplitTunnelRouteAppDisplayName)) {
      throw "SplitTunnelRouteAppDisplayName must be set when apps route smoke is enabled."
    }
    if ([string]::IsNullOrWhiteSpace($SplitTunnelRouteAppExecutableHint)) {
      throw "SplitTunnelRouteAppExecutableHint must be set when apps route smoke is enabled."
    }

    $appsRouteSmokeDefines = @(
      "SPLIT_TUNNEL_SMOKE_APP_NAME=$SplitTunnelRouteAppDisplayName",
      "SPLIT_TUNNEL_SMOKE_APP_EXECUTABLE_HINT=$SplitTunnelRouteAppExecutableHint",
      "SPLIT_TUNNEL_ROUTE_CHECK=true",
      "SPLIT_TUNNEL_ROUTE_BYPASS_ENDPOINT=$SplitTunnelRouteBypassEndpoint",
      "SPLIT_TUNNEL_ROUTE_REGULAR_ENDPOINT=$SplitTunnelRouteRegularEndpoint"
    )
    if (-not [string]::IsNullOrWhiteSpace($SplitTunnelRouteBrowserPath)) {
      $appsRouteSmokeDefines += "SPLIT_TUNNEL_ROUTE_BROWSER_PATH=$SplitTunnelRouteBrowserPath"
    }

    Invoke-IsolatedFlutterSmokeTest `
      -Path $SplitTunnelAppsRouteTestPath `
      -Description "Apps split tunneling route smoke test" `
      -EnableIpCheck `
      -ForceFullTunnel:$ForceFullTunnel `
      -ExtraDartDefines $appsRouteSmokeDefines `
      -RetryOnExitCode 79 `
      -MaxAttempts 2
  } else {
    Write-Step "Skipping apps split tunneling route smoke test."
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

      # Run API and UI smoke tests with unique names to avoid collisions.
      $env:JOIN_SERVER_CONFIG_SERVER_NAME = "$configServerBaseName-api"
      Invoke-IsolatedFlutterSmokeTest `
        -Path $ConfigUrlApiTestPath `
        -Description "Windows config URL API smoke test" `
        -ForceFullTunnel:$ForceFullTunnel

      $env:JOIN_SERVER_CONFIG_SERVER_NAME = "$configServerBaseName-ui"
      Invoke-IsolatedFlutterSmokeTest `
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
      Remove-ServiceIfPresent -Name $ServiceName
    }
    Write-Step "Cleanup finished"
  } catch {
    Write-Warning ("Failed to clean up service {0}: {1}" -f $ServiceName, $_)
  }

  try {
    Write-SmokeDebugSnapshot `
      -Path $SmokeDebugDir `
      -SmokeAppDisplayName $SplitTunnelSmokeAppDisplayName
  } catch {
    Write-Warning ("Failed to write smoke runtime snapshot: {0}" -f $_)
  }
}
