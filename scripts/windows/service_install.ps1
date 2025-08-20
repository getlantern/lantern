param(
  [string]$Name = "LanternSvc",
  [string]$Exe  = "$PSScriptRoot\..\..\bin\windows-amd64\lanternsvc.exe",
  [string]$Args = "--service"
)

$bin = '"' + $Exe + '" ' + $Args
if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
  Write-Host "Service $Name already exists."
} else {
  New-Service -Name $Name -BinaryPathName $bin -DisplayName "Lantern Service (dev)" -StartupType Manual
  Write-Host "Service $Name created."
}
Start-Service $Name
Get-Service $Name