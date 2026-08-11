$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$AppDirectory = 'C:\Program Files\Lantern'
$AppExecutable = Join-Path $AppDirectory 'lantern.exe'
$DataDirectory = 'C:\ProgramData\Lantern'
$HandoffPath = Join-Path $DataDirectory 'E2E\auto-update-handoff.json'
$FixtureInstaller = $env:FIXTURE_INSTALLER
$TargetJson = $env:TARGET_JSON
$AppcastXml = $env:APPCAST_XML
$ArtifactDirectory = if ($env:ARTIFACT_DIR) { $env:ARTIFACT_DIR } else { 'smoke-artifacts\windows-auto-update' }
$UiTimeoutSeconds = if ($env:UI_TIMEOUT_SECONDS) { [int]$env:UI_TIMEOUT_SECONDS } else { 120 }
$UpdateTimeoutSeconds = if ($env:UPDATE_TIMEOUT_SECONDS) { [int]$env:UPDATE_TIMEOUT_SECONDS } else { 600 }
$script:OriginalPid = 0
$script:RelaunchedPid = 0
$script:Result = 'failure'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Write-E2E([string]$Message) {
  Write-Host "[E2E] $Message"
}

function Assert-SmokeGuard {
  if ($env:CI -ne 'true' -or $env:GITHUB_ACTIONS -ne 'true') {
    throw 'This smoke only runs in GitHub Actions CI.'
  }
  if ($env:LANTERN_AUTO_UPDATE_SMOKE -ne 'true') {
    throw 'The explicit auto-update cleanup guard is missing.'
  }
  if ($AppDirectory -ne 'C:\Program Files\Lantern' -or $DataDirectory -ne 'C:\ProgramData\Lantern') {
    throw 'Refusing to use unexpected Lantern paths.'
  }
  foreach ($requiredPath in @($FixtureInstaller, $TargetJson, $AppcastXml)) {
    if ([string]::IsNullOrWhiteSpace($requiredPath) -or -not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
      throw "Required smoke input was not found: $requiredPath"
    }
  }
  if ($UiTimeoutSeconds -lt 1 -or $UpdateTimeoutSeconds -lt 1) {
    throw 'Update smoke timeouts must be positive integers.'
  }
}

function Get-LanternProcesses {
  @(Get-Process -Name 'lantern' -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -eq $AppExecutable } catch { $false }
    })
}

function Stop-LanternProcesses {
  foreach ($process in Get-LanternProcesses) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-ProcessAndWait {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [int]$TimeoutSeconds = 180,
    [Parameter(Mandatory = $true)][string]$Description
  )

  Write-E2E "${Description}: $FilePath $($ArgumentList -join ' ')"
  $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "$Description timed out after $TimeoutSeconds seconds"
  }
  if ($process.ExitCode -ne 0) {
    throw "$Description failed with exit code $($process.ExitCode)"
  }
}

function Remove-InstalledLantern {
  Assert-SmokeGuard
  Stop-LanternProcesses
  $uninstaller = Get-ChildItem -LiteralPath $AppDirectory -Filter 'unins*.exe' -File -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object -First 1
  if ($uninstaller) {
    Invoke-ProcessAndWait `
      -FilePath $uninstaller.FullName `
      -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-') `
      -Description 'Uninstalling the existing Lantern fixture'
  } elseif (Test-Path -LiteralPath (Join-Path $AppDirectory 'lanternd.exe')) {
    & (Join-Path $AppDirectory 'lanternd.exe') uninstall 2>&1 | Out-Null
  }
  if (Test-Path -LiteralPath $AppDirectory) {
    Remove-Item -LiteralPath $AppDirectory -Recurse -Force
  }
  if (Test-Path -LiteralPath $DataDirectory) {
    Remove-Item -LiteralPath $DataDirectory -Recurse -Force
  }
}

