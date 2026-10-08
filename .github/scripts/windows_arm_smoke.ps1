param(
  [Parameter(Mandatory = $true)][string]$InstallerPath,
  [Parameter(Mandatory = $true)][string]$UpgradeFromInstallerPath,
  [Parameter(Mandatory = $true)][string]$VpnTestAppPath,
  [Parameter(Mandatory = $true)][string]$VCRedistPath,
  [Parameter(Mandatory = $true)][string]$ArtifactDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$AppDirectory = 'C:\Program Files\Lantern'
$AppExecutable = Join-Path $AppDirectory 'lantern.exe'
$ServiceName = 'LanternSvc'
$script:AppProcess = $null
$script:Result = 'failure'

function Write-Step([string]$Message) {
  Write-Host "[ARM smoke] $Message"
}

function Get-PeMachine([string]$Path) {
  $stream = [System.IO.File]::OpenRead($Path)
  $reader = [System.IO.BinaryReader]::new($stream)
  try {
    if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5A4D) {
      throw "Invalid DOS header: $Path"
    }
    $stream.Position = 0x3C
    $offset = $reader.ReadUInt32()
    if ($offset -lt 64 -or $offset -gt $stream.Length - 6) {
      throw "Invalid PE header offset: $Path"
    }
    $stream.Position = $offset
    if ($reader.ReadUInt32() -ne 0x00004550) {
      throw "Invalid PE signature: $Path"
    }
    return $reader.ReadUInt16()
  } finally {
    $reader.Dispose()
    $stream.Dispose()
  }
}

function Get-ServiceExecutablePath([string]$PathName) {
  if ($PathName -match '^\s*"([^"]+\.exe)"(?:\s|$)') { return $Matches[1] }
  if ($PathName -match '^\s*([^\s"]+\.exe)(?:\s|$)') { return $Matches[1] }
  throw "Cannot parse service executable: $PathName"
}

function Invoke-Checked {
  param([string]$Path, [string[]]$Arguments, [int[]]$AllowedExitCodes = @(0))
  Write-Step "Running $Path"
  $process = Start-Process -FilePath $Path -ArgumentList $Arguments -PassThru
  if (-not $process.WaitForExit(300000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "Process timed out: $Path"
  }
  if ($process.ExitCode -notin $AllowedExitCodes) {
    throw "$Path failed with exit code $($process.ExitCode)"
  }
}

function Invoke-Setup([string]$Path, [string]$LogName) {
  $log = Join-Path $ArtifactDirectory "$LogName.log"
  Invoke-Checked $Path @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/LOG=`"$log`"")
}

function Install-Lantern([string]$Path, [string]$Label) {
  Invoke-Setup $Path "installer-$Label"
  Assert-ArmService
}

function Assert-ArmService {
  $deadline = [DateTime]::UtcNow.AddSeconds(60)
  do {
    $service = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'"
    if ($service -and $service.State -eq 'Running') { break }
    Start-Sleep -Seconds 1
  } while ([DateTime]::UtcNow -lt $deadline)
  if (-not $service -or $service.State -ne 'Running' -or $service.ProcessId -eq 0) {
    throw 'The installer did not register and start LanternSvc'
  }
  $servicePath = Get-ServiceExecutablePath $service.PathName
  $armPayload = Join-Path $AppDirectory 'arm64\lanternd.exe'
  if ((Get-PeMachine $servicePath) -ne 0xAA64 -or
      (Get-FileHash $servicePath).Hash -ne (Get-FileHash $armPayload).Hash) {
    throw "The installed service is not the packaged ARM64 daemon: $servicePath"
  }
  $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($service.ProcessId)"
  if (-not $process -or $process.ExecutablePath -ine $servicePath) {
    throw 'The running service does not match its registered executable'
  }
  $service | Select-Object Name, State, PathName, ProcessId |
    ConvertTo-Json | Set-Content (Join-Path $ArtifactDirectory 'service.json')
  Write-Step 'Installer registered and started the native ARM64 service'
}

