$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$AppDirectory = 'C:\Program Files\Lantern'
$AppExecutable = Join-Path $AppDirectory 'lantern.exe'
$DataDirectory = 'C:\ProgramData\Lantern'
$HandoffPath = Join-Path $DataDirectory 'E2E\auto-update-handoff.json'
$FixtureDirectory = $env:FIXTURE_APP_DIR
$TargetJson = $env:TARGET_JSON
$AppcastXml = $env:APPCAST_XML
$ArtifactDirectory = $env:ARTIFACT_DIR
$UiTimeout = if ($env:UI_TIMEOUT_SECONDS) { [int]$env:UI_TIMEOUT_SECONDS } else { 120 }
$UpdateTimeout = if ($env:UPDATE_TIMEOUT_SECONDS) { [int]$env:UPDATE_TIMEOUT_SECONDS } else { 600 }
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
  if ($env:CI -ne 'true' -or $env:GITHUB_ACTIONS -ne 'true' -or
      $env:LANTERN_AUTO_UPDATE_SMOKE -ne 'true') {
    throw 'This destructive smoke requires its explicit GitHub Actions guard.'
  }
  if ($AppDirectory -ne 'C:\Program Files\Lantern' -or
      $DataDirectory -ne 'C:\ProgramData\Lantern') {
    throw 'Refusing to use unexpected Lantern paths.'
  }
  foreach ($path in @($TargetJson, $AppcastXml)) {
    if ([string]::IsNullOrWhiteSpace($path) -or
        -not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Required smoke input was not found: $path"
    }
  }
  if ([string]::IsNullOrWhiteSpace($FixtureDirectory) -or
      -not (Test-Path -LiteralPath $FixtureDirectory -PathType Container) -or
      -not (Test-Path -LiteralPath (Join-Path $FixtureDirectory 'lantern.exe') -PathType Leaf)) {
    throw "Signed fixture app was not found: $FixtureDirectory"
  }
  if ([string]::IsNullOrWhiteSpace($ArtifactDirectory) -or
      $UiTimeout -lt 1 -or $UpdateTimeout -lt 1) {
    throw 'Artifact directory and positive timeouts are required.'
  }
}

function Get-LanternProcesses {
  @(Get-Process -Name lantern -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -eq $AppExecutable } catch { $false }
    })
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @(),
    [Parameter(Mandatory = $true)][string]$Description,
    [int]$TimeoutSeconds = 180
  )
  Write-E2E "${Description}: $FilePath $($Arguments -join ' ')"
  $process = Start-Process $FilePath -ArgumentList $Arguments -PassThru
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "$Description timed out after $TimeoutSeconds seconds"
  }
  if ($process.ExitCode -ne 0) {
    throw "$Description failed with exit code $($process.ExitCode)"
  }
}

function Reset-Lantern {
  Assert-SmokeGuard
  Get-LanternProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
  $uninstaller = Get-ChildItem $AppDirectory -Filter 'unins*.exe' -File -ErrorAction SilentlyContinue |
    Sort-Object Name | Select-Object -First 1
  if ($uninstaller) {
    Invoke-Checked $uninstaller.FullName @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-') `
      'Uninstalling existing Lantern'
  } else {
    $service = Join-Path $AppDirectory 'lanternd.exe'
    if (Test-Path -LiteralPath $service) {
      & $service uninstall 2>&1 | Out-Null
    }
  }
  Remove-Item -LiteralPath $AppDirectory, $DataDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

function Install-Fixture {
  Reset-Lantern
  New-Item -ItemType Directory -Path $AppDirectory -Force | Out-Null
  Copy-Item -Path (Join-Path $FixtureDirectory '*') -Destination $AppDirectory -Recurse -Force
  Invoke-Checked (Join-Path $AppDirectory 'lanternd.exe') @('install') 'Registering fixture service'
}

function Save-Screenshot([string]$Name) {
  try {
    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
      $bitmap.Save((Join-Path $ArtifactDirectory "$Name.png"))
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  } catch {
    $_ | Out-String | Set-Content (Join-Path $ArtifactDirectory "$Name-screenshot-error.txt")
  }
}

function Assert-AppVersion {
  param(
    [string]$Name,
    [int]$ExpectedBuild,
    [string]$ExpectedDisplay
  )
  $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($AppExecutable)
  $display = ($info.ProductVersion -split '\+', 2)[0]
  $signature = Get-AuthenticodeSignature -LiteralPath $AppExecutable
  $subject = if ($null -eq $signature.SignerCertificate) { '' } else { $signature.SignerCertificate.Subject }
  @(
    "display_version=$display"
    "raw_product_version=$($info.ProductVersion)"
    "build_number=$($info.FilePrivatePart)"
    "authenticode_status=$($signature.Status)"
    "authenticode_subject=$subject"
  ) | Set-Content (Join-Path $ArtifactDirectory "versions-$Name.txt")
  if ($display -ne $ExpectedDisplay -or $info.FilePrivatePart -ne $ExpectedBuild) {
    throw "$Name version $display+$($info.FilePrivatePart) did not match $ExpectedDisplay+$ExpectedBuild"
  }
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "$Name Lantern executable Authenticode status is $($signature.Status)"
  }
}

