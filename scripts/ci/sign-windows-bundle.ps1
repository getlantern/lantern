param(
  [Parameter(Mandatory)][string]$Directory,
  [Parameter(Mandatory)][string]$ManifestPath
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/windows-signing.ps1"

$binaries = @(Get-WindowsPayloadBinaries -Directory $Directory)
$unsigned = @($binaries | Where-Object { (Get-WindowsSigningDisposition $_) -eq 'Sign' })
$preserved = @($binaries | Where-Object { (Get-WindowsSigningDisposition $_) -eq 'Preserve' })
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('lantern-signing-' + [guid]::NewGuid())
try {
  if ($unsigned.Count -gt 0) {
    $stage = Join-Path $temporary 'payload'
    foreach ($binary in $unsigned) {
      $destination = Join-Path $stage $binary.Path
      $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination)
      Copy-Item -LiteralPath $binary.FullName -Destination $destination
      Write-Host "Signing $($binary.Path)"
    }
    $archive = Join-Path $temporary 'binaries.zip'
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive
    & "$PSScriptRoot/sign-windows.ps1" -FilePath $archive `
      -SigningPolicy $env:SIGNPATH_SIGNING_POLICY `
      -OrganizationId $env:SIGNPATH_ORG_ID -ProjectSlug $env:SIGNPATH_PROJECT_SLUG `
      -ApiToken $env:SIGNPATH_API_TOKEN -ArtifactConfigurationSlug 'zip-bundle' `
      -Description "Windows payload - GitHub Actions build $env:VERSION"
    # Copy only the requested paths out of the response. Missing entries fail;
    # a signing-service response cannot replace a vendor-signed file.
    $signed = Join-Path $temporary 'signed'
    Expand-Archive -LiteralPath $archive -DestinationPath $signed
    foreach ($binary in $unsigned) {
      Copy-Item -LiteralPath (Join-Path $signed $binary.Path) -Destination $binary.FullName -Force
    }
  }
  foreach ($binary in $preserved) {
    if ((Get-FileHash -LiteralPath $binary.FullName -Algorithm SHA256).Hash -ne $binary.Sha256) {
      throw "Vendor-signed binary changed: $($binary.Path)"
    }
  }
  Write-WindowsPayloadManifest -Directory $Directory -ManifestPath $ManifestPath
} finally {
  if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
