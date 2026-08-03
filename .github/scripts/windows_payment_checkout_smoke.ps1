param(
  [ValidateSet("orchestrator", "launcher")]
  [string]$Mode = "orchestrator",
  [string]$ServiceName = "LanternSvc",
  [string]$InstalledAppPath = "C:\Program Files\Lantern\Lantern.exe",
  [string]$InstalledDaemonPath = "C:\Program Files\Lantern\lanternd.exe",
  [string]$ArtifactDirectory = "build/windows-payment-checkout-smoke",
  [int]$WaitSeconds = 90,
  [string]$ShepherdHostPattern = '(^|\.)m62mrsf\.com$',
  [string]$LauncherConfigPath
)

$ErrorActionPreference = "Stop"
$resolvedArtifacts = if ($Mode -eq "orchestrator") {
  [System.IO.Path]::GetFullPath($ArtifactDirectory)
} else {
  $null
}
$serviceDataDirectory = Join-Path $env:ProgramData "Lantern\payment-smoke-data"
$serviceLogDirectory = Join-Path $env:ProgramData "Lantern\payment-smoke-logs"
if ($resolvedArtifacts) {
  New-Item -ItemType Directory -Path $resolvedArtifacts -Force | Out-Null
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName Accessibility
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function Initialize-NativeSmokeHelpers {
  if ("WindowsPaymentSmoke.NativeToken" -as [type]) {
    return
  }

  $accessibilityAssembly = [Accessibility.IAccessible].Assembly.Location
  Add-Type -ReferencedAssemblies $accessibilityAssembly -TypeDefinition @'
namespace WindowsPaymentSmoke {
  public static class NativeMouse {
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern void mouse_event(
      uint flags, uint dx, uint dy, uint data, System.UIntPtr extraInfo);
  }

  public static class NativeToken {
    private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    private const uint TOKEN_QUERY = 0x0008;
    private const int TokenElevation = 20;

    [System.Runtime.InteropServices.StructLayout(
      System.Runtime.InteropServices.LayoutKind.Sequential)]
    private struct TOKEN_ELEVATION {
      public int TokenIsElevated;
    }

    [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
    private static extern System.IntPtr OpenProcess(
      uint access, bool inheritHandle, int processId);

    [System.Runtime.InteropServices.DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(
      System.IntPtr processHandle, uint access, out System.IntPtr tokenHandle);

    [System.Runtime.InteropServices.DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(
      System.IntPtr tokenHandle,
      int tokenInformationClass,
      out TOKEN_ELEVATION tokenInformation,
      int tokenInformationLength,
      out int returnLength);

    [System.Runtime.InteropServices.DllImport("kernel32.dll")]
    private static extern bool CloseHandle(System.IntPtr handle);

    public static bool IsElevated(int processId) {
      System.IntPtr process = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION, false, processId);
      if (process == System.IntPtr.Zero) {
        throw LastError("OpenProcess");
      }
      try {
        System.IntPtr token;
        if (!OpenProcessToken(process, TOKEN_QUERY, out token)) {
          throw LastError("OpenProcessToken");
        }
        try {
          TOKEN_ELEVATION elevation;
          int returned;
          if (!GetTokenInformation(
              token,
              TokenElevation,
              out elevation,
              System.Runtime.InteropServices.Marshal.SizeOf<TOKEN_ELEVATION>(),
              out returned)) {
            throw LastError("GetTokenInformation");
          }
          return elevation.TokenIsElevated != 0;
        } finally {
          CloseHandle(token);
        }
      } finally {
        CloseHandle(process);
      }
    }

    private static System.Exception LastError(string operation) {
      int error = System.Runtime.InteropServices.Marshal.GetLastWin32Error();
      return new System.Exception(
        string.Format("{0} failed with Windows error {1}", operation, error));
    }
  }

  public static class NativeAccessibility {
    private const uint OBJID_CLIENT = unchecked((uint)-4);
    private const int CHILDID_SELF = 0;
    private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const uint MOUSEEVENTF_LEFTUP = 0x0004;

    private sealed class Match {
      public Accessibility.IAccessible Container;
      public object ChildId;
    }

    [System.Runtime.InteropServices.DllImport("oleacc.dll")]
    private static extern int AccessibleObjectFromWindow(
      System.IntPtr window,
      uint objectId,
      ref System.Guid interfaceId,
      out Accessibility.IAccessible accessible);

    [System.Runtime.InteropServices.DllImport("oleacc.dll")]
    private static extern int AccessibleChildren(
      Accessibility.IAccessible container,
      int childStart,
      int childCount,
      [System.Runtime.InteropServices.In,
       System.Runtime.InteropServices.Out,
       System.Runtime.InteropServices.MarshalAs(
         System.Runtime.InteropServices.UnmanagedType.LPArray,
         SizeParamIndex = 2)]
      object[] children,
      out int obtained);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern System.IntPtr GetAncestor(
      System.IntPtr window, uint flags);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(System.IntPtr window);

    public static bool ContainsName(
        System.IntPtr window, string targetName) {
      Accessibility.IAccessible root = Root(window);
      if (root == null) {
        return false;
      }
      int visited = 0;
      return Find(root, targetName, 0, ref visited) != null;
    }

    // Flutter enables semantics when Windows asks for its client object.
    public static bool RequestRoot(System.IntPtr window) {
      return Root(window) != null;
    }

    public static bool ClickByName(
        System.IntPtr window, string targetName) {
      Accessibility.IAccessible root = Root(window);
      if (root == null) {
        return false;
      }
      int visited = 0;
      Match match = Find(root, targetName, 0, ref visited);
      if (match == null) {
        return false;
      }

      try {
        string action =
          match.Container.get_accDefaultAction(match.ChildId);
        if (!string.IsNullOrWhiteSpace(action)) {
          match.Container.accDoDefaultAction(match.ChildId);
          return true;
        }
      } catch (System.Runtime.InteropServices.COMException) {
      }

      int left;
      int top;
      int width;
      int height;
      try {
        match.Container.accLocation(
          out left, out top, out width, out height, match.ChildId);
        if (width > 0 && height > 0) {
          System.IntPtr topLevel = GetAncestor(window, 2);
          if (topLevel != System.IntPtr.Zero) {
            SetForegroundWindow(topLevel);
          }
          if (!SetCursorPos(
              left + (width / 2), top + (height / 2))) {
            return false;
          }
          NativeMouse.mouse_event(
            MOUSEEVENTF_LEFTDOWN, 0, 0, 0, System.UIntPtr.Zero);
          NativeMouse.mouse_event(
            MOUSEEVENTF_LEFTUP, 0, 0, 0, System.UIntPtr.Zero);
          return true;
        }
      } catch (System.Runtime.InteropServices.COMException) {
        return false;
      }
      return false;
    }

    public static string DescribeNames(System.IntPtr window) {
      Accessibility.IAccessible root = Root(window);
      if (root == null) {
        return "(MSAA root unavailable)";
      }
      System.Text.StringBuilder names =
        new System.Text.StringBuilder();
      int nameCount = 0;
      int visited = 0;
      CollectNames(root, names, ref nameCount, 0, ref visited);
      int rootChildren;
      try {
        rootChildren = root.accChildCount;
      } catch (System.Runtime.InteropServices.COMException) {
        rootChildren = -1;
      }
      string description = nameCount == 0
        ? "(no named MSAA elements)"
        : names.ToString();
      return string.Format(
        "rootChildren={0}; visited={1}; names={2}",
        rootChildren,
        visited,
        description);
    }

    private static Accessibility.IAccessible Root(System.IntPtr window) {
      System.Guid accessibleId = new System.Guid(
        "618736E0-3C3D-11CF-810C-00AA00389B71");
      Accessibility.IAccessible accessible;
      int result = AccessibleObjectFromWindow(
        window, OBJID_CLIENT, ref accessibleId, out accessible);
      return result >= 0 ? accessible : null;
    }

    private static Match Find(
        Accessibility.IAccessible container,
        string targetName,
        int depth,
        ref int visited) {
      if (container == null || depth > 64 || visited >= 5000) {
        return null;
      }
      visited++;
      if (NameEquals(container, CHILDID_SELF, targetName)) {
        return new Match {
          Container = container,
          ChildId = CHILDID_SELF,
        };
      }

      object[] children = Children(container);
      foreach (object child in children) {
        Accessibility.IAccessible childAccessible =
          child as Accessibility.IAccessible;
        if (childAccessible != null) {
          Match match = Find(
            childAccessible, targetName, depth + 1, ref visited);
          if (match != null) {
            return match;
          }
          continue;
        }
        if (child != null && NameEquals(container, child, targetName)) {
          return new Match {
            Container = container,
            ChildId = child,
          };
        }
      }
      return null;
    }

    private static void CollectNames(
        Accessibility.IAccessible container,
        System.Text.StringBuilder names,
        ref int nameCount,
        int depth,
        ref int visited) {
      if (container == null || depth > 64 ||
          visited >= 5000 || nameCount >= 100) {
        return;
      }
      visited++;
      AddName(container, CHILDID_SELF, names, ref nameCount);
      foreach (object child in Children(container)) {
        Accessibility.IAccessible childAccessible =
          child as Accessibility.IAccessible;
        if (childAccessible != null) {
          CollectNames(
            childAccessible,
            names,
            ref nameCount,
            depth + 1,
            ref visited);
        } else if (child != null) {
          AddName(container, child, names, ref nameCount);
        }
      }
    }

    private static object[] Children(
        Accessibility.IAccessible container) {
      int childCount;
      try {
        childCount = container.accChildCount;
      } catch (System.Runtime.InteropServices.COMException) {
        return new object[0];
      }
      if (childCount <= 0) {
        return new object[0];
      }

      object[] children = new object[childCount];
      int obtained;
      int result = AccessibleChildren(
        container, 0, childCount, children, out obtained);
      if (result < 0 || obtained <= 0) {
        return new object[0];
      }
      if (obtained == childCount) {
        return children;
      }
      object[] trimmed = new object[obtained];
      System.Array.Copy(children, trimmed, obtained);
      return trimmed;
    }

    private static bool NameEquals(
        Accessibility.IAccessible container,
        object childId,
        string targetName) {
      string name = Name(container, childId);
      return string.Equals(
        name == null ? null : name.Trim(),
        targetName == null ? null : targetName.Trim(),
        System.StringComparison.Ordinal);
    }

    private static void AddName(
        Accessibility.IAccessible container,
        object childId,
        System.Text.StringBuilder names,
        ref int nameCount) {
      string name = Name(container, childId);
      if (!string.IsNullOrWhiteSpace(name)) {
        if (nameCount > 0) {
          names.Append(", ");
        }
        names.Append(name);
        nameCount++;
      }
    }

    private static string Name(
        Accessibility.IAccessible container, object childId) {
      try {
        return container.get_accName(childId);
      } catch (System.Runtime.InteropServices.COMException) {
        return null;
      }
    }
  }

  public static class NativeWindow {
    private delegate bool EnumWindowsProc(
      System.IntPtr window, System.IntPtr parameter);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool EnumWindows(
      EnumWindowsProc callback, System.IntPtr parameter);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool EnumChildWindows(
      System.IntPtr parent,
      EnumWindowsProc callback,
      System.IntPtr parameter);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(
      System.IntPtr window, out uint processId);

    [System.Runtime.InteropServices.DllImport(
      "user32.dll",
      CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern int GetClassName(
      System.IntPtr window,
      System.Text.StringBuilder className,
      int maximumCount);

    [System.Runtime.InteropServices.DllImport(
      "user32.dll",
      CharSet = System.Runtime.InteropServices.CharSet.Unicode,
      SetLastError = true)]
    public static extern System.IntPtr FindWindowEx(
      System.IntPtr parent,
      System.IntPtr childAfter,
      string className,
      string windowName);

    public static System.IntPtr FindByProcessAndClass(
        int processId, string targetClass) {
      System.IntPtr result = System.IntPtr.Zero;
      EnumWindows(delegate(System.IntPtr topLevel, System.IntPtr parameter) {
        uint owner;
        GetWindowThreadProcessId(topLevel, out owner);
        if (owner != processId) {
          return true;
        }
        if (ClassName(topLevel) == targetClass) {
          result = topLevel;
          return false;
        }
        EnumChildWindows(
          topLevel,
          delegate(System.IntPtr child, System.IntPtr childParameter) {
            if (ClassName(child) == targetClass) {
              result = child;
              return false;
            }
            return true;
          },
          System.IntPtr.Zero);
        return result == System.IntPtr.Zero;
      }, System.IntPtr.Zero);
      return result;
    }

    public static System.IntPtr FindMessageOnlyByProcessAndClass(
        int processId, string targetClass) {
      System.IntPtr messageWindow = new System.IntPtr(-3);
      System.IntPtr child = System.IntPtr.Zero;
      while (true) {
        child = FindWindowEx(messageWindow, child, targetClass, null);
        if (child == System.IntPtr.Zero) {
          return System.IntPtr.Zero;
        }
        uint owner;
        GetWindowThreadProcessId(child, out owner);
        if (owner == processId) {
          return child;
        }
      }
    }

    public static string DescribeProcessWindows(int processId) {
      System.Text.StringBuilder windows =
        new System.Text.StringBuilder();
      EnumWindows(delegate(System.IntPtr topLevel, System.IntPtr parameter) {
        uint owner;
        GetWindowThreadProcessId(topLevel, out owner);
        if (owner != processId) {
          return true;
        }
        AppendClassName(windows, ClassName(topLevel));
        EnumChildWindows(
          topLevel,
          delegate(System.IntPtr child, System.IntPtr childParameter) {
            AppendClassName(windows, ClassName(child));
            return true;
          },
          System.IntPtr.Zero);
        return true;
      }, System.IntPtr.Zero);
      return windows.ToString();
    }

    private static void AppendClassName(
        System.Text.StringBuilder windows, string className) {
      if (windows.Length > 0) {
        windows.Append(",");
      }
      windows.Append(className);
    }

    private static string ClassName(System.IntPtr window) {
      System.Text.StringBuilder className =
        new System.Text.StringBuilder(256);
      GetClassName(window, className, className.Capacity);
      return className.ToString();
    }
  }
}
'@
}

function Write-Step {
  param([string]$Message)
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message)
}

function Wait-ServiceRunning {
  param([string]$Name, [int]$TimeoutSeconds)
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
      return
    }
    Start-Sleep -Seconds 1
  }
  throw "Service $Name did not reach Running state"
}

function Use-StagingService {
  if (-not (Test-Path $InstalledDaemonPath)) {
    throw "Installed daemon not found: $InstalledDaemonPath"
  }
  Write-Step "Reinstalling the installed service for staging"
  Remove-Item $serviceDataDirectory -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $serviceLogDirectory -Recurse -Force -ErrorAction SilentlyContinue
  & $InstalledDaemonPath install --environment staging `
    --data-path $serviceDataDirectory `
    --log-path $serviceLogDirectory `
    --log-level debug
  if ($LASTEXITCODE -ne 0) {
    throw "lanternd staging install failed with exit code $LASTEXITCODE"
  }
  Wait-ServiceRunning -Name $ServiceName -TimeoutSeconds 60
  Start-Sleep -Seconds 5

  $service = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'"
  if ($service.PathName -notmatch '(?i)--environment\s+staging') {
    throw "Installed service command does not persist --environment staging: $($service.PathName)"
  }
  if ($service.PathName -notmatch [regex]::Escape($serviceDataDirectory)) {
    throw "Installed staging service is not using disposable data: $($service.PathName)"
  }
  $service | Select-Object Name, State, StartMode, PathName |
    ConvertTo-Json | Set-Content (Join-Path $resolvedArtifacts "service.json")
}

function Wait-File {
  param([string]$Path, [int]$TimeoutSeconds)
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Path $Path) { return }
    Start-Sleep -Seconds 1
  }
  throw "Timed out waiting for $Path"
}

function Wait-ProcessMainWindow {
  param([int]$ProcessID, [int]$TimeoutSeconds)
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    $process = Get-Process -Id $ProcessID -ErrorAction SilentlyContinue
    if (-not $process) {
      throw "Lantern process $ProcessID exited before creating a window"
    }
    $process.Refresh()
    if ($process.MainWindowHandle -ne 0) {
      return $process
    }
    Start-Sleep -Seconds 1
  }
  throw "Timed out waiting for Lantern main window"
}

function Wait-FlutterViewHandle {
  param([int]$ProcessID, [int]$TimeoutSeconds)
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    $handle = [WindowsPaymentSmoke.NativeWindow]::FindByProcessAndClass(
      $ProcessID,
      "FLUTTERVIEW"
    )
    if ($handle -ne [IntPtr]::Zero) {
      return $handle
    }
    Start-Sleep -Seconds 1
  }
  $messageOnly = [WindowsPaymentSmoke.NativeWindow]::FindMessageOnlyByProcessAndClass(
    $ProcessID,
    "FLUTTERVIEW"
  )
  $windows = [WindowsPaymentSmoke.NativeWindow]::DescribeProcessWindows(
    $ProcessID
  )
  if ($messageOnly -ne [IntPtr]::Zero) {
    throw "Lantern's FLUTTERVIEW remained message-only; windows=$windows"
  }
  throw "Lantern did not create a FLUTTERVIEW window; windows=$windows"
}

function Wait-AccessibleElement {
  param(
    [IntPtr]$ViewHandle,
    [string]$AccessibleName,
    [int]$TimeoutSeconds,
    [string]$FailureLogPath,
    [switch]$Optional
  )
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if ([WindowsPaymentSmoke.NativeAccessibility]::ContainsName(
        $ViewHandle,
        $AccessibleName
      )) {
      return $true
    }
    if ($FailureLogPath -and (Test-Path $FailureLogPath)) {
      $failure = Select-String -Path $FailureLogPath `
        -Pattern 'PAYMENT_CHECKOUT_SMOKE event=(rejected|bootstrap_error)' |
        Select-Object -Last 1
      if ($failure) {
        throw "Lantern checkout bootstrap failed: $($failure.Line.Trim())"
      }
    }
    Start-Sleep -Seconds 1
  }
  if ($Optional) { return $false }
  $names = [WindowsPaymentSmoke.NativeAccessibility]::DescribeNames(
    $ViewHandle
  )
  throw "Timed out waiting for accessible element '$AccessibleName'; names=$names"
}

