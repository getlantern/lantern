# Shared by the installed Release startup gate and the WinSparkle update smoke.
# Keep the monitor independent of Windows APIs so its failure modes can be tested.
function Invoke-GuiHealthMonitor {
  param(
    [Parameter(Mandatory)][scriptblock]$Probe,
    [Parameter(Mandatory)][int]$ExpectedProcessId,
    [Parameter(Mandatory)][string]$ExpectedPath,
    [ValidateRange(120, 3600)][int]$DurationSeconds = 120,
    [ValidateRange(1, 300)][int]$WindowTimeoutSeconds = 120,
    [scriptblock]$Now = { [DateTime]::UtcNow },
    [scriptblock]$Pause = { Start-Sleep -Milliseconds 1000 },
    [scriptblock]$OnReady = {}
  )
  $started = & $Now
  $healthySince = $null
  $identity = $null
  $nextProgress = $started
  while ($true) {
    $sample = & $Probe
    $current = & $Now
    if ($null -eq $sample -or $sample.ProcessId -ne $ExpectedProcessId -or
        $sample.Path -ne $ExpectedPath) {
      throw "Expected GUI process $ExpectedProcessId exited or was replaced"
    }
    if ($null -eq $identity) { $identity = $sample.StartTimeTicks }
    if ($sample.StartTimeTicks -ne $identity) {
      throw "GUI process ID $ExpectedProcessId was reused"
    }
    $healthy = $sample.HasWindow -and $sample.Responding
    if ($null -ne $healthySince -and -not $healthy) {
      throw "GUI process $ExpectedProcessId lost its window or stopped responding"
    }
    if ($healthy -and $null -eq $healthySince) {
      $healthySince = $current
      & $OnReady
    }
    if ($null -eq $healthySince -and ($current - $started).TotalSeconds -ge $WindowTimeoutSeconds) {
      throw "GUI process $ExpectedProcessId did not show a responsive window"
    }
    if ($current -ge $nextProgress) {
      Write-Host "[E2E] monitoring GUI PID $ExpectedProcessId; elapsed $([int]($current - $started).TotalSeconds)s"
      $nextProgress = $current.AddSeconds(15)
    }
    if ($null -ne $healthySince -and ($current - $healthySince).TotalSeconds -ge $DurationSeconds) {
      return
    }
    & $Pause
  }
}

function Get-LanternGuiSample([int]$ProcessId) {
  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($null -eq $process) { return $null }
  try {
    $process.Refresh()
    if ($process.HasExited) { return $null }
    [pscustomobject]@{
      ProcessId = $process.Id
      Path = $process.Path
      StartTimeTicks = $process.StartTime.ToUniversalTime().Ticks
      HasWindow = $process.MainWindowHandle -ne 0
      Responding = $process.Responding
    }
  } catch {
    if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) { return $null }
    throw
  }
}

function Get-LanternFileEvidence([string]$Path) {
  $file = Get-Item -LiteralPath $Path -ErrorAction Stop
  $signature = Get-AuthenticodeSignature -LiteralPath $Path
  [pscustomobject]@{
    path = $file.FullName
    sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    file_version = $file.VersionInfo.FileVersion
    product_version = $file.VersionInfo.ProductVersion
    signature_status = [string]$signature.Status
    signer = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
  }
}

