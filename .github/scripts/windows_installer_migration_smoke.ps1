param(
  [Parameter(Mandatory = $true)][string]$WorkDirectory,
  [Parameter(Mandatory = $true)][string]$ArtifactDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$FixtureName = 'Lantern Installer Migration Fixture'
$ServiceName = 'LanternInstallerMigrationFixtureSvc'
$TargetDirectory = Join-Path $env:ProgramFiles $FixtureName
$FixtureData = Join-Path $env:ProgramData 'LanternInstallerMigrationFixture'
$UserSettingsDirectory = Join-Path $env:APPDATA 'Lantern'
$LegacyRegistry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Lantern'
$LegacyLocationRegistry = 'HKCU:\Software\Lantern'
# This misspelling is the actual legacy device ID location; preserve it as-is.
$LegacyDeviceRegistry = 'HKCU:\Sofware\Lantern'
$RunRegistry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Lantern.lnk'
$StartShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'Lantern.lnk'
$Results = [Collections.Generic.List[object]]::new()
$CreatedLegacyState = $false
$LegacyRunningProcess = $null
$MigrationSID = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$MigrationID = [Guid]::NewGuid().ToString('N')

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Service-Exists {
  & sc.exe query $ServiceName *> $null
  if ($LASTEXITCODE -eq 1060) { return $false }
  # A service marked for deletion still exists until its last handle closes.
  if ($LASTEXITCODE -eq 1072) { return $true }
  if ($LASTEXITCODE -ne 0) { throw "Service query failed with exit code $LASTEXITCODE" }
  return $true
}

function Remove-FixtureService {
  & sc.exe stop $ServiceName *> $null
  & sc.exe delete $ServiceName *> $null
  Wait-FixtureServiceAbsent
}

function Wait-FixtureServiceAbsent {
  for ($i = 0; $i -lt 60; $i++) {
    if (-not (Service-Exists)) { return }
    Start-Sleep -Milliseconds 250
  }
  throw 'Fixture service did not disappear'
}

function Invoke-Checked([string]$File, [string[]]$Arguments) {
  & $File @Arguments | ForEach-Object { Write-Host $_ }
  if ($LASTEXITCODE -ne 0) { throw "$File failed with exit code $LASTEXITCODE" }
}

function New-FixtureBinary([string]$Kind, [string]$Output, [string]$Architecture = 'x64') {
  $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  Assert-True (Test-Path -LiteralPath $compiler) '.NET Framework C# compiler not found'
  $source = Join-Path $PSScriptRoot '..\..\scripts\ci\windows_installer_fixture.cs'
  Invoke-Checked $compiler @('/nologo', '/target:exe', "/platform:$Architecture", "/define:$Kind", '/reference:System.ServiceProcess.dll', "/out:$Output", $source)
}

function Snapshot-Legacy {
  $snapshot = [ordered]@{}
  foreach ($root in @($LegacyDirectory, $UserSettingsDirectory)) {
    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName) {
      $snapshot[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
  }
  foreach ($path in @($DesktopShortcut, $StartShortcut)) {
    $snapshot[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  }
  $snapshot['registry.uninstall'] = Get-ItemPropertyValue -LiteralPath $LegacyRegistry -Name UninstallString
  $snapshot['registry.location'] = Get-ItemPropertyValue -LiteralPath $LegacyRegistry -Name InstallLocation
  $snapshot['registry.startup'] = Get-ItemPropertyValue -LiteralPath $RunRegistry -Name Lantern
  $snapshot['registry.legacyDirectory'] = (Get-Item -LiteralPath $LegacyLocationRegistry).GetValue('')
  $snapshot['registry.deviceid'] = Get-ItemPropertyValue -LiteralPath $LegacyDeviceRegistry -Name deviceid
  return ConvertTo-Json -InputObject $snapshot -Compress
}

function Assert-LegacyPreserved {
  Assert-True ((Snapshot-Legacy) -ceq $LegacySnapshot) 'Installer modified legacy app, settings, shortcuts, or registration'
  # Verify the original executable still starts; its only effect is an external marker.
  Invoke-Checked (Join-Path $LegacyDirectory 'lantern.exe') @()
  Assert-True (Test-Path -LiteralPath $env:LANTERN_FIXTURE_UI_MARKER) 'Preserved legacy application did not run'
  Remove-Item -LiteralPath $env:LANTERN_FIXTURE_UI_MARKER -Force
}

function Reset-Case {
  Remove-FixtureService
  foreach ($path in @($TargetDirectory, $FixtureData)) {
    Remove-FixturePath $path
  }
  foreach ($path in @($env:LANTERN_FIXTURE_DEPENDENCY_MARKER, $env:LANTERN_FIXTURE_UI_MARKER)) {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
  }
  $env:LANTERN_FIXTURE_DEPENDENCY_EXIT_CODE = '0'
}

function Remove-FixturePath([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    # Never recurse through the junction used in the preservation regression.
    $item = Get-Item -LiteralPath $Path
    if ($item.PSProvider.Name -eq 'FileSystem' -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      [IO.Directory]::Delete($Path)
    } else {
      Remove-Item -LiteralPath $Path -Recurse -Force
    }
  }
}

function Build-Installer([string]$Mode, [switch]$FailFileCopy) {
  Set-Content -LiteralPath (Join-Path $PayloadDirectory 'fixture-service-mode.txt') -Value $Mode -Encoding ascii
  $script = if ($FailFileCopy) { $CopyFailureScript } else { $RenderedScript }
  Invoke-Checked $InnoCompiler @('/Qp', "/O$WorkDirectory", $script)
  $installer = Join-Path $WorkDirectory 'lantern-migration-fixture.exe'
  Assert-True (Test-Path -LiteralPath $installer) 'Fixture installer was not compiled'
  return $installer
}

function Start-Installer([string]$Name, [string]$Installer, [string]$ExtraArguments = '', [switch]$Interactive, [string]$LegacySource = $LegacyDirectory, [string]$MigrationVersion = '1', [string]$SourceSID = $MigrationSID, [string]$HandoffID = $MigrationID) {
  $log = Join-Path $ArtifactDirectory "$Name.log"
  $arguments = "/SP- /NORESTART /LEGACYMIGRATION=$MigrationVersion /LEGACYDIR=`"$LegacySource`" /LEGACYSID=`"$SourceSID`" /LEGACYID=`"$HandoffID`" /LOG=`"$log`" $ExtraArguments"
  if (-not $Interactive) { $arguments = "/VERYSILENT /SUPPRESSMSGBOXES $arguments" }
  return Start-Process -FilePath $Installer -ArgumentList $arguments -PassThru
}

function Wait-Installer([Diagnostics.Process]$Process) {
  if (-not $Process.WaitForExit(120000)) {
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    throw 'Fixture installer timed out'
  }
  $Process.Refresh()
  return $Process.ExitCode
}

function Record-Case([string]$Name, [int]$ExitCode) {
  $Results.Add([ordered]@{ case = $Name; result = 'passed'; exit_code = $ExitCode })
  $Results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ArtifactDirectory 'results.json') -Encoding utf8
  Write-Host "PASS $Name (installer exit $ExitCode)"
}

function Assert-NoFixtureLaunch {
  Assert-True (-not (Test-Path -LiteralPath $env:LANTERN_FIXTURE_UI_MARKER)) 'Migration installer launched an app before bridge identity validation'
  foreach ($folder in @('Desktop', 'CommonDesktopDirectory', 'Programs', 'CommonPrograms')) {
    $shortcut = Join-Path ([Environment]::GetFolderPath($folder)) "$FixtureName.lnk"
    Assert-True (-not (Test-Path -LiteralPath $shortcut)) 'Migration created a shortcut before bridge identity validation'
  }
  foreach ($root in @('HKCU', 'HKLM')) {
    $retry = Get-ItemProperty -LiteralPath "${root}:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name $FixtureName -ErrorAction SilentlyContinue
    Assert-True ($null -eq $retry) 'Migration scheduled a retry outside the original user bridge'
  }
}

function Test-Rejection([string]$Name, [string]$Installer, [string]$ExtraArguments = '', [bool]$ExistingService = $false, [string]$LegacySource = $LegacyDirectory, [string]$MigrationVersion = '1', [string]$SourceSID = $MigrationSID, [string]$HandoffID = $MigrationID, [string]$ExpectedError = '') {
  $targetExisted = Test-Path -LiteralPath $TargetDirectory
  $dataExisted = Test-Path -LiteralPath $FixtureData
  $code = Wait-Installer (Start-Installer $Name $Installer $ExtraArguments -LegacySource $LegacySource -MigrationVersion $MigrationVersion -SourceSID $SourceSID -HandoffID $HandoffID)
  Assert-True ($code -ne 0) "$Name unexpectedly succeeded"
  Assert-True (-not (Test-Path -LiteralPath $env:LANTERN_FIXTURE_DEPENDENCY_MARKER)) "$Name ran prerequisites before rejecting migration"
  Assert-True ((Service-Exists) -eq $ExistingService) "$Name changed the existing service state"
  Assert-True ((Test-Path -LiteralPath $TargetDirectory) -eq $targetExisted) "$Name created or removed the destination directory"
  Assert-True ((Test-Path -LiteralPath $FixtureData) -eq $dataExisted) "$Name created or removed the service data directory"
  if ($ExpectedError) {
    Assert-True ((Get-Content -LiteralPath (Join-Path $ArtifactDirectory "$Name.log") -Raw).Contains($ExpectedError)) "$Name did not reach the expected rejection"
  }
  Assert-NoFixtureLaunch
  Assert-LegacyPreserved
  Record-Case $Name $code
}

function Cancel-Installer([Diagnostics.Process]$Process) {
  Add-Type -AssemblyName UIAutomationClient
  Add-Type -AssemblyName UIAutomationTypes
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FixtureWindow {
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
}
'@
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  $clickedCancel = $false
  $wizardProcesses = [Collections.Generic.HashSet[int]]::new()
  while (-not $Process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
    # Inno's loader may spawn the actual wizard; find the isolated fixture title.
    $windows = [Windows.Automation.AutomationElement]::RootElement.FindAll(
      [Windows.Automation.TreeScope]::Children,
      [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Window))
    foreach ($window in $windows) {
      $title = $window.Current.Name
      if ($title -like "*$FixtureName*") { $null = $wizardProcesses.Add($window.Current.ProcessId) }
      if (-not $wizardProcesses.Contains($window.Current.ProcessId)) { continue }
      foreach ($label in @('Cancel', 'Yes')) {
        if ($label -eq 'Cancel' -and $clickedCancel) { continue }
        if ($label -eq 'Yes' -and -not $clickedCancel) { continue }
        $button = $window.FindFirst([Windows.Automation.TreeScope]::Descendants,
          [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty, $label))
        if ($null -ne $button -and $button.Current.IsEnabled) {
          # Post BM_CLICK asynchronously: synchronous UIA Invoke can block while
          # the Cancel button opens its confirmation dialog on the same thread.
          $handle = [IntPtr]$button.Current.NativeWindowHandle
          Assert-True ($handle -ne [IntPtr]::Zero) 'Cancellation button has no native window handle'
          Assert-True ([FixtureWindow]::PostMessage($handle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)) 'Could not click cancellation button'
          if ($label -eq 'Cancel') { $clickedCancel = $true }
        }
      }
    }
    Start-Sleep -Milliseconds 200
    $Process.Refresh()
  }
  Assert-True $clickedCancel 'Could not click Cancel in the fixture installer wizard'
  return Wait-Installer $Process
}

Assert-True ($env:CI -eq 'true' -and $env:GITHUB_ACTIONS -eq 'true' -and $env:RUNNER_ENVIRONMENT -eq 'github-hosted') 'Installer mutation tests require an ephemeral GitHub-hosted Windows runner'
Assert-True ([Environment]::Is64BitOperatingSystem -and [Environment]::Is64BitProcess) 'Fixture requires an x64 Windows test process'
Assert-True ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'Installer fixture requires an elevated test process'
Assert-True (-not (Service-Exists)) 'Fixture service already exists; refusing to overwrite it'
foreach ($path in @($TargetDirectory, $FixtureData, $UserSettingsDirectory, $LegacyRegistry, $LegacyLocationRegistry, $LegacyDeviceRegistry, $DesktopShortcut, $StartShortcut, $WorkDirectory)) {
  Assert-True (-not (Test-Path -LiteralPath $path)) "Fixture path already exists; refusing to overwrite $path"
}
$existingRun = Get-ItemProperty -LiteralPath $RunRegistry -Name Lantern -ErrorAction SilentlyContinue
Assert-True ($null -eq $existingRun) 'Legacy Lantern startup value already exists; refusing to overwrite it'

New-Item -ItemType Directory -Path $WorkDirectory, $ArtifactDirectory -Force | Out-Null
$WorkDirectory = (Resolve-Path -LiteralPath $WorkDirectory).Path
$ArtifactDirectory = (Resolve-Path -LiteralPath $ArtifactDirectory).Path
$PayloadDirectory = Join-Path $WorkDirectory 'payload'
$LegacyDirectory = Join-Path $WorkDirectory 'legacy installation'
$RenderedScript = Join-Path $ArtifactDirectory 'installer-fixture.iss'
$CopyFailureScript = Join-Path $ArtifactDirectory 'installer-copy-failure-fixture.iss'
$env:LANTERN_FIXTURE_DEPENDENCY_MARKER = Join-Path $WorkDirectory 'prerequisite-ran.txt'
$env:LANTERN_FIXTURE_UI_MARKER = Join-Path $WorkDirectory 'ui-launched.txt'
$InnoCompiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
Assert-True (Test-Path -LiteralPath $InnoCompiler) 'Inno Setup compiler not found'

try {
  New-Item -ItemType Directory -Path $PayloadDirectory, $LegacyDirectory, $UserSettingsDirectory -Force | Out-Null
  $CreatedLegacyState = $true
  New-FixtureBinary 'APP' (Join-Path $PayloadDirectory 'lantern.exe')
  New-FixtureBinary 'SERVICE' (Join-Path $PayloadDirectory 'lanternd.exe')
  New-FixtureBinary 'APP;LEGACY' (Join-Path $LegacyDirectory 'lantern.exe') 'x86'
  $dependency = Join-Path $WorkDirectory 'fixture-dependency.exe'
  New-FixtureBinary 'DEPENDENCY' $dependency 'x86'
  Set-Content -LiteralPath (Join-Path $LegacyDirectory 'settings.yaml') -Value 'userID: 12345' -Encoding utf8
  Set-Content -LiteralPath (Join-Path $UserSettingsDirectory 'settings.yaml') -Value "userID: 12345`nuserToken: fixture-legacy-token`nuserPro: true" -Encoding utf8
  New-Item -Path $LegacyRegistry -Force | Out-Null
  New-ItemProperty -LiteralPath $LegacyRegistry -Name UninstallString -Value "`"$LegacyDirectory\uninstall.exe`"" -PropertyType String | Out-Null
  New-ItemProperty -LiteralPath $LegacyRegistry -Name InstallLocation -Value $LegacyDirectory -PropertyType String | Out-Null
  New-Item -Path $LegacyLocationRegistry -Force | Out-Null
  Set-Item -LiteralPath $LegacyLocationRegistry -Value $LegacyDirectory
  New-Item -Path $LegacyDeviceRegistry -Force | Out-Null
  New-ItemProperty -LiteralPath $LegacyDeviceRegistry -Name deviceid -Value '701e8a45-e1f8-4aca-8771-003273a31e68' -PropertyType String | Out-Null
  New-Item -Path $RunRegistry -Force | Out-Null
  New-ItemProperty -LiteralPath $RunRegistry -Name Lantern -Value "`"$LegacyDirectory\lantern.exe`"" -PropertyType String | Out-Null
  $shell = New-Object -ComObject WScript.Shell
  foreach ($path in @($DesktopShortcut, $StartShortcut)) {
    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = Join-Path $LegacyDirectory 'lantern.exe'
    $shortcut.Save()
  }
  $LegacySnapshot = Snapshot-Legacy
  $LegacySnapshot | Set-Content -LiteralPath (Join-Path $ArtifactDirectory 'legacy-before.json') -Encoding utf8
  $renderer = Join-Path $PSScriptRoot '..\..\scripts\ci\render_windows_installer_fixture.py'
  $template = Join-Path $PSScriptRoot '..\..\windows\packaging\exe\inno_setup.iss'
  Invoke-Checked 'python' @($renderer, '--template', $template, '--payload', $PayloadDirectory, '--dependency', $dependency, '--output', $RenderedScript, '--install-directory', $TargetDirectory)
  Invoke-Checked 'python' @($renderer, '--template', $template, '--payload', $PayloadDirectory, '--dependency', $dependency, '--output', $CopyFailureScript, '--install-directory', $TargetDirectory, '--fail-file-copy')

  Reset-Case
  $installer = Build-Installer 'running'
  $code = Wait-Installer (Start-Installer 'success' $installer)
  Assert-True ($code -eq 0) "Migration installer failed with $code"
  $service = Get-Service -Name $ServiceName -ErrorAction Stop
  Assert-True ($service.Status -eq 'Running') 'Installer did not leave its service running'
  $service.Close()
  $enrollment = Get-Content -LiteralPath (Join-Path $TargetDirectory 'fixture-enrollment.json') -Raw | ConvertFrom-Json
  Assert-True ($enrollment.sid -eq $MigrationSID -and $enrollment.migration_id -eq $MigrationID) 'Installer did not bind the enrollment to the original user and handoff'
  Assert-True (Test-Path -LiteralPath $env:LANTERN_FIXTURE_DEPENDENCY_MARKER) 'Successful fixture did not execute the real prerequisite pipeline'
  Assert-NoFixtureLaunch
  Assert-LegacyPreserved
  Record-Case 'success' $code

  $retainedData = Join-Path $FixtureData 'account-must-survive-uninstall.yaml'
  Set-Content -LiteralPath $retainedData -Value 'userID: 12345'
  $retainedHash = (Get-FileHash -LiteralPath $retainedData).Hash
  $LegacyRunningProcess = Start-Process -FilePath (Join-Path $LegacyDirectory 'lantern.exe') -ArgumentList '--hold' -PassThru
  for ($i = 0; $i -lt 50 -and -not (Test-Path -LiteralPath $env:LANTERN_FIXTURE_UI_MARKER); $i++) {
    Start-Sleep -Milliseconds 100
  }
  Assert-True (Test-Path -LiteralPath $env:LANTERN_FIXTURE_UI_MARKER) 'Legacy process did not start for the uninstall preservation case'
  Remove-Item -LiteralPath $env:LANTERN_FIXTURE_UI_MARKER
  $uninstaller = Get-ChildItem -LiteralPath $TargetDirectory -Filter 'unins*.exe' | Select-Object -First 1
  Assert-True ($null -ne $uninstaller) 'Migration did not produce a destination uninstaller'
  $uninstallLog = Join-Path $ArtifactDirectory 'uninstall-retains-recovery.log'
  $uninstallProcess = Start-Process -FilePath $uninstaller.FullName -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=`"$uninstallLog`"" -PassThru
  $code = Wait-Installer $uninstallProcess
  Assert-True ($code -eq 0) "Destination uninstall failed with $code"
  Wait-FixtureServiceAbsent
  Assert-True ((Get-FileHash -LiteralPath $retainedData).Hash -eq $retainedHash) 'Destination uninstall deleted service account data'
  $LegacyRunningProcess.Refresh()
  Assert-True (-not $LegacyRunningProcess.HasExited) 'Destination uninstall terminated the retained legacy app'
  Assert-NoFixtureLaunch
  Assert-LegacyPreserved
  Stop-Process -Id $LegacyRunningProcess.Id -Force
  $LegacyRunningProcess = $null
  Record-Case 'uninstall-retains-recovery' $code

  Reset-Case
  $installer = Build-Installer 'prepare-fail'
  $code = Wait-Installer (Start-Installer 'enrollment-failure' $installer)
  Assert-True ($code -ne 0) 'Enrollment failure unexpectedly succeeded'
  Assert-True ((Get-Content -LiteralPath (Join-Path $ArtifactDirectory 'enrollment-failure.log') -Raw) -match 'Migration enrollment failed: 47') 'Enrollment failure did not reach the preparation command'
  Assert-True (-not (Service-Exists)) 'Service was installed before enrollment succeeded'
  Assert-NoFixtureLaunch
  Assert-LegacyPreserved
  Record-Case 'enrollment-failure' $code

  $installer = Build-Installer 'running'
  $sidRejection = 'Restart migration from the legacy app to authorize identity transfer.'
  foreach ($case in @(
    @{ Name = 'missing-sid'; SID = '' }
    @{ Name = 'malformed-sid'; SID = 'S-1------' }
    @{ Name = 'noncanonical-sid'; SID = $MigrationSID.Replace('S-1-5-', 'S-1-05-') }
    @{ Name = 'group-sid'; SID = 'S-1-5-32-544' }
    @{ Name = 'system-sid'; SID = 'S-1-5-18' }
    @{ Name = 'unresolved-sid'; SID = 'S-1-5-21-2147483647-2147483647-2147483647-2147483647' }
  )) {
    Reset-Case
    Test-Rejection $case.Name $installer -SourceSID $case.SID -ExpectedError $sidRejection
  }
  Reset-Case
  Test-Rejection 'invalid-id' $installer -HandoffID 'invalid' -ExpectedError $sidRejection

  Reset-Case
  New-Item -ItemType Directory -Path $TargetDirectory, $FixtureData | Out-Null
  $code = Wait-Installer (Start-Installer 'empty-destinations' $installer)
  Assert-True ($code -eq 0) 'Migration rejected empty destination folders'
  $service = Get-Service -Name $ServiceName -ErrorAction Stop
  Assert-True ($service.Status -eq 'Running') 'Empty-directory migration did not start its service'
  $service.Close()
  Assert-NoFixtureLaunch
  Assert-LegacyPreserved
  Record-Case 'empty-destinations' $code

  Reset-Case
  Test-Rejection 'unknown-contract' $installer -MigrationVersion '2'
  Test-Rejection 'missing-contract' $installer -MigrationVersion '0'
  Test-Rejection 'relative-source' $installer -LegacySource 'relative-legacy-folder'
  Test-Rejection 'missing-source' $installer -LegacySource (Join-Path $WorkDirectory 'missing-source')

  $pathRejection = 'Restart migration from the legacy app with its installation folder on a fixed local drive.'
  foreach ($case in @(
    @{ Name = 'source-trailing-dot'; Source = "$LegacyDirectory." }
    @{ Name = 'source-trailing-space'; Source = "$LegacyDirectory " }
    @{ Name = 'source-dot-component'; Source = "$WorkDirectory\.\legacy installation" }
    @{ Name = 'source-parent-component'; Source = "$LegacyDirectory\..\legacy installation" }
  )) {
    Reset-Case
    Assert-True ([IO.File]::Exists("$($case.Source)\lantern.exe")) "$($case.Name) does not resolve to the legacy executable"
    Test-Rejection $case.Name $installer -LegacySource $case.Source -ExpectedError $pathRejection
  }

  Reset-Case
  $shareName = 'LanternMigrationFixture-' + [Guid]::NewGuid().ToString('N')
  $networkDrive = @('Z:', 'Y:', 'X:') | Where-Object { [IO.Directory]::GetLogicalDrives() -notcontains "$_\" } | Select-Object -First 1
  Assert-True ($null -ne $networkDrive) 'No unused drive letter for the network source fixture'
  $share = $null
  $mapped = $false
  try {
    $share = New-SmbShare -Name $shareName -Path $WorkDirectory -FullAccess ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    New-SmbMapping -LocalPath $networkDrive -RemotePath "\\localhost\$shareName" -Persistent $false | Out-Null
    $mapped = $true
    Assert-True ([IO.DriveInfo]::new("$networkDrive\").DriveType -eq [IO.DriveType]::Network) 'Fixture drive is not a network drive'
    $networkSource = "$networkDrive\legacy installation"
    Assert-True ([IO.File]::Exists("$networkSource\lantern.exe")) 'Network source fixture cannot read the legacy executable'
    Test-Rejection 'network-source' $installer -LegacySource $networkSource -ExpectedError $pathRejection
  } finally {
    try {
      if ($mapped) { Remove-SmbMapping -LocalPath $networkDrive -Force -Confirm:$false }
    } finally {
      if ($null -ne $share) { Remove-SmbShare -Name $shareName -Force -Confirm:$false }
    }
  }

  foreach ($case in @(
    @{ Name = 'occupied-target'; Directory = $TargetDirectory; File = 'existing-installation.txt'; Content = 'do not overwrite' }
    @{ Name = 'occupied-data'; Directory = $FixtureData; File = 'existing-account.txt'; Content = 'do not overwrite service account data' }
  )) {
    Reset-Case
    New-Item -ItemType Directory -Path $case.Directory | Out-Null
    $sentinel = Join-Path $case.Directory $case.File
    Set-Content -LiteralPath $sentinel -Value $case.Content
    $sentinelHash = (Get-FileHash -LiteralPath $sentinel).Hash
    Test-Rejection $case.Name $installer
    Assert-True ((Get-FileHash -LiteralPath $sentinel).Hash -eq $sentinelHash) "$($case.Name) changed existing data"
  }

  Reset-Case
  New-Item -ItemType Junction -Path $FixtureData -Target $LegacyDirectory | Out-Null
  Test-Rejection 'data-junction-to-legacy' $installer
  Assert-True (((Get-Item -LiteralPath $FixtureData).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Installer changed the rejected data junction'

  Reset-Case
  Test-Rejection 'nondefault-target' $installer "/DIR=`"$(Join-Path $WorkDirectory 'other-target')`""

  Reset-Case
  Test-Rejection 'source-as-target' $installer "/DIR=`"$LegacyDirectory`""

  foreach ($case in @(
    @{ Name = 'source-inside-target'; Directory = $TargetDirectory }
    @{ Name = 'source-inside-data'; Directory = $FixtureData }
  )) {
    Reset-Case
    $nestedSource = Join-Path $case.Directory 'legacy installation'
    New-Item -ItemType Directory -Path $nestedSource -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $LegacyDirectory 'lantern.exe') -Destination $nestedSource
    $nestedExecutable = Join-Path $nestedSource 'lantern.exe'
    $nestedHash = (Get-FileHash -LiteralPath $nestedExecutable).Hash
    Test-Rejection $case.Name $installer -LegacySource $nestedSource
    Assert-True ((Get-FileHash -LiteralPath $nestedExecutable).Hash -eq $nestedHash) "$($case.Name) changed the legacy source"
    Assert-True ((Get-Content -LiteralPath (Join-Path $ArtifactDirectory "$($case.Name).log") -Raw) -match 'must be separate from legacy') "$($case.Name) did not exercise the overlap guard"
  }

  Reset-Case
  $fixtureDaemon = Join-Path $PayloadDirectory 'lanternd.exe'
  New-Service -Name $ServiceName -BinaryPathName ('"' + $fixtureDaemon + '"') -StartupType Manual | Out-Null
  Start-Service -Name $ServiceName
  Test-Rejection 'existing-service' $installer '' $true
  $service = Get-Service -Name $ServiceName
  Assert-True ($service.Status -eq 'Running') 'Rejected migration stopped the pre-existing service'
  $service.Close()

  Reset-Case
  $code = Cancel-Installer (Start-Installer 'cancel-before-install' $installer -Interactive)
  Assert-True ($code -eq 2) "Expected pre-install cancellation exit 2, got $code"
  Assert-True (-not (Service-Exists)) 'Cancellation created a service'
  Assert-True (-not (Test-Path -LiteralPath $env:LANTERN_FIXTURE_DEPENDENCY_MARKER)) 'Cancellation ran prerequisites'
  Assert-True (-not (Test-Path -LiteralPath $TargetDirectory)) 'Cancellation created installation files'
  Assert-NoFixtureLaunch
  Assert-LegacyPreserved
  Record-Case 'cancel-before-install' $code

  foreach ($prerequisiteExit in @(42, 3010, 1641)) {
    Reset-Case
    $env:LANTERN_FIXTURE_DEPENDENCY_EXIT_CODE = "$prerequisiteExit"
    $name = "prerequisite-exit-$prerequisiteExit"
    $code = Wait-Installer (Start-Installer $name $installer)
    Assert-True ($code -ne 0) "Prerequisite exit $prerequisiteExit was ignored"
    Assert-True (Test-Path -LiteralPath $env:LANTERN_FIXTURE_DEPENDENCY_MARKER) 'Prerequisite failure or restart was not exercised'
    Assert-True (-not (Service-Exists)) 'Failed prerequisite created a service'
    Assert-True (-not (Test-Path -LiteralPath $TargetDirectory)) 'Failed prerequisite installed app files'
    Assert-NoFixtureLaunch
    Assert-LegacyPreserved
    Record-Case $name $code
  }

  foreach ($mode in @('create-and-fail', 'leave-stopped')) {
    Reset-Case
    $installer = Build-Installer $mode
    $code = Wait-Installer (Start-Installer $mode $installer)
    Assert-True ($code -ne 0) "$mode unexpectedly returned success"
    $expectedLog = if ($mode -eq 'create-and-fail') { 'Migration service install failed: 42' } else { 'Migration service did not reach RUNNING' }
    Assert-True ((Get-Content -LiteralPath (Join-Path $ArtifactDirectory "$mode.log") -Raw) -match $expectedLog) "$mode did not reach the expected service failure"
    Assert-True (-not (Service-Exists)) "$mode left a failed migration service behind"
    Assert-NoFixtureLaunch
    Assert-LegacyPreserved
    Record-Case $mode $code
  }

  Reset-Case
  $installer = Build-Installer 'running' -FailFileCopy
  $code = Wait-Installer (Start-Installer 'file-copy-failure' $installer)
  Assert-True ($code -ne 0) 'File-copy failure unexpectedly returned success'
  $copyLog = Get-Content -LiteralPath (Join-Path $ArtifactDirectory 'file-copy-failure.log') -Raw
  Assert-True ($copyLog -match '(?s)Successfully installed the file\..*fixture-intentionally-missing\.bin') 'Copy failure did not occur after a fixture file was installed'
  Assert-True (-not (Service-Exists)) 'File-copy failure created a service'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $TargetDirectory 'lantern.exe'))) 'Inno did not roll back the copied application'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $TargetDirectory 'lanternd.exe'))) 'Inno did not roll back the copied daemon'
  Assert-NoFixtureLaunch
  Assert-LegacyPreserved
  Record-Case 'file-copy-failure' $code
} finally {
  if ($null -ne $LegacyRunningProcess -and -not $LegacyRunningProcess.HasExited) {
    Stop-Process -Id $LegacyRunningProcess.Id -Force -ErrorAction SilentlyContinue
  }
  & sc.exe query $ServiceName 2>&1 | Out-File -FilePath (Join-Path $ArtifactDirectory 'service-final.txt')
  if ($CreatedLegacyState) {
    try { Snapshot-Legacy | Set-Content -LiteralPath (Join-Path $ArtifactDirectory 'legacy-after.json') -Encoding utf8 } catch { Write-Warning $_ }
    Remove-FixtureService
    foreach ($path in @($TargetDirectory, $FixtureData, $UserSettingsDirectory, $LegacyRegistry, $LegacyLocationRegistry, $LegacyDeviceRegistry, $DesktopShortcut, $StartShortcut)) {
      Remove-FixturePath $path
    }
    Remove-ItemProperty -LiteralPath $RunRegistry -Name Lantern -ErrorAction SilentlyContinue
  }
}

# Cleanup queries an absent service; its expected sc.exe result is not a test failure.
Write-Host "PASS all $($Results.Count) installer migration scenarios"
exit 0
