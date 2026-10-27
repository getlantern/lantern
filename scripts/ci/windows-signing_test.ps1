# Pure signing-policy and payload tests; Authenticode itself is exercised by the
# mandatory installed-candidate gate on Windows. No signing credentials needed.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/windows-signing.ps1"
$script:signatureOverrides = @{}
function Get-AuthenticodeSignature {
  param([string]$LiteralPath)
  if ($script:signatureOverrides.ContainsKey($LiteralPath)) {
    return $script:signatureOverrides[$LiteralPath]
  }
  [pscustomobject]@{
    Status = 'Valid'
    SignatureType = 'Authenticode'
    SignerCertificate = [pscustomobject]@{ Subject = 'CN=Test Vendor'; Thumbprint = '1234' }
  }
}

function Assert-Equal($Actual, $Expected) {
  if ($Actual -ne $Expected) { throw "Expected '$Expected', got '$Actual'" }
}
function Assert-Fails([scriptblock]$Action, [string]$Message) {
  $failure = $null
  try { & $Action } catch { $failure = $_ }
  if ($null -eq $failure) { throw "Expected failure containing '$Message'" }
  if (-not $failure.ToString().Contains($Message)) { throw "Unexpected failure: $failure" }
}
function Set-TestSignature([string]$Path, [string]$Status, [string]$Type = 'Authenticode') {
  $script:signatureOverrides[$Path] = [pscustomobject]@{
    Status = $Status; SignatureType = $Type
    SignerCertificate = [pscustomobject]@{ Subject = 'CN=Test'; Thumbprint = '5678' }
  }
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) ('lantern-signing-tests-' + [guid]::NewGuid())
try {
  $build = Join-Path $temporary 'build'
  $installed = Join-Path $temporary 'installed'
  $null = New-Item -ItemType Directory -Path "$build/installer-dependencies", $installed -Force
  foreach ($name in @('lantern.exe', 'lanternd.exe', 'flutter_windows.dll', 'WinSparkle.dll', 'installer-dependencies/VC_redist.x64.exe')) {
    Set-Content -LiteralPath (Join-Path $build $name) -Value "original $name"
  }
  $manifest = Join-Path $temporary 'manifest.json'
  $vendor = @(Get-WindowsPayloadBinaries $build | Where-Object Path -eq 'WinSparkle.dll')[0]
  Assert-Equal (Get-WindowsSigningDisposition $vendor) 'Preserve'
  foreach ($name in @('WinSparkle.dll', 'flutter_windows.dll')) {
    $path = Join-Path $build $name
    Set-TestSignature $path 'NotSigned' 'None'
    $binary = @(Get-WindowsPayloadBinaries $build | Where-Object Path -eq $name)[0]
    Assert-Equal (Get-WindowsSigningDisposition $binary) 'Sign'
    $script:signatureOverrides.Remove($path)
  }
  foreach ($status in @('HashMismatch', 'NotTrusted', 'UnknownError')) {
    $vendor.Signature.Status = $status
    Assert-Fails { Get-WindowsSigningDisposition $vendor } 'Refusing invalid existing signature'
  }
  $vendor.Signature.Status = 'Valid'
  $vendor.Signature.SignatureType = 'Catalog'
  Assert-Equal (Get-WindowsSigningDisposition $vendor) 'Sign'

  Write-WindowsPayloadManifest -Directory $build -ManifestPath $manifest
  Assert-WindowsPayloadManifest -Directory $build -ManifestPath $manifest
  $app = Join-Path $build 'lantern.exe'
  Set-Content -LiteralPath $app -Value 'recompiled after signing'
  Assert-Fails { Assert-WindowsPayloadManifest $build $manifest } 'differs from signed build'
  Set-Content -LiteralPath $app -Value 'original lantern.exe'
  Set-TestSignature $app 'NotSigned' 'None'
  Assert-Fails { Assert-WindowsPayloadManifest $build $manifest } 'Invalid embedded Authenticode'
  $script:signatureOverrides.Clear()

  Copy-Item -Path "$build/*.exe", "$build/*.dll" -Destination $installed
  $daemon = Join-Path $installed 'lanternd.exe'
  $service = Join-Path $installed 'LanternSvc.exe'
  Copy-Item -LiteralPath $daemon -Destination $service
  $uninstaller = Join-Path $installed 'unins000.exe'
  Set-Content -LiteralPath $uninstaller -Value 'generated signed uninstaller'
  Assert-WindowsPayloadManifest -Directory $installed -ManifestPath $manifest -Installed
  Set-TestSignature $uninstaller 'NotSigned' 'None'
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'Invalid embedded Authenticode'
  $script:signatureOverrides.Clear()
  Remove-Item -LiteralPath $uninstaller
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'Expected one signed Inno uninstaller'
  Set-Content -LiteralPath $uninstaller -Value 'generated signed uninstaller'

  Set-Content -LiteralPath $service -Value 'different signed service'
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'differs from signed build: LanternSvc.exe'
  Copy-Item -LiteralPath $daemon -Destination $service -Force
  Set-TestSignature $service 'NotSigned' 'None'
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'Invalid embedded Authenticode'
  $script:signatureOverrides.Clear()
  Remove-Item -LiteralPath $service
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'Missing signed binaries: LanternSvc.exe'
  Copy-Item -LiteralPath $daemon -Destination $service
  Remove-Item -LiteralPath $daemon
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'Missing signed binaries: lanternd.exe'
  Copy-Item -LiteralPath (Join-Path $build 'lanternd.exe') -Destination $daemon

  # With both daemons packaged, only the native architecture's copy is valid.
  # The preceding case also covers ARM64 falling back when no ARM64 daemon exists.
  $null = New-Item -ItemType Directory -Path "$build/arm64", "$installed/arm64"
  $armDaemon = Join-Path $installed 'arm64/lanternd.exe'
  Set-Content -LiteralPath "$build/arm64/lanternd.exe" -Value 'signed ARM64 daemon'
  Copy-Item -LiteralPath "$build/arm64/lanternd.exe" -Destination $armDaemon
  Write-WindowsPayloadManifest -Directory $build -ManifestPath $manifest
  $nativeDaemon, $wrongDaemon = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') {
    $armDaemon; $daemon
  } else { $daemon; $armDaemon }
  Copy-Item -LiteralPath $nativeDaemon -Destination $service -Force
  Assert-WindowsPayloadManifest $installed $manifest -Installed
  Copy-Item -LiteralPath $wrongDaemon -Destination $service -Force
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'differs from signed build: LanternSvc.exe'
  Copy-Item -LiteralPath $nativeDaemon -Destination $service -Force

  $unexpected = Join-Path $installed 'unexpected.dll'
  Set-Content -LiteralPath $unexpected -Value 'even a valid signature does not authorize extra payload'
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'Unexpected Windows binary'
  Remove-Item -LiteralPath $unexpected
  Remove-Item -LiteralPath (Join-Path $installed 'WinSparkle.dll')
  Assert-Fails { Assert-WindowsPayloadManifest $installed $manifest -Installed } 'Missing signed binaries'
  Write-Host 'Windows signing policy and payload regression tests passed'
} finally {
  if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
