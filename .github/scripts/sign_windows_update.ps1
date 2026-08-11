[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InstallerPath,

  [Parameter(Mandatory = $true)]
  [string]$SignaturePath,

  [string]$PrivateKey = $env:SPARKLE_ED_PRIVATE_KEY,

  [string]$ResourcePath = "windows\runner\Runner.rc",

  [string]$MacOSInfoPlistPath = "macos\Runner\Info.plist",

  [string]$SignerPath = "",

  [string]$TemporaryDirectory = $env:RUNNER_TEMP
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-NativeCommandSucceeded {
  param([Parameter(Mandatory = $true)][string]$Message)

  if ($LASTEXITCODE -ne 0) {
    throw "$Message (exit code $LASTEXITCODE)"
  }
}

if ([string]::IsNullOrWhiteSpace($PrivateKey)) {
  throw "SPARKLE_ED_PRIVATE_KEY is required for Windows update signing"
}
if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
  throw "Windows installer not found: $InstallerPath"
}
if (-not (Test-Path -LiteralPath $ResourcePath -PathType Leaf)) {
  throw "Windows resource file not found: $ResourcePath"
}
if (-not (Test-Path -LiteralPath $MacOSInfoPlistPath -PathType Leaf)) {
  throw "macOS Info.plist not found: $MacOSInfoPlistPath"
}

$resourceContents = Get-Content -LiteralPath $ResourcePath -Raw
$resourceMatch = [regex]::Match(
  $resourceContents,
  'EdDSAPub\s+EDDSA\s+\{"([A-Za-z0-9+/=]+)"\}'
)
if (-not $resourceMatch.Success) {
  throw "EdDSAPub resource not found in $ResourcePath"
}
$publicKey = $resourceMatch.Groups[1].Value

$infoPlistContents = Get-Content -LiteralPath $MacOSInfoPlistPath -Raw
$infoPlistMatch = [regex]::Match(
  $infoPlistContents,
  '<key>\s*SUPublicEDKey\s*</key>\s*<string>\s*([^<\s]+)\s*</string>'
)
if (-not $infoPlistMatch.Success) {
  throw "SUPublicEDKey not found in $MacOSInfoPlistPath"
}
if ($infoPlistMatch.Groups[1].Value -ne $publicKey) {
  throw "Windows and macOS update public keys do not match"
}

if ([string]::IsNullOrWhiteSpace($SignerPath)) {
  $signerRoot = "windows\flutter\ephemeral\.plugin_symlinks\auto_updater_windows\windows"
  if (-not (Test-Path -LiteralPath $signerRoot -PathType Container)) {
    throw "WinSparkle plugin directory not found: $signerRoot"
  }
  $signerCandidates = @(
    Get-ChildItem -LiteralPath $signerRoot -Filter "winsparkle-tool.exe" -File -Recurse
  )
  if ($signerCandidates.Count -ne 1) {
    throw "Expected one WinSparkle signer under $signerRoot, found $($signerCandidates.Count)"
  }
  $SignerPath = $signerCandidates[0].FullName
}
if (-not (Test-Path -LiteralPath $SignerPath -PathType Leaf)) {
  throw "WinSparkle signer not found: $SignerPath"
}
if ([string]::IsNullOrWhiteSpace($TemporaryDirectory)) {
  $TemporaryDirectory = [System.IO.Path]::GetTempPath()
}

$null = New-Item -ItemType Directory -Force -Path $TemporaryDirectory
$signaturePath = [System.IO.Path]::GetFullPath($SignaturePath)
$signatureDirectory = Split-Path -Parent $signaturePath
$null = New-Item -ItemType Directory -Force -Path $signatureDirectory

$temporaryPrefix = Join-Path $TemporaryDirectory "winsparkle-$([guid]::NewGuid().ToString('N'))"
$privateKeyPath = "$temporaryPrefix-private.key"
$temporarySignaturePath = "$temporaryPrefix-signature.txt"

try {
  [System.IO.File]::WriteAllText(
    $privateKeyPath,
    $PrivateKey.Trim(),
    [System.Text.Encoding]::ASCII
  )

  $signatureOutput = & $SignerPath sign --private-key-file $privateKeyPath $InstallerPath
  Assert-NativeCommandSucceeded "WinSparkle signing failed"

  $signature = ($signatureOutput -join "").Trim()
  if ([string]::IsNullOrWhiteSpace($signature)) {
    throw "WinSparkle produced an empty Windows update signature"
  }
  try {
    $decodedSignature = [Convert]::FromBase64String($signature)
  }
  catch {
    throw "WinSparkle produced an invalid base64 signature"
  }
  if ($decodedSignature.Length -ne 64) {
    throw "WinSparkle produced an invalid EdDSA signature length: $($decodedSignature.Length)"
  }

  & $SignerPath verify --public-key $publicKey --signature $signature $InstallerPath
  Assert-NativeCommandSucceeded "Windows update signature verification failed"

  [System.IO.File]::WriteAllText(
    $temporarySignaturePath,
    "$signature`n",
    [System.Text.Encoding]::ASCII
  )
  Move-Item -LiteralPath $temporarySignaturePath -Destination $signaturePath -Force
}
finally {
  Remove-Item -Force -ErrorAction SilentlyContinue $privateKeyPath, $temporarySignaturePath
}
