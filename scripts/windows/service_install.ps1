param(
  [string]$Name = "LanternSvc",
  [string]$Exe  = "$PSScriptRoot\..\..\bin\windows-amd64\lanternsvc.exe",
  [string]$Args = "--service"
  [string]$DisplayName = "Lantern Service (dev)"
)

$ErrorActionPreference = "Stop"

$ExeFull = (Resolve-Path $Exe).Path
if (-not (Test-Path $ExeFull)) {
  throw "Service binary not found at $ExeFull"
}

$svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
if ($svc) {
  if ($svc.Status -ne 'Stopped') { sc.exe stop $Name | Out-Null }
  sc.exe delete $Name | Out-Null
  Start-Sleep -Milliseconds 500
}

$binPath = "`"$ExeFull`" $Args"

sc.exe create $Name binPath= "$binPath" obj= LocalSystem start= demand DisplayName= "$DisplayName" | Out-Null

sc.exe failure $Name reset= 60 actions= restart/5000/restart/5000/""/5000 | Out-Null
sc.exe failureflag $Name 1 | Out-Null
sc.exe description $Name "Lantern dev service" | Out-Null

# Start service
sc.exe start $Name

Write-Host "`nService created and started."
sc.exe qc $Name
sc.exe query $Name