function Save-Screenshot([string]$Name) {
  try {
    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
      $bitmap.Save((Join-Path $ArtifactDirectory "$Name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  } catch {
    $_ | Out-String | Set-Content (Join-Path $ArtifactDirectory "$Name-screenshot-error.txt")
  }
}

function Save-Processes([string]$Name) {
  Get-CimInstance Win32_Process |
    Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine |
    Format-List |
    Out-String -Width 4096 |
    Set-Content (Join-Path $ArtifactDirectory "processes-$Name.txt")
}

function Get-AppVersion {
  if (-not (Test-Path -LiteralPath $AppExecutable -PathType Leaf)) {
    throw "Lantern executable was not found: $AppExecutable"
  }
  $version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($AppExecutable)
  [pscustomobject]@{
    DisplayVersion = $version.ProductVersion
    BuildNumber = $version.FilePrivatePart
    FileVersion = $version.FileVersion
    ProductVersion = $version.ProductVersion
  }
}

function Test-InstalledAppVersion {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][int]$ExpectedBuild,
    [Parameter(Mandatory = $true)][string]$ExpectedDisplay
  )
  $version = Save-AppVersion $Name
  $signature = Get-AuthenticodeSignature -LiteralPath $AppExecutable
  Add-Content (Join-Path $ArtifactDirectory "versions-$Name.txt") @(
    "authenticode_status=$($signature.Status)"
    "authenticode_subject=$($signature.SignerCertificate.Subject)"
  )
  if ($version.DisplayVersion -ne $ExpectedDisplay) {
    throw "$Name display version $($version.DisplayVersion) did not match $ExpectedDisplay"
  }
  if ($version.BuildNumber -ne $ExpectedBuild) {
    throw "$Name build $($version.BuildNumber) did not match $ExpectedBuild"
  }
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "$Name Authenticode signature is $($signature.Status)"
  }
}

function Save-AppVersion([string]$Name) {
  $version = Get-AppVersion
  @(
    "display_version=$($version.DisplayVersion)"
    "build_number=$($version.BuildNumber)"
    "file_version=$($version.FileVersion)"
    "product_version=$($version.ProductVersion)"
  ) | Set-Content (Join-Path $ArtifactDirectory "versions-$Name.txt")
  return $version
}

function Get-TopLevelWindows {
  $condition = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
    [System.Windows.Automation.TreeScope]::Children,
    $condition
  )
}

function Find-Window {
  param([string[]]$Names)
  foreach ($window in Get-TopLevelWindows) {
    if ($Names -contains $window.Current.Name) {
      return $window
    }
  }
  return $null
}

function Find-Button {
  param(
    [Parameter(Mandatory = $true)][System.Windows.Automation.AutomationElement]$Window,
    [Parameter(Mandatory = $true)][string[]]$Names
  )
  $condition = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Button
  )
  foreach ($button in $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)) {
    $name = $button.Current.Name.Replace('&', '')
    if ($button.Current.IsEnabled -and $Names -contains $name) {
      return $button
    }
  }
  return $null
}