function Get-Window([string[]]$NamePrefixes) {
  $condition = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  foreach ($window in [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
      [System.Windows.Automation.TreeScope]::Children, $condition)) {
    $name = $window.Current.Name
    foreach ($prefix in $NamePrefixes) {
      if ($name -eq $prefix -or $name.StartsWith("$prefix ")) { return $window }
    }
  }
  return $null
}

function Get-Button($Window, [string[]]$Names) {
  if ($null -eq $Window) { return $null }
  $condition = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Button
  )
  foreach ($button in $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)) {
    if ($button.Current.IsEnabled -and $Names -contains $button.Current.Name.Replace('&', '')) {
      return $button
    }
  }
  return $null
}

function Press-Button($Button) {
  $pattern = $null
  if (-not $Button.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
    throw "Button '$($Button.Current.Name)' cannot be invoked"
  }
  Write-E2E "pressing $($Button.Current.Name)"
  ([System.Windows.Automation.InvokePattern]$pattern).Invoke()
}

function Save-UiTree([string]$Name) {
  $lines = foreach ($windowName in @('Software Update', 'Setup - Lantern', 'Lantern Setup')) {
    $window = Get-Window @($windowName)
    if ($window) {
      "WINDOW name='$($window.Current.Name)' pid=$($window.Current.ProcessId)"
      $condition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Button
      )
      foreach ($button in $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)) {
        "  BUTTON name='$($button.Current.Name)' enabled=$($button.Current.IsEnabled)"
      }
    }
  }
  $lines | Set-Content (Join-Path $ArtifactDirectory "ui-$Name.txt")
}

function Wait-ForUpdatePrompt {
  $deadline = [DateTime]::UtcNow.AddSeconds($UiTimeout)
  while ([DateTime]::UtcNow -lt $deadline) {
    $button = Get-Button (Get-Window @('Software Update')) @('Install update', 'Get update')
    if ($button) { return $button }
    Start-Sleep -Milliseconds 250
  }
  Save-UiTree 'prompt-timeout'
  throw 'WinSparkle update prompt did not appear before timeout'
}

function Install-Update([int]$OriginalPid) {
  $deadline = [DateTime]::UtcNow.AddSeconds($UpdateTimeout)
  while ([DateTime]::UtcNow -lt $deadline) {
    $installer = Get-Window @('Setup - Lantern', 'Lantern Setup')
    $button = Get-Button $installer @('Next >', 'Next', 'Install', 'Finish', 'Yes')
    if (-not $button) {
      $button = Get-Button (Get-Window @('Software Update')) @('Run installer')
    }
    if ($button) {
      Press-Button $button
      Start-Sleep -Milliseconds 500
    }
    if (-not (Get-Process -Id $OriginalPid -ErrorAction SilentlyContinue)) {
      $relaunched = Get-LanternProcesses | Where-Object Id -ne $OriginalPid | Select-Object -First 1
      if ($relaunched) { return $relaunched }
    }
    Start-Sleep -Milliseconds 250
  }
  Save-UiTree 'install-timeout'
  throw 'WinSparkle did not install and relaunch Lantern before timeout'
}

