param(
  [Parameter(Mandatory)][string]$InstallerPath,
  [Parameter(Mandatory)][string]$PayloadManifest,
  [Parameter(Mandatory)][int]$ExpectedBuild,
  [Parameter(Mandatory)][string]$ExpectedDisplay,
  [Parameter(Mandatory)][string]$ArtifactDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/windows_gui_health.ps1"

# Installation changes services and machine-wide files. This gate runs only on
# a disposable Actions runner, and refuses to replace an existing installation.
if ($env:CI -ne 'true' -or $env:GITHUB_ACTIONS -ne 'true' -or
    $env:LANTERN_WINDOWS_CANDIDATE_SMOKE -ne 'true') {
  throw 'Candidate installation requires the explicit GitHub Actions smoke guard.'
}
$appDirectory = 'C:\Program Files\Lantern'
$appExecutable = Join-Path $appDirectory 'lantern.exe'
if ((Test-Path -LiteralPath $appDirectory) -or
    (Get-Service -Name LanternSvc -ErrorAction SilentlyContinue)) {
  throw 'Candidate smoke requires a clean runner without an existing Lantern installation.'
}
$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$manifest = (Resolve-Path -LiteralPath $PayloadManifest).Path
New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null
$artifacts = (Resolve-Path -LiteralPath $ArtifactDirectory).Path
$installerLog = Join-Path $artifacts 'installer.log'
$failure = $null
$installationStarted = $false
$startedAt = [DateTime]::UtcNow

function Invoke-CandidateInstaller {
  param([string]$Path, [string]$LogPath)
  $process = Start-Process -FilePath $Path -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
    ('/LOG="{0}"' -f $LogPath)
  ) -PassThru
  if (-not $process.WaitForExit(300000)) {
    # Inno launches a temporary child executable. Stop the tree before cleanup
    # so a timed-out child cannot keep installing alongside the uninstaller.
    & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Host
    throw "Installer timed out: $Path"
  }
  if ($process.ExitCode -ne 0) {
    throw "Installer failed with exit code $($process.ExitCode): $Path (see $LogPath)"
  }
}

try {
  $signature = Get-AuthenticodeSignature -LiteralPath $installer
  if ($signature.Status -ne 'Valid') {
    throw "Candidate installer signature is not valid: $($signature.Status)"
  }
  Copy-Item -LiteralPath $manifest -Destination (Join-Path $artifacts 'signed-payload.json')
  [ordered]@{
    source_commit = $env:GITHUB_SHA
    source_ref = $env:GITHUB_REF
    run_id = $env:GITHUB_RUN_ID
    installer = $installer
    installer_sha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
    payload_manifest_sha256 = (Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash
    expected_display = $ExpectedDisplay
    expected_build = $ExpectedBuild
    signer = $signature.SignerCertificate.Subject
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifacts 'candidate.json') -Encoding utf8

  $installationStarted = $true
  Invoke-CandidateInstaller -Path $installer -LogPath $installerLog
  & (Join-Path $PSScriptRoot '../../scripts/ci/verify-windows-payload.ps1') `
    -Directory $appDirectory -ManifestPath $manifest -Installed

  $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($appExecutable)
  if (($version.ProductVersion -split '\+', 2)[0] -ne $ExpectedDisplay -or $version.FilePrivatePart -ne $ExpectedBuild) {
    throw "Installed executable is not the expected $ExpectedDisplay+$ExpectedBuild candidate"
  }
  $existing = @(Get-Process -Name lantern -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $appExecutable })
  if ($existing.Count -ne 0) { throw 'Candidate startup requires a fresh normal launch' }

  # This launches the installed Release executable, never a rebuilt Flutter
  # integration-test entrypoint. Its normal updater startup must run as well.
  $launchedAt = [DateTime]::UtcNow
  $appProcess = Start-Process -FilePath $appExecutable -WorkingDirectory $appDirectory -PassThru
  Wait-LanternGuiHealthy -ProcessId $appProcess.Id -AppExecutable $appExecutable `
    -ArtifactDirectory $artifacts -Phase 'startup'
  Assert-LanternUpdaterStartup -LogPath (Get-LanternFlutterLogPath) -StartedAt $launchedAt `
    -OutputPath (Join-Path $artifacts 'startup-flutter.log')
} catch {
  $failure = $_
} finally {
  try {
    Copy-LanternGuiLogs $artifacts
    $serviceLogs = 'C:\ProgramData\Lantern\logs'
    if (Test-Path -LiteralPath $serviceLogs) {
      Copy-Item -LiteralPath $serviceLogs -Destination (Join-Path $artifacts 'service-logs') -Recurse -Force
    }
  } catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $artifacts 'log-collection-error.txt') -Encoding utf8
    if ($null -eq $failure) { $failure = $_ }
  }
  try { Export-LanternWindowsEvents $startedAt $artifacts $appDirectory } catch {
    if ($null -eq $failure) { $failure = $_ }
  }
  try {
    if ($installationStarted -and (Test-Path -LiteralPath $appDirectory)) {
      Get-Process -Name lantern -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -eq $appExecutable } catch { $false }
      } | Stop-Process -Force -ErrorAction SilentlyContinue
      $uninstallers = @(Get-ChildItem -LiteralPath $appDirectory -Filter 'unins*.exe' -File)
      if ($uninstallers.Count -ne 1) {
        throw 'Candidate installation did not leave exactly one uninstaller; runner requires cleanup.'
      }
      Invoke-CandidateInstaller -Path $uninstallers[0].FullName -LogPath (Join-Path $artifacts 'uninstaller.log')
      if (Get-Service -Name LanternSvc -ErrorAction SilentlyContinue) {
        throw 'Candidate cleanup left LanternSvc installed.'
      }
    }
  } catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $artifacts 'cleanup-failure.txt') -Encoding utf8
    if ($null -eq $failure) { $failure = $_ }
  } finally {
    @{
      result = if ($null -eq $failure) { 'success' } else { 'failure' }
      expected_build = $ExpectedBuild
    } |
      ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifacts 'result.json') -Encoding utf8
  }
}
if ($null -ne $failure) {
  $failure | Out-String | Set-Content -LiteralPath (Join-Path $artifacts 'failure.txt') -Encoding utf8
  throw $failure
}
Write-Host '[E2E] exact installed candidate survived normal startup with its updater active for 120s'