function Invoke-Button([System.Windows.Automation.AutomationElement]$Button) {
  $pattern = $null
  if (-not $Button.TryGetCurrentPattern(
      [System.Windows.Automation.InvokePattern]::Pattern,
      [ref]$pattern
    )) {
    throw "Button '$($Button.Current.Name)' does not support InvokePattern"
  }
  Write-E2E "pressing $($Button.Current.Name)"
  ([System.Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Save-UiTree([string]$Name) {
  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($window in Get-TopLevelWindows) {
    $lines.Add("WINDOW name='$($window.Current.Name)' pid=$($window.Current.ProcessId)")
    $condition = [System.Windows.Automation.PropertyCondition]::new(
      [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
      [System.Windows.Automation.ControlType]::Button
    )
    foreach ($button in $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)) {
      $lines.Add("  BUTTON name='$($button.Current.Name)' enabled=$($button.Current.IsEnabled)")
    }
  }
  $lines | Set-Content (Join-Path $ArtifactDirectory "ui-$Name.txt")
}

function Wait-ForWinSparklePrompt {
  $deadline = [DateTime]::UtcNow.AddSeconds($UiTimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $window = Find-Window @('Software Update')
    if ($window) {
      $button = Find-Button $window @('Install update', 'Get update')
      if ($button) { return $button }
    }
    Start-Sleep -Milliseconds 250
  }
  Save-UiTree 'prompt-timeout'
  throw 'WinSparkle update prompt did not appear before timeout'
}

function Install-ThroughNativeUi {
  $deadline = [DateTime]::UtcNow.AddSeconds($UpdateTimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $lantern = Get-Process -Id $script:OriginalPid -ErrorAction SilentlyContinue
    if ($lantern) {
      $sparkle = Find-Window @('Software Update')
      if ($sparkle) {
        $button = Find-Button $sparkle @('Install update', 'Get update', 'Run installer')
        if ($button) {
          Invoke-Button $button
          Start-Sleep -Milliseconds 500
          continue
        }
      }
    }

    $installer = Find-Window @('Setup - Lantern', 'Lantern Setup')
    if ($installer) {
      $button = Find-Button $installer @('Next >', 'Install', 'Finish')
      if ($button) {
        Invoke-Button $button
        Start-Sleep -Milliseconds 500
        continue
      }
    }

    if (-not $lantern) {
      $newProcess = Get-LanternProcesses | Where-Object { $_.Id -ne $script:OriginalPid } | Select-Object -First 1
      if ($newProcess) { return $newProcess }
    }
    Start-Sleep -Milliseconds 250
  }
  Save-UiTree 'install-timeout'
  throw 'The Windows update did not install and relaunch before timeout'
}

function Wait-ForMainWindow([int]$ProcessId) {
  $deadline = [DateTime]::UtcNow.AddSeconds($UiTimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($process) {
      $process.Refresh()
      if ($process.MainWindowHandle -ne 0) { return }
    }
    Start-Sleep -Milliseconds 250
  }
  Save-UiTree 'main-window-timeout'
  throw "Lantern process $ProcessId did not expose a main window before timeout"
}

function Save-Diagnostics {
  New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null
  @(
    "result=$script:Result"
    "original_pid=$script:OriginalPid"
    "relaunched_pid=$script:RelaunchedPid"
  ) | Set-Content (Join-Path $ArtifactDirectory 'result.txt')
  Save-Processes 'final'
  Save-UiTree 'final'
  if (Test-Path -LiteralPath $AppExecutable) {
    try { Save-AppVersion 'final' | Out-Null } catch {}
  }
  $logDirectory = Join-Path $DataDirectory 'Logs'
  if (Test-Path -LiteralPath $logDirectory) {
    Copy-Item -LiteralPath $logDirectory -Destination (Join-Path $ArtifactDirectory 'lantern-logs') -Recurse -Force
  }
  Get-ChildItem -Path $env:TEMP -Filter 'Update-*' -Directory -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime |
    Format-Table -AutoSize |
    Out-String -Width 4096 |
    Set-Content (Join-Path $ArtifactDirectory 'sparkle-files.txt')
}

Assert-SmokeGuard
New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null
Copy-Item -LiteralPath $AppcastXml -Destination (Join-Path $ArtifactDirectory 'appcast.xml')
Copy-Item -LiteralPath $TargetJson -Destination (Join-Path $ArtifactDirectory 'resolved-target.json')
$target = Get-Content -LiteralPath $TargetJson -Raw | ConvertFrom-Json
$targetBuild = [int]$target.target_build
$fixtureBuild = [int]$target.fixture_build
$displayVersion = [string]$target.display_version
$recheckDirectory = Join-Path $ArtifactDirectory 'live-recheck'
New-Item -ItemType Directory -Path $recheckDirectory -Force | Out-Null
& python scripts/ci/resolve_desktop_update_target.py `
  --platform windows `
  --appcast-url ([string]$target.appcast_url) `
  --appcast-output (Join-Path $recheckDirectory 'appcast.xml') `
  --target-output (Join-Path $recheckDirectory 'target.json') `
  --pubspec-input pubspec.yaml `
  --pubspec-output (Join-Path $recheckDirectory 'pubspec.yaml')
if ($LASTEXITCODE -ne 0) { throw 'Unable to revalidate the live Windows beta target.' }
$recheckedTarget = Get-Content -LiteralPath (Join-Path $recheckDirectory 'target.json') -Raw | ConvertFrom-Json
if ($recheckedTarget.appcast_sha256 -ne $target.appcast_sha256) {
  throw 'The staging beta appcast changed while the fixture was building; rerun the workflow.'
}

try {
  Remove-InstalledLantern
  Invoke-ProcessAndWait `
    -FilePath $FixtureInstaller `
    -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-') `
    -Description 'Installing lower Lantern fixture'
  Test-InstalledAppVersion -Name 'fixture' -ExpectedBuild $fixtureBuild -ExpectedDisplay $displayVersion
  Save-Screenshot 'before'

  Write-E2E 'running the Flutter auto-update robot against the installed fixture'
  $driveArguments = @(
    'drive', '--profile', "--use-application-binary=$AppExecutable", '--keep-app-running',
    '--driver=test_driver/integration_test.dart',
    '--target=integration_test/auto_update/desktop_auto_update_smoke_test.dart',
    '--device-id=windows'
  )
  & flutter @driveArguments *>&1 | Tee-Object -FilePath (Join-Path $ArtifactDirectory 'flutter-drive.log')
  if ($LASTEXITCODE -ne 0) { throw "Flutter auto-update robot failed with exit code $LASTEXITCODE" }
  if (-not (Test-Path -LiteralPath $HandoffPath -PathType Leaf)) {
    throw 'Flutter test completed without creating its native handoff.'
  }
  Copy-Item -LiteralPath $HandoffPath -Destination (Join-Path $ArtifactDirectory 'auto-update-handoff.json')
  $handoff = Get-Content -LiteralPath $HandoffPath -Raw | ConvertFrom-Json
  $script:OriginalPid = [int]$handoff.pid
  if ([string]$handoff.build_number -ne [string]$fixtureBuild -or
      [string]$handoff.display_version -ne $displayVersion) {
    throw 'Flutter test ran against the wrong fixture version.'
  }
  $original = Get-Process -Id $script:OriginalPid -ErrorAction Stop
  if ($original.Path -ne $AppExecutable) {
    throw "Flutter handoff PID $script:OriginalPid is not the installed Lantern app"
  }

  Save-Processes 'prompt'
  $installButton = Wait-ForWinSparklePrompt
  Save-UiTree 'prompt'
  Save-Screenshot 'prompt'
  Invoke-Button $installButton
  $relaunched = Install-ThroughNativeUi
  $script:RelaunchedPid = $relaunched.Id
  if (Get-Process -Id $script:OriginalPid -ErrorAction SilentlyContinue) {
    throw 'Original Lantern process is still running after WinSparkle completed.'
  }
  Wait-ForMainWindow $script:RelaunchedPid
  Test-InstalledAppVersion -Name 'updated' -ExpectedBuild $targetBuild -ExpectedDisplay $displayVersion
  Save-Processes 'after'
  Save-Screenshot 'after'
  $script:Result = 'success'
  Write-E2E "auto-update smoke passed: build $fixtureBuild -> $targetBuild"
} finally {
  try { Save-Diagnostics } catch { Write-Warning "Unable to save all diagnostics: $_" }
  try { Save-Screenshot 'final' } catch { Write-Warning "Unable to save final screenshot: $_" }
  try { Remove-InstalledLantern } catch { Write-Warning "Unable to clean up Lantern fixture: $_" }
}
