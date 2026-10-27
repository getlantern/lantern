param(
  [Parameter(Mandatory)][string]$Directory,
  [Parameter(Mandatory)][string]$ManifestPath,
  [switch]$Installed
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/windows-signing.ps1"
Assert-WindowsPayloadManifest -Directory $Directory -ManifestPath $ManifestPath -Installed:$Installed
Write-Host "Verified signatures and signed-build hashes in $Directory"
