# Safe on a hosted runner: load function definitions, never execute VM orchestration.
#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
  "$PSScriptRoot/run.ps1", [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { $parseErrors | Format-List; exit 1 }
foreach ($statement in $ast.EndBlock.Statements) {
  if ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) {
    . ([scriptblock]::Create($statement.Extent.Text))
  }
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('migration-harness-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $original = Join-Path $temp 'original.json'
  $renamed = Join-Path $temp 'renamed.json'
  [IO.File]::WriteAllText($original, '{"ok":true}', [Text.UTF8Encoding]::new($false))
  $expectedHash = (Get-FileHash $original -Algorithm SHA256).Hash.ToLowerInvariant()
  if ((Hash $original) -ne $expectedHash) { throw 'wrong_hash' }
  if ((Read-Json $original).ok -ne $true) { throw 'wrong_json' }
  $held = Open-SharedRead $original
  try {
    # On Windows this fails if an observer omits FILE_SHARE_DELETE.
    Move-Item -LiteralPath $original -Destination $renamed
    if ($held.ReadByte() -ne [int][char]'{') { throw 'rename_lost_stream' }
  } finally { $held.Dispose() }
  if ((Hash $renamed) -ne $expectedHash) { throw 'rename_changed_bytes' }
  try { Require $false 'fixture_rejected'; throw 'missing_failure' }
  catch {
    if ($_.Exception.Data['migration-e2e-code'] -ne 'fixture_rejected') { throw 'lost_fixed_error_code' }
  }
  [IO.File]::WriteAllText($renamed, 'PRIVATE_FIXTURE_CONTENT')
  try { $null = Read-Json $renamed; throw 'accepted_bad_json' }
  catch {
    if ($_.Exception.Data['migration-e2e-code']) { throw 'raw_error_became_diagnostic' }
  }
  $culture = [Globalization.CultureInfo]::CurrentCulture
  try {
    $timestamp = '2026-10-20T14:15:16.0000000Z'
    $expectedTime = [DateTime]::new(2026, 10, 20, 14, 15, 16, [DateTimeKind]::Utc)
    Write-Json $renamed @{expires_utc=$timestamp; boot=$timestamp}
    foreach ($cultureName in @('en-US', 'en-GB', 'fr-FR')) {
      [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($cultureName)
      $roundtrip = Read-Json $renamed
      foreach ($value in @($roundtrip.expires_utc, $expectedTime.ToLocalTime(), $timestamp, '2026-10-20T07:15:16-07:00')) {
        $actual = ConvertTo-UtcTime $value
        if ($actual.Kind -ne [DateTimeKind]::Utc -or $actual -ne $expectedTime) { throw 'lease_expiry_changed' }
      }
      if ((ConvertTo-UtcTime $roundtrip.boot) -ne (ConvertTo-UtcTime $timestamp)) { throw 'unchanged_boot_accepted' }
      if ((ConvertTo-UtcTime $roundtrip.boot) -eq (ConvertTo-UtcTime $expectedTime.AddMinutes(1))) { throw 'changed_boot_rejected' }
    }
  } finally { [Globalization.CultureInfo]::CurrentCulture = $culture }
  foreach ($test in @(
    @{lane='rebuilt-staging'; environment='staging'; enabled=$false; scenario='success'; ready=$false; allowed=$true},
    @{lane='rebuilt-staging'; environment='staging'; enabled=$true; scenario='success'; ready=$false; allowed=$false},
    @{lane='production-beta-canary'; environment='prod'; enabled=$false; scenario='success'; ready=$false; allowed=$false},
    @{lane='production-beta-canary'; environment='prod'; enabled=$true; scenario='success'; ready=$false; allowed=$true},
    @{lane='production-beta-canary'; environment='staging'; enabled=$true; scenario='success'; ready=$false; allowed=$false},
    @{lane='production-beta-canary'; environment='prod'; enabled=$true; scenario='cancel'; ready=$false; allowed=$false},
    @{lane='production-beta-canary'; environment='prod'; enabled=$true; scenario='installer-failure'; ready=$false; allowed=$false},
    @{lane='production-beta-canary'; environment='prod'; enabled=$true; scenario='success'; ready=$true; allowed=$false},
    @{lane='other'; environment='prod'; enabled=$true; scenario='success'; ready=$false; allowed=$false}
  )) {
    $script:M = @{lane=$test.lane; account_environment=$test.environment; scenario=$test.scenario; production_activation_ready=$test.ready}
    if ($test.allowed) {
      Check-Lane $test.enabled
      if ($script:ProductionLane -ne ($test.environment -eq 'prod')) { throw 'wrong_lane_environment' }
    } else {
      try { Check-Lane $test.enabled; throw 'accepted_unsafe_lane' }
      catch {
        if ($_.Exception.Data['migration-e2e-code'] -notin @('invalid_migration_lane','production_canary_not_enabled')) { throw }
      }
    }
  }
  $script:LegacyExe = 'C:\fixture\lantern.exe'
  function Start-Process {
    param($FilePath, $ArgumentList, [switch]$PassThru)
    return @{path=$FilePath; arguments=$ArgumentList}
  }
  foreach ($production in @($false, $true)) {
    $script:ProductionLane = $production
    $launched = Launch-Legacy
    $expectedArguments = if ($production) {'-readableconfig'} else {'-readableconfig,-stickyconfig'}
    if ($launched.path -ne $script:LegacyExe -or ($launched.arguments -join ',') -ne $expectedArguments) { throw 'wrong_legacy_launch_flags' }
  }
  $script:Result = @{}
  $serviceCommand = '"C:\Program Files\Lantern\LanternSvc.exe" run'
  function Get-CimInstance {
    param($ClassName, $Filter)
    return $script:testService
  }
  foreach ($test in @(
    @{environment='staging'; arguments=' --environment staging'; allowed=$true},
    @{environment='staging'; arguments=' "--environment" "staging"'; allowed=$true},
    @{environment='staging'; arguments=' --environment=staging'; allowed=$true},
    @{environment='staging'; arguments=''; allowed=$false},
    @{environment='staging'; arguments=' --environment prod'; allowed=$false},
    @{environment='prod'; arguments=''; allowed=$true},
    @{environment='prod'; arguments=' --environment prod'; allowed=$true},
    @{environment='prod'; arguments=' "--environment" "prod"'; allowed=$true},
    @{environment='prod'; arguments=' --environment=prod'; allowed=$true},
    @{environment='prod'; arguments=' --environment staging'; allowed=$false},
    @{environment='prod'; arguments=' --environment production'; allowed=$false},
    @{environment='prod'; arguments=' --environment'; allowed=$false},
    @{environment='prod'; arguments=' --environment='; allowed=$false},
    @{environment='prod'; arguments=' --dotenv staging.env'; allowed=$false},
    @{environment='prod'; arguments=' --data-path C:\other'; allowed=$false},
    @{environment='prod'; arguments=' --ENVIRONMENT staging'; allowed=$false},
    @{environment='prod'; arguments=' --environment prod --environment staging'; allowed=$false},
    @{environment='staging'; arguments=' --environment staging --environment prod'; allowed=$false},
    @{environment='production'; arguments=''; allowed=$false}
  )) {
    $script:testService = @{State='Running'; StartName='LocalSystem'; StartMode='Auto'; PathName=($serviceCommand + $test.arguments)}
    if ($test.allowed) { Service-Ready $test.environment }
    else {
      try { Service-Ready $test.environment; throw 'accepted_wrong_service_environment' }
      catch { if ($_.Exception.Data['migration-e2e-code'] -ne 'service_environment_mismatch') { throw } }
    }
  }
  foreach ($change in @(
    @{State='Stopped'}, @{StartName='OtherUser'}, @{StartMode='Manual'},
    @{PathName='"C:\other\LanternSvc.exe" run'}, @{PathName='"C:\Program Files\Lantern\LanternSvc.exe" other'}
  )) {
    $script:testService = @{State='Running'; StartName='LocalSystem'; StartMode='Auto'; PathName=$serviceCommand}
    foreach ($key in $change.Keys) { $script:testService[$key] = $change[$key] }
    try { Service-Ready 'prod'; throw 'accepted_wrong_service' }
    catch { if ($_.Exception.Data['migration-e2e-code'] -notin @('service_not_ready','service_not_automatic','service_command_mismatch')) { throw } }
  }
  $script:M = @{endpoint='https://update.staging.iantem.io/update/lantern'; bridge_version='7.9.6'; installer_version='10.99.1';
    artifacts=@{seed=@{sha256=('a' * 64)}; bridge=@{sha256=('b' * 64)}; installer=@{sha256=('c' * 64)}}}
  $script:Result = @{}
  $script:routeOfferOverrides = @{}
  $script:routeOrigin = 'https://update.staging.iantem.io'
  function Invoke-WebRequest {
    param($Uri, $Method, $ContentType, $Body, $Headers, $MaximumRedirection, $TimeoutSec, [switch]$SkipHttpErrorCheck)
    $request = $Body | ConvertFrom-Json -AsHashtable
    $seed = $request.app_version -eq '7.9.5'
    if (-not $seed -and $request.tags.os_arch -ne 'amd64') { return @{StatusCode=204} }
    $hop = if ($seed) {'bridge'} else {'installer'}
    $version = if ($seed) {$script:M.bridge_version} else {$script:M.installer_version}
    $arch = if ($seed) {'386'} else {'amd64'}
    $offer = @{version=$version; initiative='auto'; patch_url=''; patch_type='';
      checksum=$script:M.artifacts[$hop].sha256; update_type=$(if ($seed) {'binary'} else {'installer'});
      target_arch=$arch; url="$script:routeOrigin/update/lantern/windows-migration/$arch/$version"}
    if ($script:routeOfferOverrides.ContainsKey($hop)) {
      foreach ($field in $script:routeOfferOverrides[$hop].Keys) {
        $offer[$field] = $script:routeOfferOverrides[$hop][$field]
      }
    }
    return @{StatusCode=200; Content=($offer | ConvertTo-Json -Compress)}
  }
  Check-Routes
  foreach ($badURL in @(
    'https://github.com/getlantern/lantern-update-fixtures/releases/download/v7.9.6/update_windows_386_7.9.6.bz2',
    'https://update.staging.iantem.io.evil.test/update/lantern/windows-migration/386/7.9.6',
    'http://update.staging.iantem.io/update/lantern/windows-migration/386/7.9.6',
    'https://user@update.staging.iantem.io/update/lantern/windows-migration/386/7.9.6',
    'https://update.staging.iantem.io/update/lantern/windows-migration/amd64/7.9.6',
    'https://update.staging.iantem.io/update/lantern/windows-migration/386/7.9.7',
    'https://update.staging.iantem.io/update/lantern/windows-migration/386/7.9.6?download=1',
    'https://update.staging.iantem.io/update/lantern/windows-migration/386/7.9.6#fragment'
  )) {
    $script:routeOfferOverrides = @{bridge=@{url=$badURL}}
    try { Check-Routes; throw 'accepted_wrong_download_url' }
    catch { if ($_.Exception.Data['migration-e2e-code'] -ne 'catalog_drift') { throw } }
  }
  $script:routeOfferOverrides = @{installer=@{url='https://update.staging.iantem.io/update/lantern/windows-migration/386/10.99.1'}}
  try { Check-Routes; throw 'accepted_wrong_installer_url' }
  catch { if ($_.Exception.Data['migration-e2e-code'] -ne 'catalog_drift') { throw } }
  foreach ($overrides in @(
    @{bridge=@{version='7.9.7'}},
    @{bridge=@{target_arch='amd64'}},
    @{installer=@{version='10.99.2'}},
    @{installer=@{target_arch='386'}}
  )) {
    $script:routeOfferOverrides = $overrides
    try { Check-Routes; throw 'accepted_wrong_offer' }
    catch { if ($_.Exception.Data['migration-e2e-code'] -ne 'catalog_drift') { throw } }
  }
  $script:M.endpoint = 'https://update.getlantern.org/update/lantern'
  $script:M.installer_version = '10.0.3-beta-4'
  $script:routeOrigin = 'https://update.getlantern.org'
  $script:routeOfferOverrides = @{}
  Check-Routes
  $script:routeOfferOverrides = @{installer=@{url='https://update.staging.iantem.io/update/lantern/windows-migration/amd64/10.0.3-beta-4'}}
  try { Check-Routes; throw 'accepted_staging_canary_download' }
  catch { if ($_.Exception.Data['migration-e2e-code'] -ne 'catalog_drift') { throw } }
  'PowerShell parser, read-sharing/error-code, UTC timestamp, lane, service and download routing checks passed'
} finally {
  # Only the unique directory created by this test is removed.
  Remove-Item -LiteralPath $temp -Recurse -Force
}
