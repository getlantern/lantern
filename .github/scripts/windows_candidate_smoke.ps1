param(
  [Parameter(Mandatory)][string]$InstallerPath,
  [Parameter(Mandatory)][string]$PayloadManifest,
  [Parameter(Mandatory)][int]$ExpectedBuild,
  [Parameter(Mandatory)][string]$ExpectedDisplay,
  [Parameter(Mandatory)][string]$ArtifactDirectory
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/windows_gui_health.ps1"

$appDirectory = 'C:\Program Files\Lantern'
$appExecutable = Join-Path $appDirectory 'lantern.exe'
if ($env:CI -ne 'true' -or $env:GITHUB_ACTIONS -ne 'true' -or
    $env:LANTERN_WINDOWS_CANDIDATE_SMOKE -ne 'true') {
  throw 'Candidate installation requires the explicit GitHub Actions smoke guard.'
}
if ((Test-Path -LiteralPath $appDirectory) -or (Get-Service LanternSvc -ErrorAction SilentlyContinue)) {
  throw 'Candidate smoke requires a clean runner without an existing Lantern installation.'
}
$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$manifest = (Resolve-Path -LiteralPath $PayloadManifest).Path
$null = New-Item -ItemType Directory -Path $ArtifactDirectory -Force

function Invoke-Installer([string]$Path, [string]$LogName) {
  $process = Start-Process -FilePath $Path -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    ('/LOG="{0}"' -f (Join-Path $ArtifactDirectory $LogName))
  ) -PassThru
  if (-not $process.WaitForExit(300000)) {
    & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Host
    throw "Installer timed out: $Path"
  }
  if ($process.ExitCode -ne 0) { throw "Installer exited with $($process.ExitCode): $Path" }
}

try {
  Invoke-Installer $installer 'installer.log'
  & "$PSScriptRoot/../../scripts/ci/windows-signing.ps1" -Action Verify `
    -Directory $appDirectory -ManifestPath $manifest -Installed
  $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($appExecutable)
  if (($version.ProductVersion -split '\+', 2)[0] -ne $ExpectedDisplay -or $version.FilePrivatePart -ne $ExpectedBuild) {
    throw "Installed executable is not the expected $ExpectedDisplay+$ExpectedBuild candidate"
  }
  # Launch the exact installed Release executable, including its normal updater.
  $launchedAt = [DateTime]::UtcNow
  $app = Start-Process -FilePath $appExecutable -WorkingDirectory $appDirectory -PassThru
  Wait-LanternGuiHealthy $app.Id $appExecutable
  Assert-LanternUpdaterStartup $launchedAt (Join-Path $ArtifactDirectory 'startup-flutter.log')
  Write-Host '[E2E] Installed candidate and updater survived 120 seconds of responsive GUI startup'
} finally {
  $logs = Split-Path (Get-LanternFlutterLogPath)
  if (Test-Path -LiteralPath $logs) {
    Copy-Item -LiteralPath $logs -Destination $ArtifactDirectory -Recurse -Force -ErrorAction Continue
  }
  Get-Process -Name lantern -ErrorAction SilentlyContinue | Where-Object Path -eq $appExecutable |
    Stop-Process -Force -ErrorAction SilentlyContinue
  $uninstaller = @(Get-ChildItem -LiteralPath $appDirectory -Filter 'unins*.exe' -File -ErrorAction SilentlyContinue)
  if ($uninstaller.Count -eq 1) { Invoke-Installer $uninstaller[0].FullName 'uninstaller.log' }
  if (Get-Service LanternSvc -ErrorAction SilentlyContinue) { throw 'Candidate cleanup left LanternSvc installed.' }
}
