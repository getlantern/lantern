# Invoked by ISCC for its generated uninstaller and installer. Secrets stay in
# the environment, never in the compiler's displayed SignTool command line.
param([Parameter(Mandatory)][string]$FilePath)
$ErrorActionPreference = 'Stop'
# Inno may give its cached uninstaller a .e32 extension. Submit it as .exe so
# SignPath's PE artifact policy and our signature verification both apply.
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('lantern-inno-signing-' + [guid]::NewGuid())
try {
  $null = New-Item -ItemType Directory -Path $temporary
  $executable = Join-Path $temporary 'lantern-setup-component.exe'
  Copy-Item -LiteralPath $FilePath -Destination $executable
  & "$PSScriptRoot/sign-windows.ps1" -FilePath $executable `
    -SigningPolicy $env:SIGNPATH_SIGNING_POLICY `
    -OrganizationId $env:SIGNPATH_ORG_ID -ProjectSlug $env:SIGNPATH_PROJECT_SLUG `
    -ApiToken $env:SIGNPATH_API_TOKEN `
    -Description "Windows installer/uninstaller - GitHub Actions build $env:VERSION"
  Copy-Item -LiteralPath $executable -Destination $FilePath -Force
} finally {
  if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
