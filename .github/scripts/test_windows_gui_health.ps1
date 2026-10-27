$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/windows_gui_health.ps1"

function Assert-Throws([scriptblock]$Action, [string]$Expected) {
  try { & $Action } catch {
    if ($_.Exception.Message -notlike "*$Expected*") { throw }
    return
  }
  throw "Expected failure containing: $Expected"
}

function Invoke-MonitorCase([scriptblock]$AlterSample = {}) {
  $clock = @{ seconds = 0; ready = 0 }
  $origin = [DateTime]::new(2026, 10, 26, 0, 0, 0, [DateTimeKind]::Utc)
  Invoke-GuiHealthMonitor -ExpectedProcessId 123 -ExpectedPath 'C:\Lantern\lantern.exe' `
    -DurationSeconds 120 -WindowTimeoutSeconds 10 `
    -Now { $origin.AddSeconds($clock.seconds) } `
    -Pause { $clock.seconds++ } `
    -OnReady { $clock.ready++ } `
    -Probe {
      $sample = [pscustomobject]@{
        ProcessId = 123; Path = 'C:\Lantern\lantern.exe'; StartTimeTicks = 100
        HasWindow = $true; Responding = $true
      }
      & $AlterSample $sample $clock.seconds
      $sample
    }
  if ($clock.seconds -lt 120 -or $clock.ready -ne 1) { throw 'Monitor passed without the full observation window' }
  $clock
}

$null = Invoke-MonitorCase
Assert-Throws { Invoke-MonitorCase { param($sample, $second); if ($second -eq 6) { $sample.ProcessId = 0 } } } 'exited or was replaced'
Assert-Throws { Invoke-MonitorCase { param($sample, $second); if ($second -eq 25) { $sample.StartTimeTicks = 200 } } } 'was reused'
Assert-Throws { Invoke-MonitorCase { param($sample, $second); if ($second -eq 119) { $sample.Responding = $false } } } 'stopped responding'
Assert-Throws { Invoke-MonitorCase { param($sample, $second); if ($second -eq 120) { $sample.HasWindow = $false } } } 'lost its window'
Assert-Throws { Invoke-MonitorCase { param($sample, $second); $sample.HasWindow = $false } } 'did not show a responsive window'
Assert-Throws { Invoke-MonitorCase { param($sample, $second); $sample.Path = 'C:\Other\lantern.exe' } } 'exited or was replaced'
$delayed = Invoke-MonitorCase { param($sample, $second); $sample.HasWindow = $second -ge 5 }
if ($delayed.seconds -ne 125) { throw 'Window startup delay shortened the stability observation' }
Assert-Throws {
  Invoke-GuiHealthMonitor -ExpectedProcessId 123 -ExpectedPath 'C:\Lantern\lantern.exe' -Probe { $null }
} 'exited or was replaced'

$temporary = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
  $log = Join-Path $temporary 'flutter.log'
  $output = Join-Path $temporary 'startup.log'
  $started = [DateTime]::Parse('2026-10-26T10:00:00Z').ToUniversalTime()
  @(
    'time="2026-10-26 09:00:00.000 UTC" level=INFO message=autoUpdater configured. buildType=beta'
    'time="2026-10-26 09:00:00.001 UTC" level=INFO message=Desktop update check: source=startup url=example'
  ) | Set-Content $log
  Assert-Throws { Assert-LanternUpdaterStartup $log $started $output } 'did not configure'
  'time="2026-10-26 10:00:05.000 UTC" level=INFO message=autoUpdater configured. buildType=beta' | Add-Content $log
  Assert-Throws { Assert-LanternUpdaterStartup $log $started $output } 'did not configure'
  'time="2026-10-26 10:00:05.001 UTC" level=INFO message=Desktop update check: source=manual url=example' | Add-Content $log
  Assert-Throws { Assert-LanternUpdaterStartup $log $started $output } 'did not configure'
  'time="2026-10-26 10:00:05.002 UTC" level=INFO message=Desktop update check: source=startup url=example' | Add-Content $log
  Assert-LanternUpdaterStartup $log $started $output

  # Exercise real event filtering/serialization with simulated Windows records.
  # An unrelated application crash and a Code Integrity audit are not failures.
  function New-FixtureEvent([int]$EventId, [string]$Application) {
    $event = [pscustomobject]@{
      TimeCreated = $started; Id = $EventId; ProviderName = 'Fixture'; Message = "Event for $Application"
      Application = $Application
    }
    $event | Add-Member -MemberType ScriptMethod -Name ToXml -Value {
      "<Event><EventData><Data>$($this.Application)</Data></EventData></Event>"
    }
    $event
  }
  $script:fixtureEvents = @{ Application = @(New-FixtureEvent 1000 'unrelated.exe') }
  $script:fixtureEvents['Microsoft-Windows-CodeIntegrity/Operational'] = @(New-FixtureEvent 3076 'C:\Lantern\plugin.dll')
  function Get-WinEvent {
    param([hashtable]$FilterHashtable, [string]$ErrorAction)
    if ($script:fixtureEvents.ContainsKey($FilterHashtable.LogName)) {
      $script:fixtureEvents[$FilterHashtable.LogName]
    }
  }
  Export-LanternWindowsEvents $started $temporary 'C:\Lantern'
  $script:fixtureEvents.Application = @(New-FixtureEvent 1000 'lantern.exe')
  Assert-Throws { Export-LanternWindowsEvents $started $temporary 'C:\Lantern' } 'crash/hang'
  $script:fixtureEvents.Application = @()
  $script:fixtureEvents['Microsoft-Windows-CodeIntegrity/Operational'] = @(New-FixtureEvent 3077 'C:\Lantern\plugin.dll')
  Assert-Throws { Export-LanternWindowsEvents $started $temporary 'C:\Lantern' } 'code-integrity'
  if (-not (Test-Path (Join-Path $temporary 'events-CodeIntegrity-Operational.json'))) {
    throw 'Code Integrity evidence was not saved before the failure'
  }
  function Get-WinEvent { throw 'Event log query failed' }
  Assert-Throws { Export-LanternWindowsEvents $started $temporary 'C:\Lantern' } 'Event log query failed'
} finally { Remove-Item -LiteralPath $temporary -Recurse -Force }
Write-Host 'PASS: GUI crash, hang, identity, window timing, fresh updater-startup and crash-event regression cases'