function Invoke-AccessibleElement {
  param(
    [IntPtr]$ViewHandle,
    [string]$AccessibleName
  )
  if (-not [WindowsPaymentSmoke.NativeAccessibility]::ClickByName(
      $ViewHandle,
      $AccessibleName
    )) {
    throw "Could not invoke accessible element '$AccessibleName'"
  }
}

function Save-WindowScreenshot {
  param(
    [System.Windows.Automation.AutomationElement]$Root,
    [string]$Path
  )
  $bounds = $Root.Current.BoundingRectangle
  if ($bounds.Width -le 0 -or $bounds.Height -le 0) { return }
  $bitmap = [System.Drawing.Bitmap]::new([int]$bounds.Width, [int]$bounds.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen(
      [int]$bounds.X,
      [int]$bounds.Y,
      0,
      0,
      $bitmap.Size
    )
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

function Save-DesktopScreenshot {
  param([string]$Path)
  $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bitmap = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.CopyFromScreen(
      $bounds.Left,
      $bounds.Top,
      0,
      0,
      $bitmap.Size
    )
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

function Copy-CaseLogs {
  param([string]$Destination)
  $appLogDirectory = Join-Path $env:PUBLIC "Lantern\logs"
  if (Test-Path $appLogDirectory) {
    Copy-Item $appLogDirectory (Join-Path $Destination "app-logs") -Recurse -Force
  }
  if (Test-Path $serviceLogDirectory) {
    Copy-Item $serviceLogDirectory (Join-Path $Destination "daemon-logs") -Recurse -Force
  }
}

function Wait-CheckoutDocument {
  param(
    [string]$LogPath,
    [string]$HostPattern,
    [int]$TimeoutSeconds,
    [string]$ResultPath
  )
  $linePattern = 'PAYMENT_WEBVIEW_SMOKE event=load_stop host=(\S+) url=(\S+) document_length=(\d+)'
  $lastLogText = ""
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Path $LogPath) {
      $lastLogText = [string](
        Get-Content $LogPath -Raw -ErrorAction SilentlyContinue
      )
      if ($lastLogText -match 'PAYMENT_CHECKOUT_SMOKE event=(rejected|bootstrap_error)') {
        throw "Lantern could not prepare the requested checkout smoke"
      }
      if ($lastLogText -match 'PAYMENT_WEBVIEW_SMOKE event=creation_error') {
        throw "Lantern could not create the checkout WebView"
      }
      if ($lastLogText -match 'PAYMENT_WEBVIEW_SMOKE event=navigation_error') {
        throw "The checkout WebView reported a main-frame navigation error"
      }
      if ($lastLogText -match 'PAYMENT_WEBVIEW_SMOKE event=process_error') {
        throw "The checkout WebView2 process failed"
      }
      foreach ($match in [regex]::Matches($lastLogText, $linePattern)) {
        $hostName = $match.Groups[1].Value
        $documentLength = [int]$match.Groups[3].Value
        if ($hostName -match $HostPattern -and $documentLength -gt 0) {
          if ($lastLogText -notmatch 'PAYMENT_WEBVIEW_SMOKE event=created') {
            throw "The checkout page loaded without a WebView creation marker"
          }
          @{
            host = $hostName
            url = $match.Groups[2].Value
            documentLength = $documentLength
          } | ConvertTo-Json | Set-Content $ResultPath
          return
        }
      }
    }
    if ($i -ge 29 -and
        $lastLogText -notmatch 'PAYMENT_WEBVIEW_SMOKE event=created') {
      throw "Lantern did not create the checkout WebView within 30 seconds"
    }
    Start-Sleep -Seconds 1
  }
  if ($lastLogText -match 'PAYMENT_WEBVIEW_SMOKE event=document_error') {
    throw "The checkout WebView could not inspect the loaded document"
  }
  throw "No non-empty checkout document loaded from expected host pattern $HostPattern"
}

function Wait-LauncherResult {
  param(
    [string]$Path,
    [System.Diagnostics.Process]$Process,
    [int]$TimeoutSeconds,
    [string]$ErrorPath
  )
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Path $Path) { return }
    $Process.Refresh()
    if ($Process.HasExited) {
      Start-Sleep -Seconds 1
      if (Test-Path $Path) { return }
      $errorDetails = if ($ErrorPath -and (Test-Path $ErrorPath)) {
        (Get-Content $ErrorPath -Raw -ErrorAction SilentlyContinue).Trim()
      } else {
        ""
      }
      if ($errorDetails) {
        throw "Smoke-user launcher exited with code $($Process.ExitCode): $errorDetails"
      }
      throw "Smoke-user launcher exited with code $($Process.ExitCode) without writing a result"
    }
    Start-Sleep -Seconds 1
  }
  throw "Timed out waiting for the smoke-user launcher"
}

