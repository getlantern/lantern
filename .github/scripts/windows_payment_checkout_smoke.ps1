param(
  [string]$ServiceName = "LanternSvc",
  [string]$InstalledAppPath = "C:\Program Files\Lantern\Lantern.exe",
  [string]$InstalledDaemonPath = "C:\Program Files\Lantern\lanternd.exe",
  [string]$ArtifactDirectory = "build/windows-payment-checkout-smoke",
  [int]$WaitSeconds = 180,
  [string]$ShepherdHostPattern = '(^|\.)m62mrsf\.com$',
  [bool]$RunCheckoutCases = $true,
  [bool]$RunPaymentConversion = $false
)

$ErrorActionPreference = "Stop"
$resolvedArtifacts = [System.IO.Path]::GetFullPath($ArtifactDirectory)
New-Item -ItemType Directory -Path $resolvedArtifacts -Force | Out-Null

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
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
}
'@

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
  $serviceDataPath = Join-Path $env:ProgramData "Lantern\payment-smoke-data"
  $serviceLogPath = Join-Path $env:ProgramData "Lantern\payment-smoke-logs"
  Remove-Item $serviceDataPath -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $serviceLogPath -Recurse -Force -ErrorAction SilentlyContinue
  & $InstalledDaemonPath install --environment staging `
    --data-path $serviceDataPath --log-path $serviceLogPath --log-level debug
  if ($LASTEXITCODE -ne 0) {
    throw "lanternd staging install failed with exit code $LASTEXITCODE"
  }
  Wait-ServiceRunning -Name $ServiceName -TimeoutSeconds 60
  Start-Sleep -Seconds 5

  $service = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'"
  if ($service.PathName -notmatch '(?i)--environment\s+staging') {
    throw "Installed service command does not persist --environment staging: $($service.PathName)"
  }
  if ($service.PathName -notmatch [regex]::Escape($serviceDataPath)) {
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

function Find-AutomationElement {
  param(
    [System.Windows.Automation.AutomationElement]$Root,
    [string]$Name,
    [int]$TimeoutSeconds,
    [switch]$Optional
  )
  $condition = [System.Windows.Automation.PropertyCondition]::new(
    [System.Windows.Automation.AutomationElement]::NameProperty,
    $Name
  )
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    $element = $Root.FindFirst(
      [System.Windows.Automation.TreeScope]::Descendants,
      $condition
    )
    if ($element) { return $element }
    Start-Sleep -Seconds 1
  }
  if ($Optional) { return $null }
  throw "Timed out waiting for UI Automation element '$Name'"
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
  $daemonLogDirectory = Join-Path $env:ProgramData "Lantern"
  if (Test-Path $daemonLogDirectory) {
    Copy-Item $daemonLogDirectory (Join-Path $Destination "daemon-logs") -Recurse -Force
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
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Path $LogPath) {
      $logText = Get-Content $LogPath -Raw -ErrorAction SilentlyContinue
      if ($logText -match 'PAYMENT_WEBVIEW_SMOKE event=navigation_error') {
        throw "The checkout WebView reported a main-frame navigation error"
      }
      if ($logText -match 'PAYMENT_WEBVIEW_SMOKE event=document_error') {
        throw "The checkout WebView could not inspect the loaded document"
      }
      foreach ($match in [regex]::Matches($logText, $linePattern)) {
        $hostName = $match.Groups[1].Value
        $documentLength = [int]$match.Groups[3].Value
        if ($hostName -match $HostPattern -and $documentLength -gt 0) {
          if ($logText -notmatch 'PAYMENT_WEBVIEW_SMOKE event=created') {
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
  throw "No non-empty checkout document loaded from expected host pattern $HostPattern"
}

function Wait-PaymentConversion {
  param(
    [string]$LogPath,
    [int]$TimeoutSeconds,
    [string]$ResultPath
  )
  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    if (Test-Path $LogPath) {
      $logText = Get-Content $LogPath -Raw -ErrorAction SilentlyContinue
      if ($logText -match 'PAYMENT_WEBVIEW_SMOKE event=navigation_error') {
        throw "The conversion WebView reported a main-frame navigation error"
      }
      $callback = $logText -match 'PAYMENT_WEBVIEW_SMOKE event=purchase_result .* result=true'
      $serverPro = $logText -match 'PAYMENT_CONVERSION_SMOKE event=server_user attempt=\d+ userLevel=pro'
      $localPro = $logText -match 'PAYMENT_CONVERSION_SMOKE event=local_user userLevel=pro'
      $successUI = $logText -match 'PAYMENT_CONVERSION_SMOKE event=success_ui userLevel=pro'
      if ($callback -and $serverPro -and $localPro -and $successUI) {
        @{
          purchaseResult = $true
          serverUserLevel = "pro"
          localUserLevel = "pro"
          successUI = $true
        } | ConvertTo-Json | Set-Content $ResultPath
        return
      }
      if ($logText -match 'PAYMENT_CONVERSION_SMOKE event=account_timeout') {
        throw "The app timed out waiting for the staging account to become Pro"
      }
    }
    Start-Sleep -Seconds 1
  }
  throw "The installed app did not complete the payment-to-Pro flow"
}

function Remove-SmokeAccount {
  param([string]$Username, [string]$SID)
  Get-Process Lantern -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $Username
  }
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
  param(
    [string]$Provider,
    [string]$HostPattern,
    [string]$RunID,
    [switch]$CompletePayment
  )

  $caseDirectory = Join-Path $resolvedArtifacts $Provider
  New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
  $mode = if ($CompletePayment) { "conversion" } else { "render" }
  $remoteCleanup = if ($CompletePayment) {
    "queued by the staging redirect before checkout issuance"
  } else {
    "not applicable"
  }
  @{
    provider = $Provider
    runId = $RunID
    githubRunId = $env:GITHUB_RUN_ID
    githubRunAttempt = $env:GITHUB_RUN_ATTEMPT
    mode = $mode
    remoteCleanup = $remoteCleanup
  } | ConvertTo-Json | Set-Content (Join-Path $caseDirectory "run.json")
  $transcript = Join-Path $caseDirectory "automation.log"
  Start-Transcript -Path $transcript -Force | Out-Null

  $username = "lntsmk" + ([Guid]::NewGuid().ToString("N").Substring(0, 10))
  $passwordText = "L@ntern!" + ([Guid]::NewGuid().ToString("N"))
  $securePassword = ConvertTo-SecureString $passwordText -AsPlainText -Force
  $credential = [System.Management.Automation.PSCredential]::new(
    ".\$username",
    $securePassword
  )
  $user = New-LocalUser -Name $username -Password $securePassword `
    -AccountNeverExpires -PasswordNeverExpires
  $sid = $user.SID.Value
  $launcherProcess = $null
  $appProcess = $null
  $root = $null
  $priorUDF = [Environment]::GetEnvironmentVariable(
    "WEBVIEW2_USER_DATA_FOLDER",
    [EnvironmentVariableTarget]::Process
  )

  try {
    Write-Step "Starting $Provider checkout as disposable standard user $username"
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
    $launcherPath = Join-Path $exchangeDirectory "launch.ps1"
    $launcher = @'
param(
  [string]$AppPath,
  [string]$Provider,
  [string]$RunID,
  [string]$DiagnosticsPath,
  [string]$UDFCheckPath
)
$ErrorActionPreference = "Stop"
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$installWritePath = Join-Path (Split-Path $AppPath -Parent) ("smoke-write-" + [Guid]::NewGuid().ToString("N"))
$canWriteInstallDirectory = $false
try {
  New-Item -ItemType File -Path $installWritePath -Force -ErrorAction Stop | Out-Null
  $canWriteInstallDirectory = $true
} catch {
} finally {
  Remove-Item $installWritePath -Force -ErrorAction SilentlyContinue
}
$localAppData = [Environment]::GetFolderPath("LocalApplicationData")
$externalUDF = [Environment]::GetEnvironmentVariable("WEBVIEW2_USER_DATA_FOLDER", "Process")
$app = Start-Process -FilePath $AppPath -ArgumentList @(
  "--payment-checkout-smoke=$Provider",
  "--payment-checkout-run-id=$RunID"
) -PassThru
@{
  processId = $app.Id
  username = $identity.Name
  isAdmin = $isAdmin
  canWriteInstallDirectory = $canWriteInstallDirectory
  externalWebView2UserDataFolder = $externalUDF
  localAppData = $localAppData
} | ConvertTo-Json | Set-Content $DiagnosticsPath

$udfPath = Join-Path $localAppData "Lantern\WebView2"
for ($i = 0; $i -lt 180; $i++) {
  if (Test-Path $udfPath) { break }
  if ($app.HasExited) { break }
  Start-Sleep -Seconds 1
  $app.Refresh()
}
$udfWritable = $false
$udfProbe = Join-Path $udfPath ("write-probe-" + [Guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType File -Path $udfProbe -Force -ErrorAction Stop | Out-Null
  $udfWritable = $true
} catch {
} finally {
  Remove-Item $udfProbe -Force -ErrorAction SilentlyContinue
}
@{
  path = $udfPath
  exists = (Test-Path $udfPath)
  writable = $udfWritable
} | ConvertTo-Json | Set-Content $UDFCheckPath
$app.WaitForExit()
'@
    Set-Content -Path $launcherPath -Value $launcher

    $launcherArguments = @(
      "-NoLogo",
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", "`"$launcherPath`"",
      "-AppPath", "`"$InstalledAppPath`"",
      "-Provider", $Provider,
      "-RunID", $RunID,
      "-DiagnosticsPath", "`"$diagnosticsPath`"",
      "-UDFCheckPath", "`"$udfCheckPath`""
    )
    $launcherProcess = Start-Process -FilePath "powershell.exe" `
      -Credential $credential -LoadUserProfile `
      -ArgumentList $launcherArguments -PassThru

    Wait-File -Path $diagnosticsPath -TimeoutSeconds 45
    $diagnostics = Get-Content $diagnosticsPath -Raw | ConvertFrom-Json
    if ($diagnostics.isAdmin) {
      throw "The installed app was launched from an administrator account"
    }
    if ($diagnostics.canWriteInstallDirectory) {
      throw "The smoke user can write beside the installed executable"
    }
    if (-not [string]::IsNullOrWhiteSpace($diagnostics.externalWebView2UserDataFolder)) {
      throw "Primary smoke inherited WEBVIEW2_USER_DATA_FOLDER=$($diagnostics.externalWebView2UserDataFolder)"
    }

    $appProcess = Wait-ProcessMainWindow -ProcessID $diagnostics.processId -TimeoutSeconds 90
    $processIsElevated = [WindowsPaymentSmoke.NativeToken]::IsElevated($appProcess.Id)
    $diagnostics | Add-Member -NotePropertyName processIsElevated `
      -NotePropertyValue $processIsElevated
    $diagnostics | ConvertTo-Json | Set-Content (Join-Path $caseDirectory "process.json")
    if ($processIsElevated) {
      throw "The installed Lantern process has an elevated access token"
    }
    $root = [System.Windows.Automation.AutomationElement]::FromHandle(
      $appProcess.MainWindowHandle
    )
    $providerElement = Find-AutomationElement -Root $root `
      -Name "payment-provider-$Provider" -TimeoutSeconds 90
    $checkoutElement = Find-AutomationElement -Root $root `
      -Name "payment-checkout-$Provider" -TimeoutSeconds 2 -Optional
    if (-not $checkoutElement) {
      Invoke-AutomationElement -Element $providerElement
      $checkoutElement = Find-AutomationElement -Root $root `
        -Name "payment-checkout-$Provider" -TimeoutSeconds 20
    }
    Invoke-AutomationElement -Element $checkoutElement

    $flutterLog = Join-Path $env:PUBLIC "Lantern\logs\flutter.log"
    Wait-CheckoutDocument -LogPath $flutterLog -HostPattern $HostPattern `
      -TimeoutSeconds $WaitSeconds -ResultPath (Join-Path $caseDirectory "webview.json")

    if ($CompletePayment) {
      Save-WindowScreenshot -Root $root `
        -Path (Join-Path $caseDirectory "checkout.png")
      $completeElement = Find-AutomationElement -Root $root `
        -Name "Complete" -TimeoutSeconds 30
      Invoke-AutomationElement -Element $completeElement
      Wait-PaymentConversion -LogPath $flutterLog `
        -TimeoutSeconds $WaitSeconds `
        -ResultPath (Join-Path $caseDirectory "conversion.json")
      $successElement = Find-AutomationElement -Root $root `
        -Name "payment-conversion-success" -TimeoutSeconds 30
      Save-WindowScreenshot -Root $root `
        -Path (Join-Path $caseDirectory "pro-success.png")
    }

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

    if ($CompletePayment) {
      Write-Step "$Provider checkout converted the installed app to Pro"
    } else {
      Save-WindowScreenshot -Root $root `
        -Path (Join-Path $caseDirectory "checkout.png")
      Write-Step "$Provider checkout rendered successfully"
    }
  } finally {
    try {
      if ($root) {
        Save-WindowScreenshot -Root $root -Path (Join-Path $caseDirectory "final.png")
      } else {
        Save-DesktopScreenshot -Path (Join-Path $caseDirectory "final.png")
      }
    } catch {
      Write-Warning "Could not capture final screenshot: $_"
    }
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
      Stop-Process -Id $launcherProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
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
        -Pattern 'PAYMENT_WEBVIEW_SMOKE|WEBVIEW2_DIAGNOSTIC|PAYMENT_CHECKOUT_SMOKE|PAYMENT_CONVERSION_SMOKE' |
        ForEach-Object { $_.Line } |
        Set-Content (Join-Path $caseDirectory "webview-events.log")
    }
    try {
      Copy-CaseLogs -Destination $caseDirectory
    } catch {
      Write-Warning "Could not collect payment smoke logs: $_"
    }
    if ($sharedAppDirectory -and (Test-Path $sharedAppDirectory)) {
      & icacls.exe $sharedAppDirectory /remove "*$sid" /T /C | Out-Null
    }
    [Environment]::SetEnvironmentVariable(
      "WEBVIEW2_USER_DATA_FOLDER",
      $priorUDF,
      [EnvironmentVariableTarget]::Process
    )
    try {
      Remove-SmokeAccount -Username $username -SID $sid
    } catch {
      Write-Warning "Could not fully remove disposable smoke account: $_"
    }
    try {
      Stop-Transcript | Out-Null
    } catch {
    }
  }
}

if (-not (Test-Path $InstalledAppPath)) {
  throw "Installed Lantern executable not found: $InstalledAppPath"
}

if (-not $RunCheckoutCases -and -not $RunPaymentConversion) {
  throw "No payment smoke cases were selected"
}
Use-StagingService
if ($RunCheckoutCases) {
  Invoke-CheckoutCase -Provider "stripe" -HostPattern '^checkout\.stripe\.com$' `
    -RunID ([Guid]::NewGuid().ToString())
  Invoke-CheckoutCase -Provider "shepherd" -HostPattern $ShepherdHostPattern `
    -RunID ([Guid]::NewGuid().ToString())
}
if ($RunPaymentConversion) {
  Invoke-CheckoutCase -Provider "e2e" `
    -HostPattern '^api\.staging\.iantem\.io$' `
    -RunID ([Guid]::NewGuid().ToString()) `
    -CompletePayment
}