function Get-ArmRuntime {
  $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
    [Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
  try {
    $runtime = $base.OpenSubKey('SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\arm64')
    if ($runtime) {
      try {
        return [pscustomobject]@{ Installed = $runtime.GetValue('Installed'); Version = $runtime.GetValue('Version') }
      } finally { $runtime.Dispose() }
    }
  } finally { $base.Dispose() }
}

function Assert-Prerequisites {
  $runtime = Get-ArmRuntime
  if (-not $runtime -or $runtime.Installed -ne 1) { throw 'ARM64 Visual C++ runtime is missing' }
  $version = [version]([string]$runtime.Version).TrimStart('v', 'V')
  $required = [version][System.Diagnostics.FileVersionInfo]::GetVersionInfo($VCRedistPath).FileVersion
  if ($version -lt $required) { throw "ARM64 Visual C++ runtime $version does not meet $required" }
  Write-Step "ARM64 Visual C++ runtime $version is installed"

  $webViewKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}',
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
  )
  $webView = @($webViewKeys | ForEach-Object {
      if (Test-Path $_) { Get-ItemPropertyValue $_ -Name pv -ErrorAction SilentlyContinue }
    } | Where-Object { $_ -and $_ -ne '0.0.0.0' })
  if ($webView.Count -eq 0) { throw 'WebView2 runtime is missing after installation' }
  if ((Get-PeMachine $AppExecutable) -ne 0x8664) { throw 'Expected the packaged x64 Flutter UI' }
}