function Wait-ForMainWindow([int]$ProcessId) {
  $deadline = [DateTime]::UtcNow.AddSeconds($UiTimeout)
  while ([DateTime]::UtcNow -lt $deadline) {
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($process) {
      $process.Refresh()
      if ($process.MainWindowHandle -ne 0) { return }
    }
    Start-Sleep -Milliseconds 250
  }
  throw "Lantern process $ProcessId did not expose a main window before timeout"
}

function Save-Diagnostics {
  @(
    "result=$script:Result"
    "original_pid=$script:OriginalPid"
    "relaunched_pid=$script:RelaunchedPid"
  ) | Set-Content (Join-Path $ArtifactDirectory 'result.txt')
  Get-CimInstance Win32_Process | Where-Object Name -Match '^(lantern|lanternd|lantern-installer.*|Update|unins\d*)\.exe$' |
    Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine |
    Format-List | Out-String -Width 4096 |
    Set-Content (Join-Path $ArtifactDirectory 'processes-final.txt')
  Save-UiTree 'final'
  $logs = Join-Path $DataDirectory 'Logs'
  if (Test-Path -LiteralPath $logs) {
    Copy-Item $logs (Join-Path $ArtifactDirectory 'lantern-logs') -Recurse -Force
  }
  Get-ChildItem $env:TEMP -Filter 'Update-*' -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue } |
    Select-Object FullName, Length, LastWriteTime |
    Format-Table -AutoSize | Out-String -Width 4096 |
    Set-Content (Join-Path $ArtifactDirectory 'winsparkle-files.txt')
}

Assert-SmokeGuard
New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null
Copy-Item $AppcastXml (Join-Path $ArtifactDirectory 'appcast.xml')
Copy-Item $TargetJson (Join-Path $ArtifactDirectory 'resolved-target.json')
$target = Get-Content $TargetJson -Raw | ConvertFrom-Json
$targetBuild = [int]$target.target_build
$fixtureBuild = [int]$target.fixture_build
$displayVersion = [string]$target.display_version

try {
  Install-Fixture
  Assert-AppVersion 'fixture' $fixtureBuild $displayVersion
  Save-Screenshot 'before'

  Write-E2E 'running the Flutter auto-update robot against the installed fixture'
  & flutter drive --profile "--use-application-binary=$AppExecutable" --keep-app-running `
    --driver=test_driver/integration_test.dart `
    --target=integration_test/auto_update/desktop_auto_update_smoke_test.dart `
    --device-id=windows *>&1 |
    Tee-Object -FilePath (Join-Path $ArtifactDirectory 'flutter-drive.log')
  if ($LASTEXITCODE -ne 0) { throw "Flutter auto-update robot failed with exit code $LASTEXITCODE" }

  if (-not (Test-Path -LiteralPath $HandoffPath -PathType Leaf)) {
    throw 'Flutter test completed without creating its native handoff.'
  }
  $handoff = Get-Content $HandoffPath -Raw | ConvertFrom-Json
  Copy-Item $HandoffPath (Join-Path $ArtifactDirectory 'auto-update-handoff.json')
  $script:OriginalPid = [int]$handoff.pid
  if ([string]$handoff.build_number -ne [string]$fixtureBuild -or
      [string]$handoff.display_version -ne $displayVersion) {
    throw 'Flutter test ran against the wrong fixture version.'
  }
  $original = Get-Process -Id $script:OriginalPid -ErrorAction Stop
  if ($original.Path -ne $AppExecutable) {
    throw "Flutter handoff PID $script:OriginalPid is not the installed Lantern app"
  }

  $installButton = Wait-ForUpdatePrompt
  Save-UiTree 'prompt'
  Save-Screenshot 'prompt'
  Press-Button $installButton
  $relaunched = Install-Update $script:OriginalPid
  $script:RelaunchedPid = $relaunched.Id
  Wait-ForMainWindow $script:RelaunchedPid
  Assert-AppVersion 'updated' $targetBuild $displayVersion
  Save-Screenshot 'after'
  $script:Result = 'success'
  Write-E2E "auto-update smoke passed: build $fixtureBuild -> $targetBuild"
} finally {
  try { Save-Diagnostics } catch { Write-Warning "Unable to save all diagnostics: $_" }
  try { Save-Screenshot 'final' } catch { Write-Warning "Unable to save final screenshot: $_" }
  try { Reset-Lantern } catch { Write-Warning "Unable to clean up Lantern fixture: $_" }
}
