param(
  [string]$ServiceName = "LanternSvc",
  [string]$ServiceExe = "build/windows/x64/runner/Release/lanternsvc.exe",
  [string]$TokenPath = "C:\ProgramData\Lantern\ipc-token",
  [string]$TestPath = "integration_test/vpn/windows_connect_smoke_test.dart",
  [int]$WaitSeconds = 30
)

$ErrorActionPreference = "Stop"

function Remove-ServiceIfPresent {
  param([string]$Name)

  if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
    sc.exe stop $Name | Out-Null
    Start-Sleep -Seconds 2
    sc.exe delete $Name | Out-Null
    Start-Sleep -Seconds 2
  }
}

$resolvedServiceExe = (Resolve-Path $ServiceExe).Path

try {
  Remove-ServiceIfPresent -Name $ServiceName

  sc.exe create $ServiceName binPath= "`"$resolvedServiceExe`"" start= demand DisplayName= "Lantern Service (CI)" | Out-Null
  sc.exe start $ServiceName | Out-Null

  $serviceReady = $false
  for ($i = 0; $i -lt $WaitSeconds; $i++) {
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
      $serviceReady = $true
      break
    }
    Start-Sleep -Seconds 1
  }
  if (-not $serviceReady) {
    sc.exe query $ServiceName
    throw "Windows service did not reach Running state"
  }

  $tokenReady = $false
  for ($i = 0; $i -lt $WaitSeconds; $i++) {
    if (Test-Path $TokenPath) {
      $tokenReady = $true
      break
    }
    Start-Sleep -Seconds 1
  }
  if (-not $tokenReady) {
    throw "IPC token file not found at $TokenPath"
  }

  flutter test $TestPath -d windows --dart-define=DISABLE_SYSTEM_TRAY=true
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  try {
    Remove-ServiceIfPresent -Name $ServiceName
  } catch {
    Write-Warning ("Failed to clean up service {0}: {1}" -f $ServiceName, $_)
  }
}
