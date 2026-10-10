#requires -Version 7.2
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Bundle,
  [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ManifestSHA256,
  [Parameter(Mandatory)][string]$Expected,
  [ValidateSet('Run', 'AfterReboot')][string]$Phase = 'Run',
  [ValidateRange(120, 3600)][int]$TimeoutSeconds = 1200
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:Result = [ordered]@{schema_version=1; ok=$false; code='preflight'; phase=$Phase; production_activation_ready=$false}
$script:Out = $null

function Fail([string]$Code) {
  $failure = [InvalidOperationException]::new('Migration E2E assertion failed')
  $failure.Data['migration-e2e-code'] = $Code
  throw $failure
}
function Require([bool]$Condition, [string]$Code) {
  if (-not $Condition) { Fail $Code }
}
function Open-SharedRead([string]$Path) {
  # Observing the updater or journal must not deny its atomic rename/delete.
  [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
}
function Hash([string]$Path) {
  $stream = Open-SharedRead $Path
  $digest = [Security.Cryptography.SHA256]::Create()
  try { [Convert]::ToHexString($digest.ComputeHash($stream)).ToLowerInvariant() }
  finally { $digest.Dispose(); $stream.Dispose() }
}
function Read-Json([string]$Path) {
  $stream = Open-SharedRead $Path
  $reader = [IO.StreamReader]::new($stream)
  try { $reader.ReadToEnd() | ConvertFrom-Json -AsHashtable }
  finally { $reader.Dispose(); $stream.Dispose() }
}
function Write-Json([string]$Path, $Value) {
  $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}
function ConvertTo-UtcTime($Value) {
  if ($Value -is [DateTime]) { return $Value.ToUniversalTime() }
  [DateTime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::AdjustToUniversal)
}
function Wait-Until([scriptblock]$Check, [string]$Code, [int]$Seconds = $TimeoutSeconds) {
  $until = [DateTime]::UtcNow.AddSeconds($Seconds)
  do {
    if (& $Check) { return }
    Start-Sleep -Seconds 2
  } while ([DateTime]::UtcNow -lt $until)
  Fail $Code
}
function Private-Directory([string]$Path, [switch]$InstallerReadable) {
  New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null
  $acl = [Security.AccessControl.DirectorySecurity]::new()
  $acl.SetAccessRuleProtection($true, $false)
  foreach ($id in @($script:SID, 'S-1-5-18')) {
    $sidObject = [Security.Principal.SecurityIdentifier]::new($id)
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($sidObject, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
  }
  if ($InstallerReadable) {
    # Another administrator's UAC token must traverse the source and read the
    # preserved executable. It receives no access to the private config/fixture.
    $admins = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $read = [Security.AccessControl.FileSystemAccessRule]::new($admins, 'ReadAndExecute,Synchronize', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($read)
  }
  Set-Acl -LiteralPath $Path -AclObject $acl
}
function Require-Private([string]$Path) {
  $acl = Get-Acl -LiteralPath $Path
  $allowed = @($script:SID, 'S-1-5-18', 'S-1-5-32-544')
  foreach ($rule in $acl.Access) {
    if ($rule.AccessControlType -eq 'Allow') {
      Require ($rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -in $allowed) 'fixture_acl'
    }
  }
}
function No-Reparse([string]$Path) {
  $current = [IO.Path]::GetFullPath($Path)
  while ($current) {
    if (Test-Path -LiteralPath $current) {
      Require (((Get-Item -Force -LiteralPath $current).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'reparse_path'
    }
    $current = [IO.Path]::GetDirectoryName($current)
  }
}
function Require-ProtectedLease([string]$Path, [bool]$Ancestor = $false) {
  $acl = Get-Acl -LiteralPath $Path
  $trusted = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
  Require ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -in $trusted) 'untrusted_vm_lease'
  # An ancestor may allow users to create unrelated folders, but it must not let
  # them replace this existing protected lease directory via DELETE_CHILD.
  $mutating = [Security.AccessControl.FileSystemRights]::Delete -bor
    [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
    [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
    [Security.AccessControl.FileSystemRights]::TakeOwnership
  if (-not $Ancestor) { $mutating = $mutating -bor [Security.AccessControl.FileSystemRights]::Write }
  foreach ($rule in $acl.Access) {
    if (($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0) { continue }
    if ($rule.AccessControlType -eq 'Allow' -and (($rule.FileSystemRights -band $mutating) -ne 0)) {
      Require ($rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -in $trusted) 'writable_vm_lease'
    }
  }
}
function Asset([string]$Name) { Join-Path $Bundle $script:M.artifacts[$Name].file }
function Run-Value {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run')
  try { if ($key) { return $key.GetValue('Lantern', $null, 'DoNotExpandEnvironmentNames') }; return $null }
  finally { if ($key) { $key.Dispose() } }
}
function Process-At([string]$Path) {
  @(Get-Process -Name lantern -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Path })
}
function Launch-Legacy {
  Start-Process -FilePath $script:LegacyExe -ArgumentList @('-readableconfig', '-stickyconfig') -PassThru
}
function Stop-Legacy {
  # Only processes launched from this run's fresh legacy directory are stopped.
  # The panicwrap parent can exit while its child is stopped. Recheck each PID
  # and its image path instead of failing on a process that has already exited.
  foreach ($process in @(Process-At $script:LegacyExe)) {
    $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
    if ($current -and $current.Path -eq $script:LegacyExe) {
      try { Stop-Process -InputObject $current -Force -ErrorAction Stop }
      catch {
        if (Get-Process -Id $current.Id -ErrorAction SilentlyContinue) { Fail 'legacy_stop_failed' }
      }
    }
  }
  Wait-Until { @(Process-At $script:LegacyExe).Count -eq 0 } 'legacy_stop_failed' 30
}
function Probe([string]$Mode) {
  $probeArgs = @('--expected', $Expected, '--mode', $Mode, '--timeout', '90s')
  if ($Mode -eq 'connect') { $probeArgs += @('--probe-url', $script:M.probe_url) }
  $raw = & (Asset 'probe') @probeArgs 2>$null
  Require ($LASTEXITCODE -eq 0) ('probe_' + $Mode)
  $data = ($raw -join "`n") | ConvertFrom-Json -AsHashtable
  Require ($data.ok -eq $true -and $data.identity_sha256 -eq $script:IdentityHash) ('probe_' + $Mode)
  # Only copy fixed success booleans; never forward arbitrary executable output.
  $script:Result['probe_' + $Mode] = $true
}
function Check-GlobalConfig {
  # The pinned legacy parser must accept the complete sticky config. Otherwise
  # 7.9.5 falls back to its embedded production config even with -stickyconfig.
  # Frozen dependencies log during Go package initialization, before main can
  # suppress them. Only the fresh result file is part of the helper's contract.
  $scratch = Join-Path ([IO.Path]::GetTempPath()) ('Lantern-config-check-' + [guid]::NewGuid().ToString('N'))
  No-Reparse $scratch
  Private-Directory $scratch
  try {
    $resultPath = Join-Path $scratch 'result.json'
    & (Asset 'global_checker') --config (Asset 'global_config') --result $resultPath *> $null
    Require ($LASTEXITCODE -eq 0) 'invalid_global_config'
    $checked = Read-Json $resultPath
    Require ($checked.schema_version -eq 1 -and $checked.ok -eq $true -and $checked.code -eq 'valid_staging_global_config') 'invalid_global_config'
  } finally { Remove-Item -LiteralPath $scratch -Recurse -Force }
  $script:Result.global_config_verified = $true
}
function Service-Staging {
  $service = Get-CimInstance Win32_Service -Filter "Name='LanternSvc'"
  Require ($null -ne $service -and $service.State -eq 'Running' -and $service.StartName -eq 'LocalSystem') 'service_not_ready'
  # SCM quotes the executable and arguments containing spaces. Permit quoted
  # staging values, but reject a second environment flag that could override it.
  Require ($service.PathName -match '^"C:\\Program Files\\Lantern\\LanternSvc\.exe"\s+run(?:\s|$)' -and
           $service.PathName -match '(?:^|\s)"?--environment"?(?:=|\s+)(?:"staging"|staging)(?:\s|$)' -and
           [regex]::Matches($service.PathName, '(?:^|\s)"?--environment"?(?:=|\s+)').Count -eq 1) 'service_not_staging'
  Require ($service.StartMode -eq 'Auto') 'service_not_automatic'
  $script:Result.service_ready = $true
}
function Check-Routes {
  $osVersion = [Environment]::OSVersion.Version
  $version = "$($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)"
  foreach ($hop in @('bridge', 'installer', 'unsupported-x86', 'unsupported-arm64', 'unknown')) {
    $isSeed = $hop -eq 'bridge'
    $body = @{version=1; app_id=''; app_version=$(if ($isSeed) {'7.9.5'} else {$script:M.bridge_version});
      os_version=$version; user_id=''; checksum=$script:M.artifacts[$(if ($isSeed) {'seed'} else {'bridge'})].sha256;
      tags=@{os='windows'; arch='386'; channel='stable'}}
    if (-not $isSeed) {
      $body.tags.os_arch = switch ($hop) {'unsupported-x86' {'386'} 'unsupported-arm64' {'arm64'} 'unknown' {'unknown'} default {'amd64'}}
      $body.tags.windows_installer = '1'
    }
    $response = Invoke-WebRequest -Uri $script:M.endpoint -Method Post -ContentType 'application/json' `
      -Body ($body | ConvertTo-Json -Depth 5 -Compress) -Headers @{'X-Message-Nonce'=[string][Security.Cryptography.RandomNumberGenerator]::GetInt32(1, [int]::MaxValue)} `
      -MaximumRedirection 0 -TimeoutSec 30 -SkipHttpErrorCheck
    if ($hop -in @('bridge', 'installer')) {
      Require ($response.StatusCode -eq 200) 'catalog_not_ready'
      $offer = $response.Content | ConvertFrom-Json -AsHashtable
      Require ($offer.version -eq $(if ($isSeed) {$script:M.bridge_version} else {$script:M.installer_version}) -and
               $offer.initiative -eq 'auto' -and [string]::IsNullOrEmpty($offer['patch_url']) -and
               [string]::IsNullOrEmpty($offer['patch_type']) -and
               $offer.checksum -eq $script:M.artifacts[$hop].sha256 -and
               $offer.update_type -eq $(if ($isSeed) {'binary'} else {'installer'}) -and
               $offer.target_arch -eq $(if ($isSeed) {'386'} else {'amd64'}) -and
               $offer.url.StartsWith('https://github.com/getlantern/lantern-update-fixtures/releases/download/')) 'catalog_drift'
    } else {
      Require ($response.StatusCode -eq 204) 'unsupported_route'
    }
  }
  # Synthetic requests validate catalog pins/routing. Only the real clients verify
  # the signed messages and apply/download updates below.
  $script:Result.routing_preflight = $true
}
function Legacy-Preserved {
  Require ((Hash $script:LegacyExe) -eq $script:M.artifacts.bridge.sha256) 'legacy_binary_lost'
  $settings = Join-Path $script:Config 'settings.yaml'
  Require ((Test-Path -LiteralPath $settings) -and (Get-Item -LiteralPath $settings).Length -gt 0) 'legacy_settings_lost'
  Require ((Get-Content -LiteralPath $settings -Raw).Contains($script:E.token)) 'legacy_token_lost'
  $script:Result.legacy_recoverable = $true
}

try {
  Require ($IsWindows -and [Environment]::Is64BitOperatingSystem -and [Environment]::Is64BitProcess) 'windows_x64_required'
  $processors = @(Get-CimInstance Win32_Processor)
  Require ($processors.Count -gt 0 -and @($processors | Where-Object { $_.Architecture -ne 9 }).Count -eq 0) 'native_x64_required'
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $script:SID = $identity.User.Value
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'run_as_original_standard_user'
  # A filtered administrator token also fails the role check. Require an actual
  # non-administrator account so the different-admin UAC path is exercised.
  Require (@($identity.Groups | Where-Object { $_.Value -eq 'S-1-5-32-544' }).Count -eq 0) 'standard_account_required'
  Require ([Environment]::UserInteractive -and (Get-Process -Id $PID).SessionId -ne 0) 'interactive_session_required'
  $Bundle = (Resolve-Path -LiteralPath $Bundle).Path
  $Expected = (Resolve-Path -LiteralPath $Expected).Path
  No-Reparse $Bundle
  No-Reparse $Expected
  Require-Private $Expected
  $validation = & python "$PSScriptRoot/bundle.py" $Bundle --manifest-sha256 $ManifestSHA256 2>$null
  Require ($LASTEXITCODE -eq 0) 'invalid_bundle'
  $script:M = Read-Json (Join-Path $Bundle 'manifest.json')
  $script:E = Read-Json $Expected
  [long]$parsedID = 0
  Require ($script:E.schema_version -eq 1 -and $script:E.account_environment -eq 'staging' -and
    $script:E.user_id -is [string] -and $script:E.user_id -match '^[1-9][0-9]{0,18}$' -and
    [long]::TryParse($script:E.user_id, [ref]$parsedID) -and $parsedID -gt 0 -and
    $script:E.token -is [string] -and $script:E.token.Length -gt 0 -and
    $script:E.device_id -is [string] -and $script:E.device_id.Length -gt 0 -and
    $script:E.device_id -notmatch '[\r\n]' -and $script:E.user_level -in @('free','pro')) 'invalid_private_fixture'
  foreach ($key in @('auto_launch','auto_report','proxy_all')) { Require ($script:E[$key] -is [bool]) 'invalid_private_fixture' }
  $script:IdentityHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
    [Text.Encoding]::UTF8.GetBytes($script:E.user_id + "`n" + $script:E.device_id))).ToLowerInvariant()
  # The VM provider creates a fresh, short-lived lease. A normal workstation lacks
  # this protected marker; the runner never deletes an existing installation.
  $leasePath = 'C:\ProgramData\LanternMigrationE2E\lease.json'
  No-Reparse $leasePath
  Require-ProtectedLease $leasePath
  $leaseDirectory = [IO.Path]::GetDirectoryName($leasePath)
  Require-ProtectedLease $leaseDirectory
  $ancestor = [IO.Path]::GetDirectoryName($leaseDirectory)
  while ($ancestor) {
    Require-ProtectedLease $ancestor $true
    $ancestor = [IO.Path]::GetDirectoryName($ancestor)
  }
  $lease = Read-Json $leasePath
  Require ($lease.run_id -eq $script:M.run_id -and $lease.machine -eq $env:COMPUTERNAME -and
    $lease.original_sid -eq $script:SID -and (ConvertTo-UtcTime $lease.expires_utc) -gt [DateTime]::UtcNow) 'invalid_vm_lease'
  $root = Join-Path $env:LOCALAPPDATA ('LanternMigrationE2E\' + $script:M.run_id)
  $script:Config = Join-Path $env:APPDATA 'Lantern'
  $script:LegacyExe = Join-Path $root 'legacy app\lantern.exe'
  $destination = 'C:\Program Files\Lantern'
  $destinationUI = Join-Path $destination 'lantern.exe'
  $diagnostics = Join-Path $root 'diagnostics'
  $statePath = Join-Path $root 'state.json'
  $journalPath = Join-Path $script:Config 'bridge-migration\adoption-v1.json'
  $startupPath = Join-Path $script:Config 'bridge-migration\startup-v1.json'
  $runtimePath = Join-Path $script:Config 'bridge-e2e\status.json'
  foreach ($path in @($root,$script:Config,$destination,'C:\ProgramData\Lantern')) { No-Reparse $path }
  foreach ($name in @('seed','bridge','installer')) {
    $signature = Get-AuthenticodeSignature -LiteralPath (Asset $name)
    Require ($signature.Status -eq 'Valid' -and $signature.SignerCertificate.Thumbprint -eq $script:M.artifacts[$name].signer_thumbprint) 'invalid_authenticode'
  }
  $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
  $script:Result.run_id = $script:M.run_id
  $script:Result.lane = $script:M.lane
  $script:Result.scenario = $script:M.scenario
  $script:Result.manifest_sha256 = $ManifestSHA256
  if ($Phase -eq 'Run') {
    foreach ($path in @($root,$script:Config,$destination,'C:\ProgramData\Lantern')) {
      Require (-not (Test-Path -LiteralPath $path)) 'existing_installation_or_run'
    }
    Require (-not (Get-Service -Name LanternSvc -ErrorAction SilentlyContinue)) 'existing_service'
    Require ($null -eq (Run-Value)) 'existing_startup'
    Require (@(Get-Process -Name lantern -ErrorAction SilentlyContinue).Count -eq 0) 'existing_process'
    Require (-not (Test-Path 'HKLM:\Software\Lantern\LegacyMigrationV1')) 'existing_enrollment'
    Require (-not (Test-Path 'HKCU:\Sofware\Lantern')) 'existing_device_identity'
    Check-GlobalConfig
    Check-Routes
    Private-Directory $root -InstallerReadable
    Private-Directory (Join-Path $root 'legacy app') -InstallerReadable
    Private-Directory $script:Config
    Private-Directory $diagnostics
    $script:Out = $diagnostics
    Copy-Item -LiteralPath (Asset 'seed') -Destination $script:LegacyExe
    Copy-Item -LiteralPath (Asset 'global_config') -Destination (Join-Path $script:Config 'global.yaml')
    $settings = [ordered]@{userID=$parsedID; userToken=$script:E.token; migratedDeviceIDForUserID=$parsedID;
      lang=$script:E.locale; autoReport=$script:E.auto_report; proxyAll=$script:E.proxy_all; autoLaunch=$script:E.auto_launch}
    Write-Json (Join-Path $script:Config 'settings.yaml') $settings
    # This typo is the registry path actually used by released 7.9.5.
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Sofware\\Lantern')
    try { $key.SetValue('deviceid', $script:E.device_id) } finally { $key.Dispose() }
    $seed = Launch-Legacy
    $script:Result.seed_started = $true
    Wait-Until {
      # go-update briefly renames the old image before putting the new image in
      # place; a read during that interval is not an update failure.
      try { (Hash $script:LegacyExe) -eq $script:M.artifacts.bridge.sha256 } catch { $false }
    } 'bridge_update_timeout'
    $script:Result.real_seed_update = $true
    # The released updater replaces the EXE but only notifies the running process.
    # Model a user restart; never copy the bridge fixture over the executable.
    Stop-Legacy
    Require (-not (Test-Path -LiteralPath $runtimePath)) 'stale_runtime_evidence'
    if ($script:M.scenario -eq 'installer-failure') {
      Write-Host 'Create C:\Program Files\Lantern\migration-e2e-sentinel.txt containing the run ID using the VM administrator. The real installer must reject this occupied destination.'
      Wait-Until { Test-Path -LiteralPath (Join-Path $destination 'migration-e2e-sentinel.txt') } 'fault_not_prepared'
      Require ((Get-Content -LiteralPath (Join-Path $destination 'migration-e2e-sentinel.txt') -Raw).Trim() -eq $script:M.run_id) 'wrong_fault_fixture'
    }
    Write-Host $(if ($script:M.scenario -eq 'cancel') {'Decline the real UAC prompt for the migration installer.'} else {'Approve the migration installer UAC prompt using the VM administrator; complete the installer.'})
    $bridge = Launch-Legacy
    Wait-Until { Test-Path -LiteralPath $runtimePath } 'bridge_runtime_timeout'
    $runtime = Read-Json $runtimePath
    $runtimeProcess = Get-Process -Id $runtime.pid -ErrorAction SilentlyContinue
    Require ($runtimeProcess -and $runtimeProcess.Path -eq $script:LegacyExe -and
      $runtimeProcess.StartTime -ge $bridge.StartTime -and $runtime.schema_version -eq 1 -and
      $runtime.app_version -eq $script:M.bridge_version -and $runtime.account_environment -eq 'staging' -and
      $runtime.update_endpoint -eq $script:M.endpoint -and $runtime.identity_sha256 -eq $script:IdentityHash -and
      $runtime.token_present -eq $true -and $runtime.locale -eq $script:E.locale -and
      $runtime.auto_report -eq $script:E.auto_report -and $runtime.proxy_all -eq $script:E.proxy_all -and
      $runtime.auto_launch -eq $script:E.auto_launch) 'bridge_identity_mismatch'
    $script:Result.bridge_runtime_verified = $true
    if ($script:M.scenario -ne 'success') {
      $attempts = Join-Path $script:Config 'bridge-migration\installer-attempts'
      Wait-Until {
        $files = @(Get-ChildItem -LiteralPath $attempts -Filter '*.json' -ErrorAction SilentlyContinue)
        $files.Count -eq 1 -and (Read-Json $files[0].FullName).status -eq 'failed_or_cancelled'
      } 'failure_not_observed'
      Require (-not (Get-Service -Name LanternSvc -ErrorAction SilentlyContinue)) 'failed_install_left_service'
      Require (-not (Test-Path -LiteralPath $startupPath)) 'failed_install_switched_startup'
      $runBefore = Run-Value
      Require ($runBefore -eq ('"' + $script:LegacyExe + '" ' + $(if ($script:E.auto_launch) {'-startup'} else {'-clear-proxy-settings'}))) 'legacy_startup_changed'
      $attemptFile = @(Get-ChildItem -LiteralPath $attempts -Filter '*.json')[0].FullName
      $attemptHash = Hash $attemptFile
      Stop-Legacy
      $restartTime = [DateTime]::Now
      $null = Launch-Legacy
      Wait-Until {
        $latest = Read-Json $runtimePath
        $running = @(Process-At $script:LegacyExe | Where-Object { $_.Id -eq $latest.pid -and $_.StartTime -ge $restartTime })
        $running.Count -eq 1
      } 'legacy_restart_not_observed' 90
      # Resume has a 90-second deadline. Observe beyond it, keeping each wait
      # short so an interactive operator can still cancel the job.
      foreach ($tick in 1..65) {
        Start-Sleep -Seconds 2
        Require ((Hash $attemptFile) -eq $attemptHash -and (Run-Value) -eq $runBefore -and
          -not (Get-Service -Name LanternSvc -ErrorAction SilentlyContinue)) 'failure_retry_changed_state'
      }
      Require ((Hash $attemptFile) -eq $attemptHash -and (Run-Value) -eq $runBefore) 'failure_retry_changed_state'
      $legacyProcesses = @(Process-At $script:LegacyExe)
      Require ($legacyProcesses.Count -ge 1 -and $legacyProcesses.Count -le 2) 'legacy_not_running'
      Legacy-Preserved
      $script:Result.failure_observed = $true
      $script:Result.restart_preserved_attempt = $true
      $script:Result.code = 'negative_case_passed'
    } else {
      Wait-Until { (Test-Path -LiteralPath $journalPath) -and (Read-Json $journalPath).phase -eq 'complete' } 'migration_not_complete'
      Require ((Read-Json $startupPath).phase -eq 'complete') 'startup_not_committed'
      Service-Staging
      Probe 'verify'
      Probe 'connect'
      Probe 'disconnect'
      Legacy-Preserved
      Wait-Until { @(Process-At $script:LegacyExe).Count -eq 0 } 'legacy_still_running' 60
      Wait-Until { @(Process-At $destinationUI).Count -eq 1 } 'destination_ui_missing' 60
      $run = Run-Value
      Require ($(if ($script:E.auto_launch) {$run -eq ('"' + $destinationUI + '"')} else {$null -eq $run})) 'destination_startup_mismatch'
      Check-Routes
      Write-Json $statePath @{schema_version=1; manifest_sha256=$ManifestSHA256; original_sid=$script:SID;
        boot=$boot; journal_sha256=(Hash $journalPath); startup_sha256=(Hash $startupPath);
        expected_sha256=(Hash $Expected); identity_sha256=$script:IdentityHash; pending_reboot=$true}
      $script:Result.code = 'awaiting_reboot'
      $script:Result.ok = $false
      Write-Host 'Migration checks passed. Reboot the VM, log in as the same standard user, then run AfterReboot with the same bundle and private fixture. This is not a completed E2E result yet.'
    }
  } else {
    Require ($script:M.scenario -eq 'success') 'reboot_requires_success_scenario'
    Require-Private $statePath
    $state = Read-Json $statePath
    Require ($state.pending_reboot -eq $true -and $state.manifest_sha256 -eq $ManifestSHA256 -and
      $state.original_sid -eq $script:SID -and $state.identity_sha256 -eq $script:IdentityHash -and
      $state.expected_sha256 -eq (Hash $Expected) -and
      (ConvertTo-UtcTime $state.boot) -ne (ConvertTo-UtcTime $boot)) 'reboot_not_proven'
    No-Reparse $diagnostics
    Require-Private $diagnostics
    Require (-not (Test-Path -LiteralPath (Join-Path $diagnostics 'AfterReboot.json'))) 'existing_reboot_result'
    $script:Out = $diagnostics
    Require ((Hash $journalPath) -eq $state.journal_sha256 -and (Read-Json $journalPath).phase -eq 'complete') 'replay_changed_journal'
    Require ((Hash $startupPath) -eq $state.startup_sha256 -and (Read-Json $startupPath).phase -eq 'complete') 'replay_changed_startup'
    $run = Run-Value
    Require ($(if ($script:E.auto_launch) {$run -eq ('"' + $destinationUI + '"')} else {$null -eq $run})) 'destination_startup_mismatch'
    Wait-Until {
      $service = Get-Service -Name LanternSvc -ErrorAction SilentlyContinue
      $service -and $service.Status -eq 'Running'
    } 'service_after_reboot' 90
    Service-Staging
    Probe 'verify'
    Probe 'connect'
    Probe 'disconnect'
    Legacy-Preserved
    Require (@(Process-At $script:LegacyExe).Count -eq 0) 'legacy_started_after_reboot'
    if ($script:E.auto_launch) { Wait-Until { @(Process-At $destinationUI).Count -eq 1 } 'ui_not_started_after_reboot' 90 }
    else { Require (@(Process-At $destinationUI).Count -eq 0) 'unexpected_ui_autolaunch' }
    $script:Result.reboot_verified = $true
    $script:Result.code = 'rebuilt_staging_chain_passed'
  }
  if ($script:Result.code -ne 'awaiting_reboot') { $script:Result.ok = $true }
} catch {
  # Raw exception messages can include paths, credentials or API response bodies.
  # Only fixed local error identifiers are safe to surface.
  $code = $_.Exception.Data['migration-e2e-code']
  $script:Result.code = $(if ($code -is [string]) {$code} else {'harness_error'})
  $script:Result.ok = $false
} finally {
  if ($script:Out -and (Test-Path -LiteralPath $script:Out)) {
    Write-Json (Join-Path $script:Out ($Phase + '.json')) $script:Result
  }
  $script:Result | ConvertTo-Json -Depth 6 -Compress
}
if ($script:Result.code -eq 'awaiting_reboot') { exit 2 }
if (-not $script:Result.ok) { exit 1 }
