param(
  [Parameter(Mandatory = $true)][int]$ProcessId,
  [Parameter(Mandatory = $true)][ValidateSet('tcp', 'udp')][string]$Protocol,
  [Parameter(Mandatory = $true)][string]$LocalAddress,
  [Parameter(Mandatory = $true)][int]$LocalPort,
  [Parameter(Mandatory = $true)][string]$RemoteAddress,
  [Parameter(Mandatory = $true)][int]$RemotePort
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if ($Protocol -eq 'tcp') {
  $endpoints = @(Get-NetTCPConnection -OwningProcess $ProcessId -LocalPort $LocalPort |
    Where-Object {
      $_.LocalAddress -eq $LocalAddress -and
      $_.RemoteAddress -eq $RemoteAddress -and $_.RemotePort -eq $RemotePort
    })
} else {
  # Windows' UDP table records the local endpoint, not the remote peer.
  $endpoints = @(Get-NetUDPEndpoint -OwningProcess $ProcessId -LocalPort $LocalPort |
    Where-Object { $_.LocalAddress -eq $LocalAddress -or $_.LocalAddress -eq '0.0.0.0' })
}
if ($endpoints.Count -ne 1) {
  throw "Expected one $Protocol endpoint owned by PID $ProcessId, found $($endpoints.Count)"
}
$owner = Get-Process -Id $ProcessId
if ([string]::IsNullOrWhiteSpace($owner.Path)) { throw 'Socket owner executable is unavailable' }
@{
  pid = $ProcessId
  executable = $owner.Path
  protocol = $Protocol
  localAddress = "$($endpoints[0].LocalAddress):$($endpoints[0].LocalPort)"
  remoteAddress = if ($Protocol -eq 'tcp') { "${RemoteAddress}:$RemotePort" } else { $null }
} | ConvertTo-Json -Compress
