param(
  [string]$Exe = "$PSScriptRoot\..\..\bin\windows-amd64\lanternd.exe"
)

$ErrorActionPreference = "Stop"

$ExeFull = (Resolve-Path $Exe).Path
if (-not (Test-Path $ExeFull)) {
  throw "lanternd binary not found at $ExeFull"
}

Write-Host "Installing lanternd service via: $ExeFull install"
& $ExeFull install
if ($LASTEXITCODE -ne 0) {
  throw "lanternd install failed with exit code $LASTEXITCODE"
}

Write-Host "`nService installed and started."
sc.exe qc LanternSvc
sc.exe query LanternSvc