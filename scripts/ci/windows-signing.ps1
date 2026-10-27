# Shared by signing, the packaging gate, and installed-candidate verification.
Set-StrictMode -Version Latest

function Get-WindowsPayloadBinaries {
  param([Parameter(Mandatory)][string]$Directory)
  $root = (Resolve-Path -LiteralPath $Directory).Path
  $files = @(Get-ChildItem -LiteralPath $root -Recurse -File |
    Where-Object { $_.Extension -in @('.exe', '.dll') } | Sort-Object FullName)
  if ($files.Count -eq 0) { throw "No Windows binaries found in $root" }
  foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
    $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
    [pscustomobject]@{
      Path = $relative
      FullName = $file.FullName
      Signature = $signature
      Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }
}

function Get-WindowsSigningDisposition {
  param([Parameter(Mandatory)]$Binary)
  $signature = $Binary.Signature
  if ($signature.Status -eq 'Valid' -and $signature.SignatureType -eq 'Authenticode') {
    return 'Preserve'
  }
  # A catalog signature may exist only on the build machine. Embed a signature
  # so the same bytes can be authenticated on the customer's machine.
  if ($signature.Status -eq 'NotSigned' -or
      ($signature.Status -eq 'Valid' -and $signature.SignatureType -eq 'Catalog')) {
    return 'Sign'
  }
  throw "Refusing invalid existing signature: $($Binary.Path): $($signature.Status)"
}

function Assert-WindowsBinarySignature {
  param([Parameter(Mandatory)]$Binary)
  if ($Binary.Signature.Status -ne 'Valid' -or
      $Binary.Signature.SignatureType -ne 'Authenticode') {
    throw "Invalid embedded Authenticode signature: $($Binary.Path): $($Binary.Signature.Status) ($($Binary.Signature.SignatureType))"
  }
}

function Write-WindowsPayloadManifest {
  param(
    [Parameter(Mandatory)][string]$Directory,
    [Parameter(Mandatory)][string]$ManifestPath
  )
  $entries = @(foreach ($binary in Get-WindowsPayloadBinaries -Directory $Directory) {
    Assert-WindowsBinarySignature $binary
    [ordered]@{
      path = $binary.Path
      sha256 = $binary.Sha256
      signer = $binary.Signature.SignerCertificate.Subject
      thumbprint = $binary.Signature.SignerCertificate.Thumbprint
      installed = -not $binary.Path.StartsWith('installer-dependencies/', [StringComparison]::OrdinalIgnoreCase)
    }
  })
  $parent = Split-Path -Parent ([IO.Path]::GetFullPath($ManifestPath))
  $null = New-Item -ItemType Directory -Force -Path $parent
  [ordered]@{ schema_version = 1; binaries = $entries } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding utf8
}

function Assert-WindowsPayloadManifest {
  param(
    [Parameter(Mandatory)][string]$Directory,
    [Parameter(Mandatory)][string]$ManifestPath,
    [switch]$Installed
  )
  $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
  if ($manifest.schema_version -ne 1 -or @($manifest.binaries).Count -eq 0) {
    throw 'Empty or unsupported signed Windows payload manifest'
  }
  $expected = @{}
  foreach ($entry in $manifest.binaries) {
    if ($Installed -and -not $entry.installed) { continue }
    if ($expected.ContainsKey($entry.path)) { throw "Duplicate manifest path: $($entry.path)" }
    $expected[$entry.path] = $entry.sha256
  }
  if ($expected.Count -eq 0) { throw 'Manifest contains no installed binaries' }
  if ($Installed) {
    # lanternd install copies itself to LanternSvc.exe. Match Inno's native
    # daemon selection and require the copy to retain the signed build's bytes.
    $daemon = 'lanternd.exe'
    if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64' -and
        $expected.ContainsKey('arm64/lanternd.exe')) { $daemon = 'arm64/lanternd.exe' }
    if (-not $expected.ContainsKey($daemon)) { throw "Manifest is missing the service source: $daemon" }
    $expected.Add('LanternSvc.exe', $expected[$daemon])
  }
  $uninstallers = 0
  foreach ($binary in Get-WindowsPayloadBinaries -Directory $Directory) {
    Assert-WindowsBinarySignature $binary
    if ($expected.ContainsKey($binary.Path)) {
      if ($binary.Sha256 -ne $expected[$binary.Path]) {
        throw "Packaged binary differs from signed build: $($binary.Path)"
      }
      $expected.Remove($binary.Path)
    } elseif ($Installed -and $binary.Path -match '^unins\d{3}\.exe$') {
      # Inno generates and signs this executable while compiling the installer.
      $uninstallers++
    } else {
      throw "Unexpected Windows binary in payload: $($binary.Path)"
    }
  }
  if ($expected.Count -gt 0) { throw "Missing signed binaries: $($expected.Keys -join ', ')" }
  if ($Installed -and $uninstallers -ne 1) { throw "Expected one signed Inno uninstaller; found $uninstallers" }
}
