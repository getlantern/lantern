[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InstallerPath,

  [Parameter(Mandatory = $true)]
  [string]$SignaturePath,

  [string]$PrivateKey = $env:WINSPARKLE_DSA_PRIVATE_KEY,

  [string]$PublicKeyPath = "windows\dsa_pub.pem",

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
  throw "WINSPARKLE_DSA_PRIVATE_KEY is required for Windows update signing"
}
if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
  throw "Windows installer not found: $InstallerPath"
}
if (-not (Test-Path -LiteralPath $PublicKeyPath -PathType Leaf)) {
  throw "WinSparkle public key not found: $PublicKeyPath"
}
if ([string]::IsNullOrWhiteSpace($SignerPath)) {
  $signerRoot = "windows\flutter\ephemeral\.plugin_symlinks\auto_updater_windows\windows"
  if (-not (Test-Path -LiteralPath $signerRoot -PathType Container)) {
    throw "WinSparkle plugin directory not found: $signerRoot"
  }
  $signerCandidates = @(
    Get-ChildItem -LiteralPath $signerRoot -Filter "sign_update.bat" -File -Recurse
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

$null = Get-Command openssl -ErrorAction Stop
$null = New-Item -ItemType Directory -Force -Path $TemporaryDirectory
$signatureDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($SignaturePath))
$null = New-Item -ItemType Directory -Force -Path $signatureDirectory

$temporaryPrefix = Join-Path $TemporaryDirectory "winsparkle-$([guid]::NewGuid().ToString('N'))"
$privateKeyPath = "$temporaryPrefix-private.pem"
$signatureTextPath = "$temporaryPrefix-signature.txt"
$signatureBinaryPath = "$temporaryPrefix-signature.bin"
$digestPath = "$temporaryPrefix-installer.sha1"

try {
  [System.IO.File]::WriteAllText(
    $privateKeyPath,
    $PrivateKey,
    [System.Text.Encoding]::ASCII
  )

  $signatureOutput = & $SignerPath $InstallerPath $privateKeyPath
  Assert-NativeCommandSucceeded "WinSparkle signing failed"

  $signature = ($signatureOutput -join "").Trim()
  if ([string]::IsNullOrWhiteSpace($signature)) {
    throw "WinSparkle produced an empty Windows update signature"
  }
  [System.IO.File]::WriteAllText(
    $signatureTextPath,
    $signature,
    [System.Text.Encoding]::ASCII
  )

  & openssl enc -base64 -d -A -in $signatureTextPath -out $signatureBinaryPath
  Assert-NativeCommandSucceeded "Unable to decode the WinSparkle signature"

  & openssl dgst -sha1 -binary -out $digestPath $InstallerPath
  Assert-NativeCommandSucceeded "Unable to hash the Windows installer"

  & openssl dgst -sha1 -verify $PublicKeyPath -signature $signatureBinaryPath $digestPath
  Assert-NativeCommandSucceeded "Windows update signature verification failed"

  [System.IO.File]::WriteAllText(
    $SignaturePath,
    "$signature`n",
    [System.Text.Encoding]::ASCII
  )
}
finally {
  Remove-Item -Force -ErrorAction SilentlyContinue `
    $privateKeyPath, $signatureTextPath, $signatureBinaryPath, $digestPath
}
