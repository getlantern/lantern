param([switch]$ShowDialog, [switch]$ClassicDialog)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
if ($ShowDialog) {
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $dialog = [System.Windows.Forms.OpenFileDialog]::new()
  try {
    $dialog.AutoUpgradeEnabled = -not $ClassicDialog
    $dialog.Filter = 'Windows executable|*.exe'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
      throw 'Native picker was cancelled'
    }
    [Console]::WriteLine($dialog.FileName)
  } finally { $dialog.Dispose() }
  exit 0
}

Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
using System.Text;
public static class LanternPickerFixtureNative {
  [DllImport("kernel32.dll", EntryPoint = "GetLongPathNameW", CharSet = CharSet.Unicode)]
  public static extern uint GetLongPathName(string path, StringBuilder output, uint length);
}
'@

$tempPath = [Text.StringBuilder]::new(32768)
$tempPathLength = [LanternPickerFixtureNative]::GetLongPathName([IO.Path]::GetTempPath(), $tempPath, $tempPath.Capacity)
if ($tempPathLength -eq 0 -or $tempPathLength -ge $tempPath.Capacity) { throw 'Could not expand the fixture temp path' }
$directory = Join-Path ($tempPath.ToString()) "lantern-picker-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $directory | Out-Null
$hostProcess = $null
try {
  $fixture = Join-Path $directory ("Game $([char]0x904a)$([char]0x6232).exe")
  # Selection does not execute the file; an empty fixture is sufficient.
  [IO.File]::WriteAllBytes($fixture, [byte[]]@())
  $stdout = Join-Path $directory 'stdout.txt'
  $stderr = Join-Path $directory 'stderr.txt'
  foreach ($classic in @($false, $true)) {
    $arguments = @(
      '-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'Bypass',
      '-File', "`"$PSCommandPath`"", '-ShowDialog'
    )
    if ($classic) { $arguments += '-ClassicDialog' }
    $hostProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $hostProcess.Handle
    $selection = & (Join-Path $PSScriptRoot 'windows-select-file.ps1') -AppProcessId $hostProcess.Id -FilePath $fixture
    if (-not $hostProcess.WaitForExit(5000)) { throw 'Native picker host did not exit' }
    if ($hostProcess.ExitCode -ne 0) { throw "Native picker failed: $(Get-Content -LiteralPath $stderr -Raw)" }
    $selectedPath = (Get-Content -LiteralPath $stdout -Raw -Encoding utf8).Trim()
    $selection = $selection | ConvertFrom-Json
    if ($selectedPath -ne $fixture -or $selection.path -ne $fixture) {
      throw "Native picker returned an unexpected path: $selectedPath"
    }
    Write-Host "Native executable picker passed (Unicode path, classic=$classic, $($selection.openControlType))"
    $hostProcess.Dispose()
    $hostProcess = $null
  }
} finally {
  if ($hostProcess) {
    if (-not $hostProcess.HasExited) {
      Stop-Process -InputObject $hostProcess -Force
      $null = $hostProcess.WaitForExit(5000)
    }
    $hostProcess.Dispose()
  }
  Remove-Item -LiteralPath $directory -Recurse -Force
}
