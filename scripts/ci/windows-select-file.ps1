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
$openIdCondition = [PropertyCondition]::new([AutomationElement]::AutomationIdProperty, '1')
# Open can be a split button; match its action rather than its control type.
$openCondition = [AndCondition]::new(
  $openIdCondition,
  [PropertyCondition]::new([AutomationElement]::IsInvokePatternAvailableProperty, $true)
)

function Stop-Picker {
  param([string]$Message)

  try {
    $controls = if ($lastDialog) {
      @($lastDialog.FindAll([TreeScope]::Descendants, [OrCondition]::new([Condition[]]@(
        $filenameCondition,
        $openIdCondition,
        $editCondition,
        [PropertyCondition]::new([AutomationElement]::ControlTypeProperty, [ControlType]::ComboBox),
        [PropertyCondition]::new([AutomationElement]::IsInvokePatternAvailableProperty, $true)
      ))) | Select-Object -First 30 | ForEach-Object {
        @{ id = $_.Current.AutomationId; type = $_.Current.ControlType.ProgrammaticName; enabled = $_.Current.IsEnabled; invoke = $_.GetCurrentPropertyValue([AutomationElement]::IsInvokePatternAvailableProperty) }
      })
    } else { @() }
    $windows = @([AutomationElement]::RootElement.FindAll([TreeScope]::Children,
      [PropertyCondition]::new([AutomationElement]::ProcessIdProperty, $AppProcessId)
    ) | Select-Object -First 10 | ForEach-Object {
      @{ handle = $_.Current.NativeWindowHandle; class = $_.Current.ClassName }
    })
    [Console]::Error.WriteLine((@{ stage = $stage; windows = $windows; controls = $controls } | ConvertTo-Json -Depth 4 -Compress))
  } catch {
    [Console]::Error.WriteLine("Picker diagnostics unavailable at ${stage}: $_")
  } finally {
    # Close only the target process's picker so Flutter can finish its cleanup.
    if ($lastDialog) {
      try { ([WindowPattern]$lastDialog.GetCurrentPattern([WindowPattern]::Pattern)).Close() } catch { }
    }
  }
  throw $Message
}

# Match the common dialog's control IDs, not translated labels or screen positions.
$timer = [Diagnostics.Stopwatch]::StartNew()
$dialog = $null
$lastDialog = $null
$stage = 'waiting for the native dialog'
$value = $null
$open = $null
while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  Get-Process -Id $AppProcessId -ErrorAction Stop | Out-Null
  $dialogs = [AutomationElement]::RootElement.FindAll([TreeScope]::Children, $dialogCondition)
  foreach ($candidate in $dialogs) {
    $lastDialog = $candidate
    $filename = $candidate.FindFirst([TreeScope]::Descendants, $filenameCondition)
    $open = $candidate.FindFirst([TreeScope]::Descendants, $openCondition)
    $stage = "dialog found; filename=$([bool]$filename), Open=$([bool]$open)"
    if ($filename -and $open -and $filename.Current.IsEnabled) {
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
if (-not $dialog) { Stop-Picker "Executable picker was not ready for process $AppProcessId within $TimeoutSeconds seconds: $stage" }

$windowHandle = $dialog.Current.NativeWindowHandle
$value.SetValue($targetPath)
if ($value.Current.Value -ne $targetPath) { Stop-Picker 'The file picker did not accept the fixture path' }
$stage = 'filename entered; waiting for Open to enable'
while (-not $open.Current.IsEnabled -and $timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  Start-Sleep -Milliseconds 100
}
if (-not $open.Current.IsEnabled) { Stop-Picker 'Open did not enable after entering the fixture path' }
$invoke = [InvokePattern]$open.GetCurrentPattern([InvokePattern]::Pattern)
$openControlType = $open.Current.ControlType.ProgrammaticName
$invoke.Invoke()
$stage = 'Open invoked; waiting for the dialog to close'

$windowCondition = [AndCondition]::new(
  $dialogCondition,
  [PropertyCondition]::new([AutomationElement]::NativeWindowHandleProperty, $windowHandle)
)
while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  if (-not [AutomationElement]::RootElement.FindFirst([TreeScope]::Children, $windowCondition)) {
    [pscustomobject]@{ processId = $AppProcessId; path = $targetPath; windowHandle = $windowHandle; openControlType = $openControlType } | ConvertTo-Json -Compress
    exit 0
  }
  Start-Sleep -Milliseconds 200
}
Stop-Picker 'The executable picker remained open after selecting the fixture'
