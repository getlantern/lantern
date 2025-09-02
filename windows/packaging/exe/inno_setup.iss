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

; Launch Lantern app UI
Filename: "{app}\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; \
  Flags: runasoriginaluser nowait postinstall skipifsilent

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

function GenerateToken(): string;
var
  g, s: string;
begin
  { Use a GUID + tick count, hashed to a compact hex token }
  g := CreateGUID();
  s := g + '|' + IntToStr(GetTickCount());
  Result := GetSHA1OfString(s);  { 40 hex chars }
end;

procedure CreateTokenFile();
var
  path, dir, existing: string;
begin
  path := ExpandConstant('{#TokenFile}');
  dir := ExtractFileDir(path);

  if not DirExists(dir) then
  begin
    if ForceDirectories(dir) then
      Log(Format('Created token directory: %s', [dir]))
    else
      RaiseException(Format('Failed to create token directory: %s', [dir]));
  end;

  if LoadStringFromFile(path, existing) and (Trim(existing) <> '') then
  begin
    Log('Token file already present; keeping existing value.');
    exit;
  end;

  if not SaveStringToFile(path, GenerateToken(), False) then
    RaiseException(Format('Failed to write token to %s', [path]))
  else
    Log(Format('Created token file at %s', [path]));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  { Create the token }
  if CurStep = ssInstall then
  begin
    try
      CreateTokenFile();
    except
      { If we cannot create the token, abort install }
      RaiseException('Failed to create IPC token');
    end;
  end;
end;