param([string]$Name = "LanternSvc")
if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
  if ((Get-Service $Name).Status -eq 'Running') { Stop-Service $Name -Force }
  sc.exe delete $Name | Out-Null
  Write-Host "Removed $Name."
} else { Write-Host "Service $Name not found." }