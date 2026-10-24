using namespace System.Windows.Automation

param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 2147483647)]
  [int]$AppProcessId,
  [Parameter(Mandatory = $true)]
  [string]$FilePath,
  [ValidateRange(1, 30)]
  [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf) -or [IO.Path]::GetExtension($FilePath) -ne '.exe') {
  throw 'The file-dialog fixture must be an existing executable'
}
$targetPath = (Get-Item -LiteralPath $FilePath).FullName
Get-Process -Id $AppProcessId -ErrorAction Stop | Out-Null
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$dialogCondition = [AndCondition]::new(
  [PropertyCondition]::new([AutomationElement]::ProcessIdProperty, $AppProcessId),
  [PropertyCondition]::new([AutomationElement]::ClassNameProperty, '#32770')
)
$filenameCondition = [PropertyCondition]::new([AutomationElement]::AutomationIdProperty, '1148')
$editCondition = [PropertyCondition]::new([AutomationElement]::ControlTypeProperty, [ControlType]::Edit)
$openCondition = [AndCondition]::new(
  [PropertyCondition]::new([AutomationElement]::AutomationIdProperty, '1'),
  [PropertyCondition]::new([AutomationElement]::ControlTypeProperty, [ControlType]::Button)
)

# Match the common dialog's control IDs, not translated labels or screen positions.
$timer = [Diagnostics.Stopwatch]::StartNew()
$dialog = $null
$value = $null
$open = $null
while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  Get-Process -Id $AppProcessId -ErrorAction Stop | Out-Null
  $dialogs = [AutomationElement]::RootElement.FindAll([TreeScope]::Children, $dialogCondition)
  foreach ($candidate in $dialogs) {
    $filename = $candidate.FindFirst([TreeScope]::Descendants, $filenameCondition)
    $open = $candidate.FindFirst([TreeScope]::Descendants, $openCondition)
    if ($filename -and $open -and $filename.Current.IsEnabled -and $open.Current.IsEnabled) {
      $pattern = $null
      if (-not $filename.TryGetCurrentPattern([ValuePattern]::Pattern, [ref]$pattern) -or ([ValuePattern]$pattern).Current.IsReadOnly) {
        # Some dialog versions expose the editable field beneath a combo box.
        $filename = $filename.FindFirst([TreeScope]::Descendants, $editCondition)
        if (-not $filename -or -not $filename.TryGetCurrentPattern([ValuePattern]::Pattern, [ref]$pattern)) { continue }
      }
      $value = [ValuePattern]$pattern
      if ($value.Current.IsReadOnly -or -not $filename.Current.IsEnabled) { continue }
      $dialog = $candidate
      break
    }
  }
  if ($dialog) { break }
  Start-Sleep -Milliseconds 200
}
if (-not $dialog) { throw "No executable picker appeared for process $AppProcessId within $TimeoutSeconds seconds" }

$windowHandle = $dialog.Current.NativeWindowHandle
$value.SetValue($targetPath)
if ($value.Current.Value -ne $targetPath) { throw 'The file picker did not accept the fixture path' }
$invoke = [InvokePattern]$open.GetCurrentPattern([InvokePattern]::Pattern)
$invoke.Invoke()

$windowCondition = [AndCondition]::new(
  $dialogCondition,
  [PropertyCondition]::new([AutomationElement]::NativeWindowHandleProperty, $windowHandle)
)
while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  Get-Process -Id $AppProcessId -ErrorAction Stop | Out-Null
  if (-not [AutomationElement]::RootElement.FindFirst([TreeScope]::Children, $windowCondition)) {
    [pscustomobject]@{ processId = $AppProcessId; path = $targetPath; windowHandle = $windowHandle } | ConvertTo-Json -Compress
    exit 0
  }
  Start-Sleep -Milliseconds 200
}
throw 'The executable picker remained open after selecting the fixture'