function Reset-VCRuntime {
  # Remove the hosted image's v14 bundles so setup must install its own payload.
  $bundles = @(Get-ItemProperty @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    ) | Where-Object {
      $_.PSObject.Properties['DisplayName'] -and
      $_.DisplayName -match '^Microsoft Visual C\+\+ (2015(?:-2022)?|v14) Redistributable \((x64|arm64)\)'
    })
  foreach ($bundle in $bundles) {
    $path = Get-ServiceExecutablePath $bundle.UninstallString
    $log = Join-Path $ArtifactDirectory "runtime-uninstall-$($bundle.PSChildName).log"
    Invoke-Checked $path @('/uninstall', '/quiet', '/norestart', "/log `"$log`"") @(0, 1605, 3010)
  }
  $runtime = Get-ArmRuntime
  if ($runtime -and $runtime.Installed -eq 1) {
    throw 'ARM64 Visual C++ runtime is still installed; cannot exercise the missing-prerequisite path'
  }
}

function Start-InstalledUi([string]$Label) {
  $script:AppProcess = Start-Process $AppExecutable -WorkingDirectory $AppDirectory -PassThru
  $deadline = [DateTime]::UtcNow.AddSeconds(90)
  do {
    $script:AppProcess.Refresh()
    if ($script:AppProcess.HasExited) { throw 'Installed Lantern UI exited during startup' }
    if ($script:AppProcess.MainWindowHandle -ne 0 -and $script:AppProcess.Responding) { break }
    Start-Sleep -Seconds 1
  } while ([DateTime]::UtcNow -lt $deadline)
  if ($script:AppProcess.MainWindowHandle -eq 0 -or -not $script:AppProcess.Responding) {
    throw 'Installed Lantern UI did not render a responsive window'
  }
  Start-Sleep -Seconds 10
  $script:AppProcess.Refresh()
  if ($script:AppProcess.HasExited -or -not $script:AppProcess.Responding) {
    throw 'Installed Lantern UI stopped responding after startup'
  }
  Save-Screenshot $Label
  Write-Step 'Installed x64 UI rendered and remained responsive on ARM64 Windows'
}

function Stop-InstalledUi {
  if ($script:AppProcess -and -not $script:AppProcess.HasExited) {
    Stop-Process -Id $script:AppProcess.Id -Force
    $script:AppProcess.WaitForExit(10000) | Out-Null
  }
  $script:AppProcess = $null
}

function Get-LanternRegistration {
  Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object { $_.PSObject.Properties['InstallLocation'] -and $_.InstallLocation -and $_.InstallLocation.TrimEnd('\') -ieq $AppDirectory }
}

function Get-InstalledVersion {
  $entries = @(Get-LanternRegistration)
  if ($entries.Count -ne 1) { throw 'Expected one Lantern uninstall registration' }
  return [version]($entries[0].DisplayVersion -split '\+', 2)[0]
}

function Get-NetworkConfiguration {
  foreach ($config in Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }) {
    $dns = (Get-DnsClientServerAddress -InterfaceIndex $config.InterfaceIndex -AddressFamily IPv4).ServerAddresses
    $gateways = @($config.IPv4DefaultGateway | ForEach-Object { $_.NextHop })
    "interface=$($config.InterfaceIndex);dns=$($dns -join ',');gateways=$($gateways -join ',')"
  }
}

function Uninstall-Lantern {
  $uninstaller = @(Get-ChildItem $AppDirectory -Filter 'unins*.exe' -File)
  if ($uninstaller.Count -ne 1) { throw 'Expected the installed Lantern uninstaller' }
  Invoke-Setup $uninstaller[0].FullName 'uninstall'
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  while ((Get-Service $ServiceName -ErrorAction SilentlyContinue) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Seconds 1
  }
  if ((Get-Service $ServiceName -ErrorAction SilentlyContinue) -or (Test-Path $AppExecutable) -or
      (Test-Path (Join-Path $AppDirectory 'LanternSvc.exe'))) {
    throw 'Uninstall left the Lantern service or UI executable installed'
  }
  if (Get-LanternRegistration) { throw 'Uninstall left Lantern registered' }
  Write-Step 'Uninstall removed the app, service and uninstall registration'
}

function Save-Screenshot([string]$Label) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bitmap = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save((Join-Path $ArtifactDirectory "$Label.png"))
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

function Save-DaemonLogs {
  $logs = Join-Path $env:ProgramData 'Lantern'
  $destination = Join-Path $ArtifactDirectory 'daemon-logs'
  New-Item -ItemType Directory $destination -Force | Out-Null
  Get-ChildItem $logs -Filter '*.log' -File -ErrorAction SilentlyContinue |
    Copy-Item -Destination $destination -Force
}

if ($env:GITHUB_ACTIONS -ne 'true' -or $env:LANTERN_WINDOWS_ARM_SMOKE -ne 'true' -or
    [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'Arm64' -or
    [Environment]::OSVersion.Version.Build -lt 22000) {
  throw 'This smoke test requires its explicit GitHub Actions guard and Windows 11 ARM64'
}
foreach ($path in @($InstallerPath, $UpgradeFromInstallerPath, $VpnTestAppPath, $VCRedistPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required artifact is missing: $path" }
}
if ((Get-PeMachine $VpnTestAppPath) -ne 0x8664) { throw 'VPN test app must use the packaged UI architecture (x64)' }
if ((Get-Service $ServiceName -ErrorAction SilentlyContinue) -or (Test-Path $AppDirectory)) {
  throw 'The hosted ARM runner must start without Lantern installed'
}
New-Item -ItemType Directory -Path $ArtifactDirectory -Force | Out-Null

try {
  Reset-VCRuntime
  Install-Lantern $UpgradeFromInstallerPath 'before-upgrade'
  if ((Get-Content (Join-Path $ArtifactDirectory 'installer-before-upgrade.log') -Raw) -notmatch
      'Starting dependency: Microsoft Visual C\+\+ Runtime') {
    throw 'Setup did not exercise the bundled Visual C++ prerequisite'
  }
  Assert-Prerequisites
  $before = Get-InstalledVersion
  Start-InstalledUi 'before-upgrade'
  Stop-InstalledUi

  Install-Lantern $InstallerPath 'after-upgrade'
  $after = Get-InstalledVersion
  if ($after -le $before) { throw "Installer did not upgrade the registered version: $before -> $after" }
  Write-Step "Installer upgraded $before -> $after"
  Assert-Prerequisites
  Start-InstalledUi 'after-upgrade'
  Stop-InstalledUi

  $networkBefore = @(Get-NetworkConfiguration | Sort-Object)
  if ($networkBefore.Count -eq 0) { throw 'No baseline network adapter with a default gateway' }
  $networkBefore | Set-Content (Join-Path $ArtifactDirectory 'network-before.txt')
  & flutter drive --profile --device-id=windows `
    --target=integration_test/vpn/windows_connect_smoke_test.dart `
    --driver=test_driver/integration_test.dart `
    "--use-application-binary=$VpnTestAppPath" 2>&1 |
    Tee-Object (Join-Path $ArtifactDirectory 'vpn.log')
  if ($LASTEXITCODE -ne 0) { throw "Flutter VPN E2E failed with exit code $LASTEXITCODE" }
  $networkAfter = @(Get-NetworkConfiguration | Sort-Object)
  $networkAfter | Set-Content (Join-Path $ArtifactDirectory 'network-after.txt')
  if (Compare-Object $networkBefore $networkAfter) {
    throw 'Adapter DNS servers or default gateways were not restored after disconnect'
  }
  Assert-ArmService
  Stop-InstalledUi
  Save-DaemonLogs
  Uninstall-Lantern
  $script:Result = 'success'
} finally {
  try {
    Save-DaemonLogs
    Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddMinutes(-30); Level = @(1, 2) } -ErrorAction SilentlyContinue |
      Select-Object TimeCreated, ProviderName, Message | Format-List |
      Out-File (Join-Path $ArtifactDirectory 'application-errors.txt')
  } catch { Write-Warning "Could not collect diagnostics: $_" }
  if ($script:Result -ne 'success') {
    try { Save-Screenshot 'failure' } catch { Write-Warning "Could not capture screenshot: $_" }
    try {
      Stop-InstalledUi
      if (Test-Path $AppDirectory) { Uninstall-Lantern }
    } catch { Write-Warning "Cleanup failed: $_" }
  }
  $script:Result | Set-Content (Join-Path $ArtifactDirectory 'result.txt')
}
