param(
  [string]$ServiceName = "LanternSvc",
  [string]$ServiceExe = "build/windows/x64/runner/Release/lanternsvc.exe",
  [string]$InstallerPath = "",
  [string]$TokenPath = "C:\ProgramData\Lantern\ipc-token",
  [string]$TestPath = "integration_test/vpn/windows_connect_smoke_test.dart",
  [string]$SplitTunnelWebsiteTestPath = "integration_test/vpn/split_tunneling_website_smoke_test.dart",
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

$ErrorActionPreference = "Stop"

& "$PSScriptRoot/windows_smoke_suite.ps1" @PSBoundParameters @args
exit $LASTEXITCODE
