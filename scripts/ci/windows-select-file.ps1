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

# Hosted Windows runners can expose native controls without UI Automation patterns.
if (-not ('LanternPickerNative' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class LanternPickerNative {
  private delegate bool EnumWindowProc(IntPtr window, IntPtr parameter);
  [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowProc callback, IntPtr parameter);
  [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumWindowProc callback, IntPtr parameter);
  [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder name, int length);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr window);
  [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr window);
  [DllImport("user32.dll")] public static extern bool IsChild(IntPtr parent, IntPtr window);
  [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr window);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
  [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW", CharSet = CharSet.Unicode)]
  private static extern IntPtr SendText(IntPtr window, uint message, IntPtr wParam, string text, uint flags, uint timeout, out IntPtr result);
  [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW", CharSet = CharSet.Unicode)]
  private static extern IntPtr ReadText(IntPtr window, uint message, IntPtr wParam, StringBuilder text, uint flags, uint timeout, out IntPtr result);

  public static string ClassName(IntPtr window) {
    var name = new StringBuilder(256);
    GetClassName(window, name, name.Capacity);
    return name.ToString();
  }
  public static bool IsDialog(IntPtr window, int processId) {
    uint owner;
    return GetWindowThreadProcessId(window, out owner) != 0 && owner == processId && ClassName(window) == "#32770";
  }
  public static IntPtr[] Dialogs(int processId) {
    var windows = new List<IntPtr>();
    EnumWindows(delegate(IntPtr window, IntPtr parameter) {
      if (IsDialog(window, processId)) windows.Add(window);
      return true;
    }, IntPtr.Zero);
    return windows.ToArray();
  }
  public static IntPtr[] Children(IntPtr parent) {
    var windows = new List<IntPtr>();
    EnumChildWindows(parent, delegate(IntPtr window, IntPtr parameter) {
      windows.Add(window);
      return true;
    }, IntPtr.Zero);
    return windows.ToArray();
  }
  public static IntPtr FindControl(IntPtr parent, int id, string className) {
    foreach (var window in Children(parent)) {
      if (GetDlgCtrlID(window) == id && ClassName(window) == className) return window;
    }
    return IntPtr.Zero;
  }
  public static IntPtr FileNameControl(IntPtr dialog) {
    foreach (var window in Children(dialog)) {
      if (GetDlgCtrlID(window) != 1148) continue;
      if (ClassName(window) == "Edit") return window;
      foreach (var child in Children(window)) {
        if (ClassName(child) == "Edit") return child;
      }
    }
    // Legacy dialogs can expose edt1 instead of the cmb13 combo box.
    return FindControl(dialog, 1152, "Edit");
  }
  public static void SetFileName(IntPtr dialog, IntPtr edit, int processId, string path) {
    if (!IsDialog(dialog, processId) || !IsChild(dialog, edit) || FileNameControl(dialog) != edit || !IsWindowEnabled(edit))
      throw new InvalidOperationException("The filename control is no longer available");
    IntPtr result;
    if (SendText(edit, 0x000C, IntPtr.Zero, path, 0x0002, 1000, out result) == IntPtr.Zero || result == IntPtr.Zero)
      throw new InvalidOperationException("The file picker did not accept the fixture path");
    var text = new StringBuilder(path.Length + 1);
    if (ReadText(edit, 0x000D, (IntPtr)text.Capacity, text, 0x0002, 1000, out result) == IntPtr.Zero || text.ToString() != path)
      throw new InvalidOperationException("The file picker did not retain the fixture path");
  }
  public static void Open(IntPtr dialog, IntPtr button, int processId) {
    if (!IsDialog(dialog, processId) || !IsChild(dialog, button) || GetDlgCtrlID(button) != 1 || ClassName(button) != "Button" || !IsWindowEnabled(button))
      throw new InvalidOperationException("The Open button is no longer available");
    // Deliver BN_CLICKED to the button's parent without relying on desktop focus.
    if (!PostMessage(GetParent(button), 0x0111, (IntPtr)1, button))
      throw new InvalidOperationException("Could not submit the native file picker");
  }
}
'@
}

function Stop-Picker {
  param([string]$Message)

  try {
    $controls = if ([LanternPickerNative]::IsDialog($lastDialog, $AppProcessId)) {
      @([LanternPickerNative]::Children($lastDialog) | Select-Object -First 40 | ForEach-Object {
        @{ handle = $_.ToInt64(); id = [LanternPickerNative]::GetDlgCtrlID($_); class = [LanternPickerNative]::ClassName($_); enabled = [LanternPickerNative]::IsWindowEnabled($_) }
      })
    } else { @() }
    [Console]::Error.WriteLine((@{ stage = $stage; dialog = $lastDialog.ToInt64(); controls = $controls } | ConvertTo-Json -Depth 4 -Compress))
  } finally {
    if ([LanternPickerNative]::IsDialog($lastDialog, $AppProcessId) -and [LanternPickerNative]::FileNameControl($lastDialog) -ne [IntPtr]::Zero) {
      $null = [LanternPickerNative]::PostMessage($lastDialog, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    }
  }
  throw $Message
}

$timer = [Diagnostics.Stopwatch]::StartNew()
$dialog = [IntPtr]::Zero
$lastDialog = [IntPtr]::Zero
$filename = [IntPtr]::Zero
$open = [IntPtr]::Zero
$stage = 'waiting for the native dialog'
while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  Get-Process -Id $AppProcessId -ErrorAction Stop | Out-Null
  foreach ($candidate in [LanternPickerNative]::Dialogs($AppProcessId)) {
    $lastDialog = $candidate
    $filename = [LanternPickerNative]::FileNameControl($candidate)
    $open = [LanternPickerNative]::FindControl($candidate, 1, 'Button')
    $stage = "dialog found; filename=$($filename.ToInt64()), Open=$($open.ToInt64())"
    if ($filename -ne [IntPtr]::Zero -and $open -ne [IntPtr]::Zero -and [LanternPickerNative]::IsWindowEnabled($filename)) {
      $dialog = $candidate
      break
    }
  }
  if ($dialog -ne [IntPtr]::Zero) { break }
  Start-Sleep -Milliseconds 200
}
if ($dialog -eq [IntPtr]::Zero) { Stop-Picker "Executable picker was not ready for process $AppProcessId within $TimeoutSeconds seconds: $stage" }

try { [LanternPickerNative]::SetFileName($dialog, $filename, $AppProcessId, $targetPath) } catch { Stop-Picker $_ }
$stage = 'filename entered; waiting for Open to enable'
while (-not [LanternPickerNative]::IsWindowEnabled($open) -and $timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  Start-Sleep -Milliseconds 100
}
try { [LanternPickerNative]::Open($dialog, $open, $AppProcessId) } catch { Stop-Picker $_ }
$stage = 'Open submitted; waiting for the dialog to close'
while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
  if (-not [LanternPickerNative]::IsDialog($dialog, $AppProcessId)) {
    [pscustomobject]@{ processId = $AppProcessId; path = $targetPath; windowHandle = $dialog.ToInt64(); openControlType = 'Button' } | ConvertTo-Json -Compress
    exit 0
  }
  Start-Sleep -Milliseconds 200
}
Stop-Picker 'The executable picker remained open after selecting the fixture'
