param(
  [string]$ServiceName = "LanternSvc",
  [string]$ServiceExe = "build/windows/x64/runner/Release/lanternd.exe",
  [string]$InstallerPath = "",
  [string]$TestPath = "integration_test/vpn/windows_connect_smoke_test.dart",
  [string]$ConfigUrlApiTestPath = "integration_test/vpn/windows_config_url_api_smoke_test.dart",
  [string]$ConfigUrlUiTestPath = "integration_test/vpn/windows_config_url_smoke_test.dart",
  [string]$DefaultConfigServerName = "ci-config-url-smoke",
  [int]$WaitSeconds = 30,
  [int]$InstallerTimeoutSeconds = 180,
  [int]$UninstallTimeoutSeconds = 180,
  [int]$HeartbeatSeconds = 15,
  [switch]$EnableIpCheck,
  [switch]$UseInstaller
)

& (Join-Path $PSScriptRoot "windows_smoke_suite.ps1") `
  -ServiceName $ServiceName `
  -ServiceExe $ServiceExe `
  -InstallerPath $InstallerPath `
  -TestPath $TestPath `
  -ConfigUrlApiTestPath $ConfigUrlApiTestPath `
  -ConfigUrlUiTestPath $ConfigUrlUiTestPath `
  -DefaultConfigServerName $DefaultConfigServerName `
  -WaitSeconds $WaitSeconds `
  -InstallerTimeoutSeconds $InstallerTimeoutSeconds `
  -UninstallTimeoutSeconds $UninstallTimeoutSeconds `
  -HeartbeatSeconds $HeartbeatSeconds `
  -RunConnectSmoke:$true `
  -RunSplitTunnelWebsiteSmoke:$false `
  -RunConfigUrlSmoke:$true `
  -EnableIpCheck:$EnableIpCheck `
  -UseInstaller:$UseInstaller
