#define SourceDirMacro   "{{SOURCE_DIR}}"
#define SvcName          "LanternSvc"
#define SvcDisplayName   "Lantern Service"
#define ProgramDataDir   "{commonappdata}\Lantern"
#define TokenFile        "{commonappdata}\Lantern\ipc-token"

[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={autopf}\{{DISPLAY_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; VPN service/driver install needs elevation
PrivilegesRequired=admin
; PrivilegesRequiredOverridesAllowed=dialog

ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
{% for locale in LOCALES %}
{% if locale == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale == 'zh' %}Name: "chinesesimplified"; MessagesFile: "compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% if locale == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}

[Dirs]
Name: "{#ProgramDataDir}"; Permissions: users-modify; Flags: uninsalwaysuninstall

[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{{SOURCE_DIR}}\\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion
; Windows service binary
Source: "{{SOURCE_DIR}}\\lanternsvc.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon

[Downloads]
Source: "https://go.microsoft.com/fwlink/p/?LinkId=2124703"; DestFile: "{tmp}\MicrosoftEdgeWebView2Setup.exe"; Flags: external
; Latest supported Visual C++ Redistributable
Source: "https://aka.ms/vs/17/release/vc_redist.x64.exe"; DestFile: "{tmp}\vc_redist.x64.exe"; Flags: external

[Run]
; VC++ runtime (fixes MSVCP140/VCRUNTIME errors)
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Installing Microsoft Visual C++ 2015–2022 Runtime (x64)…"; \
  Check: NeedsVCRedist and FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe')); \
  Flags: runhidden

; Install WebView2 Evergreen for Flutter
Filename: "{tmp}\MicrosoftEdgeWebView2Setup.exe"; Parameters: "/silent /install"; \
  StatusMsg: "Installing WebView2 Runtime..."; \
  Check: NeedsWebView2Runtime and FileExists(ExpandConstant('{tmp}\MicrosoftEdgeWebView2Setup.exe'))

; Stop and delete any existing Lantern service
Filename: "{cmd}"; Parameters: "/C sc.exe stop ""{#SvcName}"" 2>nul & sc.exe delete ""{#SvcName}"" 2>nul"; \
  Flags: runhidden

; Create service (LocalSystem by default), delayed-auto start
; NOTE: one set of quotes around binPath only
Filename: "{cmd}"; Parameters: "/C sc.exe create ""{#SvcName}"" binPath= ""{app}\lanternsvc.exe"" start= delayed-auto DisplayName= ""{#SvcDisplayName}"""; \
  Flags: runhidden

Filename: "{cmd}"; Parameters: "/C sc.exe description ""{#SvcName}"" ""Lantern VPN service"""; \
  Flags: runhidden

Filename: "{cmd}"; Parameters: "/C sc.exe failure ""{#SvcName}"" reset= 86400 actions= restart/5000/restart/5000/restart/5000"; \
  Flags: runhidden

Filename: "{cmd}"; Parameters: "/C sc.exe failureflag ""{#SvcName}"" 1"; \
  Flags: runhidden

; Start service
Filename: "{cmd}"; Parameters: "/C sc.exe start ""{#SvcName}"""; \
  Flags: runhidden

; Wait for service to be running before launching UI
Filename: "powershell.exe"; Flags: runhidden; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""$svc=$null; for($i=0;$i -lt 30;$i++){ $svc=Get-Service -Name '{#SvcName}' -ErrorAction SilentlyContinue; if($svc -and $svc.Status -eq 'Running'){ exit 0 }; Start-Sleep -Seconds 1 }; exit 1"""

; Launch Lantern app UI
Filename: "{app}\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; \
  Flags: runasoriginaluser nowait postinstall skipifsil

[UninstallRun]
; Stop and remove the service on uninstall
Filename: "{cmd}"; Parameters: "/C sc.exe stop ""{#SvcName}"" 2>nul & sc.exe delete ""{#SvcName}"" 2>nul"; \
  Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{#ProgramDataDir}"

[Code]
function NeedsWebView2Runtime(): Boolean;
var
  EdgeVersion: string;
begin
  if RegQueryStringValue(HKLM64, 'Software\Microsoft\EdgeUpdate\Clients\{F2C8B2F8-5A81-41D0-873A-D1D9F4922A3A}', 'pv', EdgeVersion) then
  begin
    Result := False;
  end
  else
  begin
    Result := True; // WebView2 is not installed
  end;
end;

function NeedsVCRedist(): Boolean;
var
  Installed: Cardinal;
begin
  { VS 2015–2022 x64 runtime flag }
  if RegQueryDWordValue(HKLM64,
    'Software\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Installed', Installed) then
  begin
    Result := (Installed <> 1);
  end
  else
  begin
    Result := not FileExists(ExpandConstant('{sys}\MSVCP140.dll'));
  end;
end;