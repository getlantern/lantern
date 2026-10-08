$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptPath = Join-Path $PSScriptRoot 'windows_arm_smoke.ps1'
$ast = $null
$suiteAst = $null
foreach ($path in @($scriptPath, (Join-Path $PSScriptRoot 'windows_smoke_suite.ps1'))) {
  $errors = $null
  $parsed = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
  if ($errors.Count) { throw ($errors | Out-String) }
  if ($path -eq $scriptPath) { $ast = $parsed }
  else { $suiteAst = $parsed }
}

# Import only pure helpers. Parsing this file must never install or uninstall anything.
foreach ($name in @('Get-PeMachine', 'Get-ServiceExecutablePath')) {
  $function = $ast.Find({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
  if (-not $function) { throw "Missing smoke helper: $name" }
  Invoke-Expression $function.Extent.Text
}

function Assert-Equal($Actual, $Expected) {
  if ($Actual -ne $Expected) { throw "Expected '$Expected', got '$Actual'" }
}

function Assert-Rejected([scriptblock]$Action) {
  $rejected = $false
  try { & $Action | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw "Invalid fixture was accepted: $Action" }
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) "lantern-arm-smoke-test-$([guid]::NewGuid())"
New-Item -ItemType Directory $temporary | Out-Null
try {
  $path = Join-Path $temporary 'service.exe'
  $bytes = [byte[]]::new(256)
  $bytes[0] = 0x4D
  $bytes[1] = 0x5A
  [BitConverter]::GetBytes([uint32]128).CopyTo($bytes, 0x3C)
  [BitConverter]::GetBytes([uint32]0x4550).CopyTo($bytes, 128)
  foreach ($machine in @(0xAA64, 0x8664)) {
    [BitConverter]::GetBytes([uint16]$machine).CopyTo($bytes, 132)
    [System.IO.File]::WriteAllBytes($path, $bytes)
    Assert-Equal (Get-PeMachine $path) $machine
  }
  foreach ($offset in @(0, 255, [uint32]::MaxValue)) {
    [BitConverter]::GetBytes([uint32]$offset).CopyTo($bytes, 0x3C)
    [System.IO.File]::WriteAllBytes($path, $bytes)
    Assert-Rejected { Get-PeMachine $path }
  }
  [System.IO.File]::WriteAllBytes($path, [byte[]]::new(12))
  Assert-Rejected { Get-PeMachine $path }
  [BitConverter]::GetBytes([uint32]128).CopyTo($bytes, 0x3C)
  $bytes[128] = 0
  [System.IO.File]::WriteAllBytes($path, $bytes)
  Assert-Rejected { Get-PeMachine $path }

  Assert-Equal (Get-ServiceExecutablePath '"C:\Program Files\Lantern\LanternSvc.exe" service') 'C:\Program Files\Lantern\LanternSvc.exe'
  Assert-Equal (Get-ServiceExecutablePath 'C:\Lantern\service.exe --environment prod') 'C:\Lantern\service.exe'
  Assert-Rejected { Get-ServiceExecutablePath 'C:\Program Files\Lantern\LanternSvc.exe service' }
  Assert-Rejected { Get-ServiceExecutablePath '"C:\Lantern\service.exe' }

  $install = $suiteAst.Find({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Install-FromInstaller'
    }, $true)
  Invoke-Expression $install.Extent.Text
  $InstallerTimeoutSeconds = 1
  $HeartbeatSeconds = 1
  $script:ManualInstall = $false
  $script:ReachedWait = $false
  function Invoke-ProcessWithTimeout { }
  function Write-Step { }
  function Show-LanterndInstallDiagnostics { }
  function Get-Service { return $null }
  function Invoke-LanterndCommand { $script:ManualInstall = $true }
  function Wait-ServiceRunning { $script:ReachedWait = $true }
  Assert-Rejected { Install-FromInstaller -Path $path -TimeoutSeconds 1 -Name 'LanternSvc' }
  Assert-Equal $script:ManualInstall $false
  Assert-Equal $script:ReachedWait $false
  Write-Host 'ARM smoke script syntax, PE validation and service paths passed'
} finally {
  Remove-Item $temporary -Recurse -Force
}
