function Wait-LanternGuiHealthy([int]$ProcessId, [string]$AppExecutable) {
  $process = Get-Process -Id $ProcessId -ErrorAction Stop
  $null = $process.Handle
  if ($process.Path -ne $AppExecutable) { throw 'Unexpected Lantern GUI executable' }
  $windowDeadline = [DateTime]::UtcNow.AddSeconds(120)
  $healthySince = $null
  while ($true) {
    $process.Refresh()
    if ($process.HasExited) { throw "Lantern GUI exited: $($process.ExitCode)" }
    $healthy = $process.MainWindowHandle -ne 0 -and $process.Responding
    if ($null -ne $healthySince -and -not $healthy) { throw 'Lantern GUI lost its window or stopped responding' }
    if ($null -eq $healthySince) {
      if ($healthy) { $healthySince = [DateTime]::UtcNow }
      elseif ([DateTime]::UtcNow -ge $windowDeadline) { throw 'Lantern GUI did not show a responsive window' }
    }
    # The reported updater crash is delayed until after normal startup.
    if ($null -ne $healthySince -and ([DateTime]::UtcNow - $healthySince).TotalSeconds -ge 120) { return }
    Start-Sleep -Seconds 1
  }
}

function Get-LanternFlutterLogPath {
  Join-Path $env:PUBLIC 'Lantern/logs/flutter.log'
}

function Assert-LanternUpdaterStartup([DateTime]$StartedAt, [string]$OutputPath, [switch]$ConfigurationOnly) {
  # Filter by the logger's UTC timestamp so an older launch cannot pass this check.
  $lines = @(Get-Content -LiteralPath (Get-LanternFlutterLogPath) | Where-Object {
    if ($_ -match '^time="(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}) UTC"') {
      $time = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss.fff',
        [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
      $time.ToUniversalTime() -ge $StartedAt.ToUniversalTime()
    } else { $false }
  })
  $lines | Where-Object { $_ -match 'message=(autoUpdater|Desktop update|WinSparkle)' } |
    Set-Content -LiteralPath $OutputPath
  if (-not ($lines -match 'message=autoUpdater configured\.')) {
    throw 'This launch did not configure the native updater'
  }
  if (-not $ConfigurationOnly -and -not ($lines -match 'message=Desktop update check: source=startup(?:\s|$)')) {
    throw 'This launch did not start its normal startup update check'
  }
}