function Invoke-SmokeUserCheckout {
  param(
    [string]$AppPath,
    [string]$CheckoutProvider,
    [string]$CheckoutRunID,
    [string]$ProcessDiagnosticsPath,
    [string]$WebViewUDFPath,
    [string]$UserProfilePath,
    [string]$ResultPath,
    [string]$AppLogPath,
    [string]$ExpectedHostPattern,
    [string]$WebViewPath,
    [string]$CheckoutImagePath,
    [string]$FinalImagePath,
    [string]$TranscriptPath,
    [int]$TimeoutSeconds
  )

  $app = $null
  $root = $null
  $transcriptStarted = $false
  try {
    $env:USERPROFILE = $UserProfilePath
    $env:LOCALAPPDATA = Join-Path $UserProfilePath "AppData\Local"
    $env:APPDATA = Join-Path $UserProfilePath "AppData\Roaming"
    $env:HOMEDRIVE = Split-Path -Qualifier $UserProfilePath
    $env:HOMEPATH = $UserProfilePath.Substring($env:HOMEDRIVE.Length)
    $env:TEMP = Join-Path $env:LOCALAPPDATA "Temp"
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
    Start-Transcript -Path $TranscriptPath -Force | Out-Null
    $transcriptStarted = $true
    $null = Initialize-NativeSmokeHelpers
    [Environment]::SetEnvironmentVariable(
      "WEBVIEW2_USER_DATA_FOLDER",
      $null,
      [EnvironmentVariableTarget]::Process
    )

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdmin = $principal.IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    $installWritePath = Join-Path (Split-Path $AppPath -Parent) (
      "smoke-write-" + [Guid]::NewGuid().ToString("N")
    )
    $canWriteInstallDirectory = $false
    try {
      New-Item -ItemType File -Path $installWritePath -Force `
        -ErrorAction Stop | Out-Null
      $canWriteInstallDirectory = $true
    } catch {
    } finally {
      Remove-Item $installWritePath -Force -ErrorAction SilentlyContinue
    }

    $localAppData = $env:LOCALAPPDATA
    $externalUDF = [Environment]::GetEnvironmentVariable(
      "WEBVIEW2_USER_DATA_FOLDER",
      "Process"
    )
    $appDirectory = Split-Path $AppPath -Parent
    $app = Start-Process -FilePath $AppPath `
      -WorkingDirectory $appDirectory -ArgumentList @(
      "--payment-checkout-smoke=$CheckoutProvider",
      "--payment-checkout-run-id=$CheckoutRunID"
    ) -PassThru
    @{
      processId = $app.Id
      username = $identity.Name
      isAdmin = $isAdmin
      canWriteInstallDirectory = $canWriteInstallDirectory
      externalWebView2UserDataFolder = $externalUDF
      localAppData = $localAppData
      profilePath = $UserProfilePath
    } | ConvertTo-Json | Set-Content $ProcessDiagnosticsPath

    $app = Wait-ProcessMainWindow -ProcessID $app.Id -TimeoutSeconds 90
    $flutterViewHandle = Wait-FlutterViewHandle `
      -ProcessID $app.Id -TimeoutSeconds 30
    $processIsElevated = [WindowsPaymentSmoke.NativeToken]::IsElevated($app.Id)
    $diagnostics = Get-Content $ProcessDiagnosticsPath -Raw | ConvertFrom-Json
    $diagnostics | Add-Member -NotePropertyName processIsElevated `
      -NotePropertyValue $processIsElevated
    $diagnostics | Add-Member -NotePropertyName mainWindowHandle `
      -NotePropertyValue ([IntPtr]$app.MainWindowHandle).ToInt64()
    $diagnostics | Add-Member -NotePropertyName flutterViewHandle `
      -NotePropertyValue $flutterViewHandle.ToInt64()
    $diagnostics | ConvertTo-Json | Set-Content $ProcessDiagnosticsPath
    if ($isAdmin -or $processIsElevated) {
      throw "The installed Lantern process has an elevated access token"
    }
    if ($canWriteInstallDirectory) {
      throw "The smoke user can write beside the installed executable"
    }
    if (-not [string]::IsNullOrWhiteSpace($externalUDF)) {
      throw "Primary smoke inherited WEBVIEW2_USER_DATA_FOLDER=$externalUDF"
    }

    $udfPath = Join-Path $localAppData "Lantern\WebView2"
    for ($i = 0; $i -lt 30; $i++) {
      if (Test-Path $udfPath) { break }
      if ($app.HasExited) { break }
      Start-Sleep -Seconds 1
      $app.Refresh()
    }
    $udfWritable = $false
    $udfProbe = Join-Path $udfPath (
      "write-probe-" + [Guid]::NewGuid().ToString("N")
    )
    try {
      New-Item -ItemType File -Path $udfProbe -Force `
        -ErrorAction Stop | Out-Null
      $udfWritable = $true
    } catch {
    } finally {
      Remove-Item $udfProbe -Force -ErrorAction SilentlyContinue
    }
    @{
      path = $udfPath
      exists = (Test-Path $udfPath)
      writable = $udfWritable
    } | ConvertTo-Json | Set-Content $WebViewUDFPath

    if (-not [WindowsPaymentSmoke.NativeAccessibility]::RequestRoot(
        $flutterViewHandle
      )) {
      throw "Lantern did not expose an MSAA root for its FLUTTERVIEW"
    }
    Write-Step "Attached accessibility automation to Lantern's FLUTTERVIEW child window"
    $root = [System.Windows.Automation.AutomationElement]::FromHandle(
      $flutterViewHandle
    )
    $providerTitle = (Get-Culture).TextInfo.ToTitleCase($CheckoutProvider)
    $providerName = "$providerTitle payment method"
    $checkoutName = "Continue with $providerTitle"
    $null = Wait-AccessibleElement -ViewHandle $flutterViewHandle `
      -AccessibleName $providerName -TimeoutSeconds 90 `
      -FailureLogPath $AppLogPath
    $checkoutVisible = Wait-AccessibleElement -ViewHandle $flutterViewHandle `
      -AccessibleName $checkoutName `
      -TimeoutSeconds 2 -Optional
    if (-not $checkoutVisible) {
      Invoke-AccessibleElement -ViewHandle $flutterViewHandle `
        -AccessibleName $providerName
      $null = Wait-AccessibleElement -ViewHandle $flutterViewHandle `
        -AccessibleName $checkoutName `
        -TimeoutSeconds 20 -FailureLogPath $AppLogPath
    }
    Invoke-AccessibleElement -ViewHandle $flutterViewHandle `
      -AccessibleName $checkoutName

    Wait-CheckoutDocument -LogPath $AppLogPath `
      -HostPattern $ExpectedHostPattern -TimeoutSeconds $TimeoutSeconds `
      -ResultPath $WebViewPath

    Save-WindowScreenshot -Root $root -Path $CheckoutImagePath
    Save-WindowScreenshot -Root $root -Path $FinalImagePath
    @{
      success = $true
      processId = $app.Id
      provider = $CheckoutProvider
    } | ConvertTo-Json | Set-Content $ResultPath

    $app.WaitForExit()
  } catch {
    $failure = $_
    try {
      if ($root) {
        Save-WindowScreenshot -Root $root -Path $FinalImagePath
      } else {
        Save-DesktopScreenshot -Path $FinalImagePath
      }
    } catch {
      Write-Warning "Could not capture smoke-user screenshot: $_"
    }
    @{
      success = $false
      error = $failure.Exception.Message
      provider = $CheckoutProvider
    } | ConvertTo-Json | Set-Content $ResultPath
    throw $failure
  } finally {
    if ($transcriptStarted) {
      try {
        Stop-Transcript | Out-Null
      } catch {
      }
    }
  }
}

function Remove-SmokeAccount {
  param([string]$Username, [string]$SID)

  if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $Username
  }
  if ([string]::IsNullOrWhiteSpace($SID)) { return }

  for ($i = 0; $i -lt 15; $i++) {
    $profile = Get-CimInstance Win32_UserProfile -Filter "SID='$SID'" `
      -ErrorAction SilentlyContinue
    if (-not $profile) { return }
    if (-not $profile.Loaded) {
      Remove-CimInstance $profile
      return
    }
    Start-Sleep -Seconds 1
  }
  Write-Warning "Disposable profile $SID remained loaded and could not be removed"
}

function Invoke-CheckoutCase {
  param([string]$Provider, [string]$HostPattern, [string]$RunID)

  $caseDirectory = Join-Path $resolvedArtifacts $Provider
  New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
  @{
    provider = $Provider
    runId = $RunID
    githubRunId = $env:GITHUB_RUN_ID
    githubRunAttempt = $env:GITHUB_RUN_ATTEMPT
  } | ConvertTo-Json | Set-Content (Join-Path $caseDirectory "run.json")
  $transcript = Join-Path $caseDirectory "orchestration.log"
  $username = "lntsmk" + ([Guid]::NewGuid().ToString("N").Substring(0, 10))
  $sid = $null
  $credential = $null
  $launcherProcess = $null
  $appProcess = $null
  $sharedAppDirectory = $null
  $diagnosticsPath = $null
  $udfCheckPath = $null
  $automationResultPath = $null
  $childWebViewPath = $null
  $childCheckoutImagePath = $null
  $childFinalImagePath = $null
  $launcherLogPath = $null
  $launcherStdoutPath = $null
  $launcherStderrPath = $null
  $launcherConfigPath = $null
  $profilePath = $null
  $transcriptStarted = $false
  $priorUDF = [Environment]::GetEnvironmentVariable(
    "WEBVIEW2_USER_DATA_FOLDER",
    [EnvironmentVariableTarget]::Process
  )

  try {
    Start-Transcript -Path $transcript -Force | Out-Null
    $transcriptStarted = $true

    $passwordText = "L@ntern!" + ([Guid]::NewGuid().ToString("N"))
    $securePassword = ConvertTo-SecureString $passwordText -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new(
      ".\$username",
      $securePassword
    )
    $user = New-LocalUser -Name $username -Password $securePassword `
      -AccountNeverExpires -PasswordNeverExpires
    $sid = $user.SID.Value
    # Radiance currently authorizes desktop clients by Administrators group
    # membership. UAC still gives this interactive launch a filtered token.
    $administrators = Get-LocalGroup -SID "S-1-5-32-544"
    Add-LocalGroupMember -Group $administrators -Member $user
    $administratorsMember = Get-LocalGroupMember -Group $administrators |
      Where-Object { $_.SID.Value -eq $sid }
    if (-not $administratorsMember) {
      throw "Could not grant the smoke user access to the installed Lantern service"
    }

    # Create the profile before the real launch so the child process does not
    # inherit the runner account's AppData paths.
    $profileBootstrap = Start-Process -FilePath "powershell.exe" `
      -Credential $credential -LoadUserProfile -Wait -PassThru `
      -ArgumentList @(
        "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "exit 0"
      )
    if ($profileBootstrap.ExitCode -ne 0) {
      throw "Could not initialize the disposable user profile"
    }
    $profile = $null
    for ($i = 0; $i -lt 15; $i++) {
      $profile = Get-CimInstance Win32_UserProfile -Filter "SID='$sid'" `
        -ErrorAction SilentlyContinue
      if ($profile -and -not [string]::IsNullOrWhiteSpace($profile.LocalPath)) {
        break
      }
      Start-Sleep -Seconds 1
    }
    if (-not $profile -or [string]::IsNullOrWhiteSpace($profile.LocalPath)) {
      throw "Windows did not create a profile for disposable user $username"
    }
    $profilePath = [Environment]::ExpandEnvironmentVariables($profile.LocalPath)

    Write-Step "Starting $Provider checkout as disposable non-elevated user $username"
    [Environment]::SetEnvironmentVariable(
      "WEBVIEW2_USER_DATA_FOLDER",
      $null,
      [EnvironmentVariableTarget]::Process
    )

    $sharedAppDirectory = Join-Path $env:PUBLIC "Lantern"
    New-Item -ItemType Directory -Path $sharedAppDirectory -Force | Out-Null
    & icacls.exe $sharedAppDirectory /grant "*$sid`:(OI)(CI)M" /T /C | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Could not grant the smoke user access to $sharedAppDirectory"
    }
    $exchangeDirectory = Join-Path $sharedAppDirectory "payment-smoke\$RunID-$Provider"
    New-Item -ItemType Directory -Path $exchangeDirectory -Force | Out-Null
    Remove-Item (Join-Path $sharedAppDirectory "data") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $sharedAppDirectory "logs") -Recurse -Force -ErrorAction SilentlyContinue

    $diagnosticsPath = Join-Path $exchangeDirectory "process.json"
    $udfCheckPath = Join-Path $exchangeDirectory "udf.json"
    $automationResultPath = Join-Path $exchangeDirectory "automation-result.json"
    $childWebViewPath = Join-Path $exchangeDirectory "webview.json"
    $childCheckoutImagePath = Join-Path $exchangeDirectory "checkout.png"
    $childFinalImagePath = Join-Path $exchangeDirectory "final.png"
    $launcherLogPath = Join-Path $exchangeDirectory "automation.log"
    $launcherStdoutPath = Join-Path $exchangeDirectory "launcher-stdout.log"
    $launcherStderrPath = Join-Path $exchangeDirectory "launcher-stderr.log"
    $launcherPath = Join-Path $exchangeDirectory "launch.ps1"
    $launcherConfigPath = Join-Path $exchangeDirectory "launcher.json"
    $flutterLog = Join-Path $env:PUBLIC "Lantern\logs\flutter.log"
    # Run UI Automation in the same logon session as Flutter. Cross-user
    # automation can see the native host window but not Flutter's semantics.
    Copy-Item $PSCommandPath $launcherPath -Force
    @{
      appPath = $InstalledAppPath
      provider = $Provider
      runId = $RunID
      diagnosticsPath = $diagnosticsPath
      udfCheckPath = $udfCheckPath
      profilePath = $profilePath
      automationResultPath = $automationResultPath
      flutterLogPath = $flutterLog
      hostPattern = $HostPattern
      webViewResultPath = $childWebViewPath
      checkoutScreenshotPath = $childCheckoutImagePath
      finalScreenshotPath = $childFinalImagePath
      launcherLogPath = $launcherLogPath
      waitSeconds = $WaitSeconds
    } | ConvertTo-Json | Set-Content $launcherConfigPath

    $launcherArguments = @(
      "-NoLogo",
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", "`"$launcherPath`"",
      "-Mode", "launcher",
      "-LauncherConfigPath", "`"$launcherConfigPath`""
    )
    $launcherProcess = Start-Process -FilePath "powershell.exe" `
      -Credential $credential -LoadUserProfile `
      -ArgumentList $launcherArguments `
      -RedirectStandardOutput $launcherStdoutPath `
      -RedirectStandardError $launcherStderrPath -PassThru

    Wait-LauncherResult -Path $automationResultPath -Process $launcherProcess `
      -TimeoutSeconds ($WaitSeconds + 150) -ErrorPath $launcherStderrPath
    $automationResult = Get-Content $automationResultPath -Raw |
      ConvertFrom-Json
    if (-not $automationResult.success) {
      throw "Smoke-user checkout failed: $($automationResult.error)"
    }

    $diagnostics = Get-Content $diagnosticsPath -Raw | ConvertFrom-Json
    if ($diagnostics.isAdmin) {
      throw "The installed app was launched with an administrator token"
    }
    if ($diagnostics.canWriteInstallDirectory) {
      throw "The smoke user can write beside the installed executable"
    }
    if (-not [string]::IsNullOrWhiteSpace($diagnostics.externalWebView2UserDataFolder)) {
      throw "Primary smoke inherited WEBVIEW2_USER_DATA_FOLDER=$($diagnostics.externalWebView2UserDataFolder)"
    }
    $expectedLocalAppData = Join-Path $profilePath "AppData\Local"
    if ($diagnostics.localAppData -ne $expectedLocalAppData) {
      throw "Lantern inherited the wrong LOCALAPPDATA: $($diagnostics.localAppData)"
    }
    $diagnostics | ConvertTo-Json | Set-Content (Join-Path $caseDirectory "process.json")
    if ($diagnostics.processIsElevated) {
      throw "The installed Lantern process has an elevated access token"
    }
    $appProcess = Get-Process -Id $diagnostics.processId -ErrorAction Stop

    Wait-File -Path $udfCheckPath -TimeoutSeconds 30
    $udf = Get-Content $udfCheckPath -Raw | ConvertFrom-Json
    Copy-Item $udfCheckPath (Join-Path $caseDirectory "webview2-udf.json") -Force
    $expectedUDF = Join-Path $diagnostics.localAppData "Lantern\WebView2"
    if (-not $udf.exists -or -not $udf.writable -or $udf.path -ne $expectedUDF) {
      throw "Unexpected or unwritable WebView2 folder: $($udf | ConvertTo-Json -Compress)"
    }
    $escapedExpectedUDF = [regex]::Escape($expectedUDF)
    $flutterLogText = Get-Content $flutterLog -Raw
    if ($flutterLogText -notmatch "WEBVIEW2_DIAGNOSTIC user_data_folder=$escapedExpectedUDF") {
      throw "Flutter did not record the actual per-user WebView2 folder $expectedUDF"
    }

    Write-Step "$Provider checkout rendered successfully"
  } finally {
    if ($appProcess) {
      Stop-Process -Id $appProcess.Id -Force -ErrorAction SilentlyContinue
    } elseif ($diagnosticsPath -and (Test-Path $diagnosticsPath)) {
      try {
        $startedProcessID = (Get-Content $diagnosticsPath -Raw | ConvertFrom-Json).processId
        Stop-Process -Id $startedProcessID -Force -ErrorAction SilentlyContinue
      } catch {
      }
    }
    if ($launcherProcess) {
      $launcherProcess.Refresh()
      if (-not $launcherProcess.HasExited -and
          -not $launcherProcess.WaitForExit(5000)) {
        Stop-Process -Id $launcherProcess.Id -Force -ErrorAction SilentlyContinue
      }
    }
    Start-Sleep -Seconds 1
    $childArtifacts = @(
      [pscustomobject]@{
        Source = $launcherLogPath
        Destination = Join-Path $caseDirectory "automation.log"
      },
      [pscustomobject]@{
        Source = $launcherStdoutPath
        Destination = Join-Path $caseDirectory "launcher-stdout.log"
      },
      [pscustomobject]@{
        Source = $launcherStderrPath
        Destination = Join-Path $caseDirectory "launcher-stderr.log"
      },
      [pscustomobject]@{
        Source = $childWebViewPath
        Destination = Join-Path $caseDirectory "webview.json"
      },
      [pscustomobject]@{
        Source = $childCheckoutImagePath
        Destination = Join-Path $caseDirectory "checkout.png"
      },
      [pscustomobject]@{
        Source = $childFinalImagePath
        Destination = Join-Path $caseDirectory "final.png"
      }
    )
    foreach ($artifact in $childArtifacts) {
      if ($artifact.Source -and (Test-Path $artifact.Source)) {
        try {
          Copy-Item $artifact.Source $artifact.Destination -Force
        } catch {
          Write-Warning "Could not collect $($artifact.Source): $_"
        }
      }
    }
    try {
      if (-not (Test-Path (Join-Path $caseDirectory "final.png"))) {
        Save-DesktopScreenshot -Path (Join-Path $caseDirectory "final.png")
      }
    } catch {
      Write-Warning "Could not capture final screenshot: $_"
    }
    if ($udfCheckPath -and (Test-Path $udfCheckPath)) {
      Copy-Item $udfCheckPath (Join-Path $caseDirectory "webview2-udf.json") -Force
    }
    if ($diagnosticsPath -and (Test-Path $diagnosticsPath) -and
        -not (Test-Path (Join-Path $caseDirectory "process.json"))) {
      Copy-Item $diagnosticsPath (Join-Path $caseDirectory "process.json") -Force
    }
    $finalFlutterLog = Join-Path $env:PUBLIC "Lantern\logs\flutter.log"
    if (Test-Path $finalFlutterLog) {
      Select-String -Path $finalFlutterLog `
        -Pattern 'PAYMENT_WEBVIEW_SMOKE|WEBVIEW2_DIAGNOSTIC|PAYMENT_CHECKOUT_SMOKE' |
        ForEach-Object { $_.Line } |
        Set-Content (Join-Path $caseDirectory "webview-events.log")
    }
    try {
      Copy-CaseLogs -Destination $caseDirectory
    } catch {
      Write-Warning "Could not collect payment smoke logs: $_"
    }
    if ($sid -and $sharedAppDirectory -and (Test-Path $sharedAppDirectory)) {
      & icacls.exe $sharedAppDirectory /remove "*$sid" /T /C | Out-Null
    }
    [Environment]::SetEnvironmentVariable(
      "WEBVIEW2_USER_DATA_FOLDER",
      $priorUDF,
      [EnvironmentVariableTarget]::Process
    )
    if ($sid -or (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
      try {
        Remove-SmokeAccount -Username $username -SID $sid
      } catch {
        Write-Warning "Could not fully remove disposable smoke account: $_"
      }
    }
    if ($transcriptStarted) {
      try {
        Stop-Transcript | Out-Null
      } catch {
      }
    }
  }
}

if ($Mode -eq "launcher") {
  if (-not $LauncherConfigPath -or -not (Test-Path $LauncherConfigPath)) {
    throw "Smoke-user launcher config not found: $LauncherConfigPath"
  }
  $launcherConfig = Get-Content $LauncherConfigPath -Raw | ConvertFrom-Json
  Invoke-SmokeUserCheckout `
    -AppPath $launcherConfig.appPath `
    -CheckoutProvider $launcherConfig.provider `
    -CheckoutRunID $launcherConfig.runId `
    -ProcessDiagnosticsPath $launcherConfig.diagnosticsPath `
    -WebViewUDFPath $launcherConfig.udfCheckPath `
    -UserProfilePath $launcherConfig.profilePath `
    -ResultPath $launcherConfig.automationResultPath `
    -AppLogPath $launcherConfig.flutterLogPath `
    -ExpectedHostPattern $launcherConfig.hostPattern `
    -WebViewPath $launcherConfig.webViewResultPath `
    -CheckoutImagePath $launcherConfig.checkoutScreenshotPath `
    -FinalImagePath $launcherConfig.finalScreenshotPath `
    -TranscriptPath $launcherConfig.launcherLogPath `
    -TimeoutSeconds $launcherConfig.waitSeconds
  return
}

if (-not (Test-Path $InstalledAppPath)) {
  throw "Installed Lantern executable not found: $InstalledAppPath"
}

Use-StagingService
Invoke-CheckoutCase -Provider "stripe" -HostPattern '^checkout\.stripe\.com$' `
  -RunID ([Guid]::NewGuid().ToString())
Invoke-CheckoutCase -Provider "shepherd" -HostPattern $ShepherdHostPattern `
  -RunID ([Guid]::NewGuid().ToString())
