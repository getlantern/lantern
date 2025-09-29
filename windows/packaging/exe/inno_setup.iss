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
PrivilegesRequiredOverridesAllowed=dialog
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
; Make sure ProgramData\Lantern exists and is readable by user sessions
Name: "{#ProgramDataDir}"; Permissions: users-modify

[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Windows service binary
Source: "{{SOURCE_DIR}}\\lanternsvc.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon

[Downloads]
Source: "https://go.microsoft.com/fwlink/p/?LinkId=2124703"; DestFile: "{tmp}\MicrosoftEdgeWebView2Setup.exe"; Flags: external
; This link always points to the latest supported Visual C++ Redistributable
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

; Stop and delete any existing Lantern service, then create & start the new one
Filename: "{sys}\sc.exe"; Parameters: "stop ""{#SvcName}"""; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete ""{#SvcName}"""; Flags: runhidden

; Create service
Filename: "{sys}\sc.exe"; \
  Parameters: "create ""{#SvcName}"" binPath= """"{app}\lanternsvc.exe"""" start= delayed-auto DisplayName= ""{#SvcDisplayName}"""; \
  Flags: runhidden
  
Filename: "{sys}\sc.exe"; Parameters: "failure ""{#SvcName}"" reset= 60 actions= restart/5000/restart/5000/""""/5000"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "failureflag ""{#SvcName}"" 1"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "description ""{#SvcName}"" ""Lantern Windows service"""; Flags: runhidden

; Start service
Filename: "{sys}\sc.exe"; Parameters: "start ""{#SvcName}"""; Flags: runhidden

; Launch Lantern app UI
Filename: "{app}\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; \
  Flags: runasoriginaluser nowait postinstall skipifsilent

[UninstallRun]
; Stop and remove service on uninstall
Filename: "{sys}\sc.exe"; Parameters: "stop ""{#SvcName}"""; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete ""{#SvcName}"""; Flags: runhidden

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
