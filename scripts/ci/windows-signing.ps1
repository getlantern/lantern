param(
  [Parameter(Mandatory)][ValidateSet('Sign', 'Verify', 'SignInstaller')][string]$Action,
  [string]$Directory,
  [string]$ManifestPath,
  [string]$FilePath,
  [switch]$Installed
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Action -eq 'SignInstaller') {
  if ([string]::IsNullOrWhiteSpace($FilePath)) { throw '-Action SignInstaller requires -FilePath' }
} elseif ([string]::IsNullOrWhiteSpace($Directory) -or [string]::IsNullOrWhiteSpace($ManifestPath)) {
  throw "-Action $Action requires -Directory and -ManifestPath"
}

function Invoke-Signing([string]$Path, [string]$Configuration = '') {
  & "$PSScriptRoot/sign-windows.ps1" -FilePath $Path `
    -SigningPolicy $env:SIGNPATH_SIGNING_POLICY `
    -OrganizationId $env:SIGNPATH_ORG_ID -ProjectSlug $env:SIGNPATH_PROJECT_SLUG `
    -ApiToken $env:SIGNPATH_API_TOKEN -ArtifactConfigurationSlug $Configuration `
    -Description "Windows build $env:VERSION"
}

# Inno's cached uninstaller may have a .e32 extension. Submit it as .exe so
# SignPath's PE policy and our embedded-signature verification both apply.
if ($Action -eq 'SignInstaller') {
  $temporary = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
  $null = New-Item -ItemType Directory -Path $temporary
  try {
    $executable = Join-Path $temporary 'setup.exe'
    Copy-Item -LiteralPath $FilePath -Destination $executable
    Invoke-Signing $executable
    Copy-Item -LiteralPath $executable -Destination $FilePath -Force
  } finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force
  }
  return
}

$root = (Resolve-Path -LiteralPath $Directory).Path
$binaries = @(Get-ChildItem -LiteralPath $root -Recurse -File |
  Where-Object { $_.Extension -in @('.exe', '.dll') })
if ($binaries.Count -eq 0) { throw "No Windows binaries found in $root" }

if ($Action -eq 'Sign') {
  $temporary = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
  $stage = Join-Path $temporary 'payload'
  try {
    $unsigned = @(foreach ($binary in $binaries) {
      $signature = Get-AuthenticodeSignature -LiteralPath $binary.FullName
      if ($signature.Status -eq 'Valid' -and $signature.SignatureType -eq 'Authenticode') { continue }
      # Machine-local catalog signatures are not portable to customer machines.
      if ($signature.Status -ne 'NotSigned' -and
          -not ($signature.Status -eq 'Valid' -and $signature.SignatureType -eq 'Catalog')) {
        throw "Refusing invalid existing signature: $($binary.FullName): $($signature.Status)"
      }
      $relative = [IO.Path]::GetRelativePath($root, $binary.FullName)
      $destination = Join-Path $stage $relative
      $null = New-Item -ItemType Directory -Force -Path (Split-Path $destination)
      Copy-Item -LiteralPath $binary.FullName -Destination $destination
      $relative
    })
    if ($unsigned.Count -gt 0) {
      $archive = Join-Path $temporary 'binaries.zip'
      Compress-Archive -Path "$stage/*" -DestinationPath $archive
      Invoke-Signing $archive 'zip-bundle'
      $signed = Join-Path $temporary 'signed'
      Expand-Archive -LiteralPath $archive -DestinationPath $signed
      # Copy only submitted files, preserving every vendor-signed original.
      foreach ($relative in $unsigned) {
        Copy-Item -LiteralPath (Join-Path $signed $relative) -Destination (Join-Path $root $relative) -Force
      }
    }
  } finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
  }
} else {
  $expected = @{} + (Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json -AsHashtable)
  if ($Installed) {
    foreach ($path in @($expected.Keys)) {
      if ($path.StartsWith('installer-dependencies/', [StringComparison]::OrdinalIgnoreCase)) {
        $expected.Remove($path)
      }
    }
    # Service installation copies the native lanternd executable to LanternSvc.exe.
    $daemon = 'lanternd.exe'
    if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64' -and
        $expected.ContainsKey('arm64/lanternd.exe')) { $daemon = 'arm64/lanternd.exe' }
    if (-not $expected.ContainsKey($daemon)) { throw "Manifest is missing the service source: $daemon" }
    $expected['LanternSvc.exe'] = $expected[$daemon]
  }
  if ($expected.Count -eq 0) { throw 'Empty signed Windows payload manifest' }
}

$manifest = [ordered]@{}
$uninstallers = 0
foreach ($binary in $binaries) {
  $relative = [IO.Path]::GetRelativePath($root, $binary.FullName).Replace('\', '/')
  $signature = Get-AuthenticodeSignature -LiteralPath $binary.FullName
  if ($signature.Status -ne 'Valid' -or $signature.SignatureType -ne 'Authenticode') {
    throw "Invalid embedded signature: ${relative}: $($signature.Status)"
  }
  $hash = (Get-FileHash -LiteralPath $binary.FullName -Algorithm SHA256).Hash
  if ($Action -eq 'Sign') {
    $manifest[$relative] = $hash
  } elseif ($expected.ContainsKey($relative)) {
    if ($hash -ne $expected[$relative]) { throw "Packaged binary differs from signed build: $relative" }
    $expected.Remove($relative)
  } elseif ($Installed -and $relative -match '^unins\d{3}\.exe$') {
    $uninstallers++
  } else {
    throw "Unexpected Windows binary: $relative"
  }
}
if ($Action -eq 'Sign') {
  $null = New-Item -ItemType Directory -Force -Path (Split-Path ([IO.Path]::GetFullPath($ManifestPath)))
  $manifest | ConvertTo-Json | Set-Content -LiteralPath $ManifestPath -Encoding utf8
} else {
  if ($expected.Count -gt 0) { throw "Missing signed binaries: $($expected.Keys -join ', ')" }
  if ($Installed -and $uninstallers -ne 1) { throw "Expected one signed uninstaller; found $uninstallers" }
}