function Save-LanternModuleEvidence {
  param([int]$ProcessId, [string]$AppExecutable, [string]$OutputPath)
  $process = Get-Process -Id $ProcessId -ErrorAction Stop
  $process.Refresh()
  $modules = @($process.Modules | Where-Object {
      $_.ModuleName -match '^(msvcp140.*|vcruntime140.*|ucrtbase|auto_updater_windows_plugin|WinSparkle)\.dll$'
    } | ForEach-Object { Get-LanternFileEvidence $_.FileName })
  @{
    pid = $ProcessId
    process_started_utc = $process.StartTime.ToUniversalTime().ToString('o')
    captured_utc = [DateTime]::UtcNow.ToString('o')
    workflow_source_commit = $env:GITHUB_SHA
    workflow_run = $env:GITHUB_RUN_ID
    os = [Environment]::OSVersion.VersionString
    application = Get-LanternFileEvidence $AppExecutable
    modules = $modules
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath
  if (-not ($modules | Where-Object { [IO.Path]::GetFileName($_.path) -eq 'auto_updater_windows_plugin.dll' })) {
    throw 'The expected updater plugin DLL is not loaded in the GUI process'
  }
  if (-not ($modules | Where-Object { [IO.Path]::GetFileName($_.path) -eq 'msvcp140.dll' })) {
    throw 'Unable to identify the C++ runtime actually loaded by the GUI process'
  }
}

function Wait-LanternGuiHealthy {
  param(
    [int]$ProcessId, [string]$AppExecutable, [string]$ArtifactDirectory,
    [string]$Phase
  )
  New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null
  Invoke-GuiHealthMonitor -ExpectedProcessId $ProcessId -ExpectedPath $AppExecutable `
    -Probe { Get-LanternGuiSample $ProcessId } `
    -OnReady {
      Save-LanternModuleEvidence $ProcessId $AppExecutable (Join-Path $ArtifactDirectory "$Phase-modules-start.json")
    }
  Save-LanternModuleEvidence $ProcessId $AppExecutable (Join-Path $ArtifactDirectory "$Phase-modules-end.json")
}

function Get-LanternFlutterLogPath {
  $publicDirectory = if ($env:PUBLIC) { $env:PUBLIC } else { 'C:\Users\Public' }
  Join-Path $publicDirectory 'Lantern\logs\flutter.log'
}

function Assert-LanternUpdaterStartup {
  param([string]$LogPath, [DateTime]$StartedAt, [string]$OutputPath)
  # Use the logger's UTC timestamp, not file mtime: an older successful launch
  # must not satisfy this launch's updater witness.
  $lines = @(Get-Content -LiteralPath $LogPath -ErrorAction Stop | Where-Object {
      if ($_ -match '^time="(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) UTC"') {
        $time = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss.fff',
          [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
        $time.ToUniversalTime() -ge $StartedAt.ToUniversalTime()
      } else { $false }
    })
  $lines | Set-Content -LiteralPath $OutputPath
  if (-not ($lines -match 'message=autoUpdater configured\.') -or
      -not ($lines -match 'message=Desktop update check: source=startup(?:\s|$)')) {
    throw 'This launch did not configure the native updater and start its normal startup check'
  }
}

function Export-LanternWindowsEvents {
  param([DateTime]$StartedAt, [string]$ArtifactDirectory, [string]$AppDirectory)
  $crashes = @()
  foreach ($logName in @('Application', 'Microsoft-Windows-CodeIntegrity/Operational', 'Microsoft-Windows-WER-Diag/Operational')) {
    $name = $logName.Replace('/', '-').Replace('Microsoft-Windows-', '')
    try {
      $events = @(Get-WinEvent -FilterHashtable @{ LogName = $logName; StartTime = $StartedAt } -ErrorAction Stop)
    } catch {
      if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { $events = @() }
      else {
        $_ | Out-String | Set-Content (Join-Path $ArtifactDirectory "events-$name-error.txt")
        if ($logName -eq 'Application') { throw }
        continue
      }
    }
    $records = @($events | ForEach-Object {
        [pscustomobject]@{
          time = $_.TimeCreated.ToUniversalTime().ToString('o')
          id = $_.Id
          provider = $_.ProviderName
          message = $_.Message
          xml = $_.ToXml()
        }
      })
    ConvertTo-Json -InputObject $records -Depth 6 | Set-Content (Join-Path $ArtifactDirectory "events-$name.json")
    $crashes += @($records | Where-Object {
        $related = $_.xml -match '(?i)lantern\.exe|auto_updater_windows_plugin\.dll' -or
          ($AppDirectory -and $_.xml -match [regex]::Escape($AppDirectory))
        $related -and (($logName -eq 'Application' -and $_.id -in @(1000, 1001, 1002)) -or
          ($logName -like '*CodeIntegrity*' -and $_.id -in @(3033, 3077)))
      })
  }
  if ($crashes.Count -gt 0) { throw "Windows recorded $($crashes.Count) Lantern crash/hang or enforced code-integrity failure(s)" }
}

function Copy-LanternGuiLogs([string]$ArtifactDirectory) {
  $logDirectory = Split-Path (Get-LanternFlutterLogPath)
  if (Test-Path -LiteralPath $logDirectory) {
    Copy-Item -LiteralPath $logDirectory -Destination (Join-Path $ArtifactDirectory 'ui-logs') -Recurse -Force
  }
}
