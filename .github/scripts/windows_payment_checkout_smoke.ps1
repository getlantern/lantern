param(
  [ValidateSet("orchestrator", "launcher")]
  [string]$Mode = "orchestrator",
  [string]$ServiceName = "LanternSvc",
  [string]$InstalledAppPath = "C:\Program Files\Lantern\Lantern.exe",
  [string]$InstalledDaemonPath = "C:\Program Files\Lantern\lanternd.exe",
  [string]$ArtifactDirectory = "build/windows-payment-checkout-smoke",
  [int]$WaitSeconds = 180,
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
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function Initialize-NativeSmokeHelpers {
  if ("WindowsPaymentSmoke.NativeToken" -as [type]) {
    return
  }

  Add-Type -TypeDefinition @'
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
        throw new System.ComponentModel.Win32Exception();
      }
      try {
        System.IntPtr token;
        if (!OpenProcessToken(process, TOKEN_QUERY, out token)) {
          throw new System.ComponentModel.Win32Exception();
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
            throw new System.ComponentModel.Win32Exception();
          }
          return elevation.TokenIsElevated != 0;
        } finally {
          CloseHandle(token);
        }
      } finally {
        CloseHandle(process);
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
      System.Collections.Generic.List<string> windows =
        new System.Collections.Generic.List<string>();
      EnumWindows(delegate(System.IntPtr topLevel, System.IntPtr parameter) {
        uint owner;
        GetWindowThreadProcessId(topLevel, out owner);
        if (owner != processId) {
          return true;
        }
        windows.Add(ClassName(topLevel));
        EnumChildWindows(
          topLevel,
          delegate(System.IntPtr child, System.IntPtr childParameter) {
            windows.Add(ClassName(child));
            return true;
          },
          System.IntPtr.Zero);
        return true;
      }, System.IntPtr.Zero);
      return string.Join(",", windows.ToArray());
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

function Find-AutomationElement {
  param(
    [System.Windows.Automation.AutomationElement]$Root,
    [string]$AutomationID,
    [int]$TimeoutSeconds,
    [string]$FailureLogPath,
    [switch]$Optional
  )
  $condition = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
    $AutomationID
  )
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    $element = $Root.FindFirst(
      [System.Windows.Automation.TreeScope]::Descendants,
      $condition
    )
    if ($element) { return $element }
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
  if ($Optional) { return $null }
  throw "Timed out waiting for UI Automation element '$AutomationID'"
}

function Invoke-AutomationElement {
  param([System.Windows.Automation.AutomationElement]$Element)
  $pattern = $null
  if ($Element.TryGetCurrentPattern(
      [System.Windows.Automation.InvokePattern]::Pattern,
      [ref]$pattern
    )) {
    ([System.Windows.Automation.InvokePattern]$pattern).Invoke()
    return
  }

  $point = $Element.GetClickablePoint()
  [System.Windows.Forms.Cursor]::Position = [System.Drawing.Point]::new(
    [int]$point.X,
    [int]$point.Y
  )
  [WindowsPaymentSmoke.NativeMouse]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  [WindowsPaymentSmoke.NativeMouse]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
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
    Start-Sleep -Seconds 1
  }
  if ($lastLogText -match 'PAYMENT_WEBVIEW_SMOKE event=navigation_error') {
    throw "The checkout WebView reported a main-frame navigation error"
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
    $app = Start-Process -FilePath $AppPath -ArgumentList @(
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

    Write-Step "Attached UI Automation to Lantern's FLUTTERVIEW child window"
    $root = [System.Windows.Automation.AutomationElement]::FromHandle(
      $flutterViewHandle
    )
    $providerElement = Find-AutomationElement -Root $root `
      -AutomationID "payment-provider-$CheckoutProvider" -TimeoutSeconds 90 `
      -FailureLogPath $AppLogPath
    $checkoutElement = Find-AutomationElement -Root $root `
      -AutomationID "payment-checkout-$CheckoutProvider" `
      -TimeoutSeconds 2 -Optional
    if (-not $checkoutElement) {
      Invoke-AutomationElement -Element $providerElement
      $checkoutElement = Find-AutomationElement -Root $root `
        -AutomationID "payment-checkout-$CheckoutProvider" `
        -TimeoutSeconds 20 -FailureLogPath $AppLogPath
    }
    Invoke-AutomationElement -Element $checkoutElement

    Wait-CheckoutDocument -LogPath $AppLogPath `
      -HostPattern $ExpectedHostPattern -TimeoutSeconds $TimeoutSeconds `
      -ResultPath $WebViewPath

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
    $profile = Get-CimInstance Win32_UserProfile -Filter "SID='$SID'" -ErrorAction SilentlyContinue
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
    # The daemon accepts members of Administrators. UAC still gives the app a
    # filtered, non-elevated token, which the checks below verify.
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
      -ArgumentList @("-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "exit 0")
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
    $launcherCommandLine = $launcherArguments -join " "
    if ($launcherCommandLine.Length -gt 900) {
      throw "Smoke-user launcher command line is too long"
    }
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
