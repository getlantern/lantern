param(
  [string]$WingetId = "Anthropic.Claude",
  [string]$DisplayName = "Claude",
  [string]$ExecutableHint = "Claude.exe",
  [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Write-ReportLine {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Message
  )
  Add-Content -Path $Path -Value $Message
  Write-Host $Message
}

if ([string]::IsNullOrWhiteSpace($WingetId)) {
  throw "WingetId is required."
}

if ([string]::IsNullOrWhiteSpace($DisplayName)) {
  throw "DisplayName is required."
}

if ([string]::IsNullOrWhiteSpace($ExecutableHint)) {
  throw "ExecutableHint is required."
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $OutputDir = Join-Path $env:RUNNER_TEMP "windows-smoke-debug"
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$reportPath = Join-Path $OutputDir "smoke-app-install-report.txt"
if (Test-Path $reportPath) {
  Remove-Item $reportPath -Force
}

Write-Step "Installing smoke app package $WingetId"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget command was not found on this runner."
}

$installArgs = @(
  "install",
  "--id",
  $WingetId,
  "-e",
  "--accept-source-agreements",
  "--accept-package-agreements",
  "--silent",
  "--disable-interactivity"
)

Write-ReportLine -Path $reportPath -Message "Smoke app install timestamp: $(Get-Date -Format o)"
Write-ReportLine -Path $reportPath -Message "Winget package id: $WingetId"
Write-ReportLine -Path $reportPath -Message "Display name hint: $DisplayName"
Write-ReportLine -Path $reportPath -Message "Executable hint: $ExecutableHint"
Write-ReportLine -Path $reportPath -Message ""
Write-ReportLine -Path $reportPath -Message "Running: winget $($installArgs -join ' ')"

& winget @installArgs
if ($LASTEXITCODE -ne 0) {
  throw "winget install failed with exit code $LASTEXITCODE"
}

Write-ReportLine -Path $reportPath -Message ""
Write-ReportLine -Path $reportPath -Message "winget list output:"
(& winget list --id $WingetId -e 2>&1) | ForEach-Object {
  Write-ReportLine -Path $reportPath -Message $_
}

$startMenuRoots = @(
  "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
) | Where-Object { $_ -and (Test-Path $_) }

$matchingLinks = @()
foreach ($root in $startMenuRoots) {
  $matchingLinks += Get-ChildItem -Path $root -Filter *.lnk -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "*$DisplayName*" -or $_.FullName -like "*$DisplayName*" }
}

Write-ReportLine -Path $reportPath -Message ""
Write-ReportLine -Path $reportPath -Message "Start menu shortcut diagnostics:"
if ($matchingLinks.Count -eq 0) {
  Write-ReportLine -Path $reportPath -Message "No shortcuts matching '$DisplayName' were found."
} else {
  $wsh = New-Object -ComObject WScript.Shell
  foreach ($link in $matchingLinks | Sort-Object -Property FullName -Unique) {
    try {
      $shortcut = $wsh.CreateShortcut($link.FullName)
      Write-ReportLine -Path $reportPath -Message ("Link: {0}" -f $link.FullName)
      Write-ReportLine -Path $reportPath -Message ("  TargetPath: {0}" -f $shortcut.TargetPath)
      Write-ReportLine -Path $reportPath -Message ("  Arguments: {0}" -f $shortcut.Arguments)
      Write-ReportLine -Path $reportPath -Message ("  WorkingDirectory: {0}" -f $shortcut.WorkingDirectory)
      Write-ReportLine -Path $reportPath -Message ("  IconLocation: {0}" -f $shortcut.IconLocation)
    } catch {
      Write-ReportLine -Path $reportPath -Message ("Link: {0}" -f $link.FullName)
      Write-ReportLine -Path $reportPath -Message ("  Failed to inspect shortcut: {0}" -f $_)
    }
  }
}

$registryPaths = @(
  "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$registryRows = @()
foreach ($path in $registryPaths) {
  $registryRows += Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayName -like "*$DisplayName*" }
}

Write-ReportLine -Path $reportPath -Message ""
Write-ReportLine -Path $reportPath -Message "Uninstall registry diagnostics:"
if ($registryRows.Count -eq 0) {
  Write-ReportLine -Path $reportPath -Message "No uninstall entries matching '$DisplayName' were found."
} else {
  foreach ($entry in $registryRows) {
    Write-ReportLine -Path $reportPath -Message ("DisplayName: {0}" -f $entry.DisplayName)
    Write-ReportLine -Path $reportPath -Message ("  DisplayIcon: {0}" -f $entry.DisplayIcon)
    Write-ReportLine -Path $reportPath -Message ("  InstallLocation: {0}" -f $entry.InstallLocation)
    Write-ReportLine -Path $reportPath -Message ("  UninstallString: {0}" -f $entry.UninstallString)
  }
}

$appxRows = Get-AppxPackage -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Name -like "*$DisplayName*" -or
    $_.PackageFamilyName -like "*$DisplayName*"
  }

Write-ReportLine -Path $reportPath -Message ""
Write-ReportLine -Path $reportPath -Message "AppX diagnostics:"
if ($appxRows.Count -eq 0) {
  Write-ReportLine -Path $reportPath -Message "No AppX packages matching '$DisplayName' were found."
} else {
  foreach ($pkg in $appxRows) {
    Write-ReportLine -Path $reportPath -Message ("Name: {0}" -f $pkg.Name)
    Write-ReportLine -Path $reportPath -Message ("  PackageFamilyName: {0}" -f $pkg.PackageFamilyName)
    Write-ReportLine -Path $reportPath -Message ("  InstallLocation: {0}" -f $pkg.InstallLocation)
  }
}

$exeMatches = @()
$exeSearchRoots = @(
  "$env:LOCALAPPDATA\Programs",
  "$env:LOCALAPPDATA"
) | Where-Object { $_ -and (Test-Path $_) }

foreach ($root in $exeSearchRoots) {
  $exeMatches += Get-ChildItem -Path $root -Filter $ExecutableHint -File -Recurse -ErrorAction SilentlyContinue
}

Write-ReportLine -Path $reportPath -Message ""
Write-ReportLine -Path $reportPath -Message "Executable search diagnostics:"
if ($exeMatches.Count -eq 0) {
  Write-ReportLine -Path $reportPath -Message "No executables matching '$ExecutableHint' were found under LOCALAPPDATA roots."
} else {
  foreach ($match in $exeMatches | Sort-Object -Property FullName -Unique | Select-Object -First 30) {
    Write-ReportLine -Path $reportPath -Message ("Executable: {0}" -f $match.FullName)
  }
}

Write-Step "Smoke app install diagnostics written to $reportPath"
