param([switch]$ShowDialog)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
if ($ShowDialog) {
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $dialog = [System.Windows.Forms.OpenFileDialog]::new()
  try {
    $dialog.AutoUpgradeEnabled = $true
    $dialog.Filter = 'Windows executable|*.exe'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
      throw 'Native picker was cancelled'
    }
    [Console]::WriteLine($dialog.FileName)
  } finally { $dialog.Dispose() }
  exit 0
}

$directory = Join-Path ([IO.Path]::GetTempPath()) "lantern-picker-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $directory | Out-Null
$hostProcess = $null
try {
  $fixture = Join-Path $directory ("Game $([char]0x904a)$([char]0x6232).exe")
  # Selection does not execute the file; an empty fixture is sufficient.
  [IO.File]::WriteAllBytes($fixture, [byte[]]@())
  $stdout = Join-Path $directory 'stdout.txt'
  $stderr = Join-Path $directory 'stderr.txt'
  $hostProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'Bypass',
    '-File', "`"$PSCommandPath`"", '-ShowDialog'
  ) -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  $null = $hostProcess.Handle
  $selection = & (Join-Path $PSScriptRoot 'windows-select-file.ps1') -AppProcessId $hostProcess.Id -FilePath $fixture
  if (-not $hostProcess.WaitForExit(5000)) { throw 'Native picker host did not exit' }
  if ($hostProcess.ExitCode -ne 0) { throw "Native picker failed: $(Get-Content -LiteralPath $stderr -Raw)" }
  $selectedPath = (Get-Content -LiteralPath $stdout -Raw -Encoding utf8).Trim()
  $selection = $selection | ConvertFrom-Json
  if ($selectedPath -ne $fixture -or $selection.path -ne $fixture) {
    throw "Native picker returned an unexpected path: $selectedPath"
  }
  Write-Host "Native executable picker passed (Unicode path, $($selection.openControlType))"
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
