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
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupLogging=yes
UninstallLogging=yes

[Languages]
{% for locale in LOCALES %}
{% if locale == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale == 'zh' %}Name: "chinesesimplified"; MessagesFile: "compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% if locale == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}

[Dirs]
Name: "{#ProgramDataDir}"; Permissions: users-modify

[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{{SOURCE_DIR}}\\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{{SOURCE_DIR}}\\lanternsvc.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon

[Run]
; Stop/delete any existing service
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
Filename: "{sys}\sc.exe"; Parameters: "stop ""{#SvcName}"""; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete ""{#SvcName}"""; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{#ProgramDataDir}"

[Code]
var
  VCUrl: string;
  WebView2Url: string;

function NeedsWebView2Runtime(): Boolean;
var
  EdgeVersion: string;
begin
  if RegQueryStringValue(HKLM64,
    'Software\Microsoft\EdgeUpdate\Clients\{F2C8B2F8-5A81-41D0-873A-D1D9F4922A3A}',
    'pv', EdgeVersion) then
  begin
    Result := False;
    Log('WebView2 runtime found: ' + EdgeVersion);
  end
  else
  begin
    Result := True;
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
    if Result then Log('VC++ registry present but Installed=' + IntToStr(Installed))
              else Log('VC++ runtime detected via registry.');
  end
  else
  begin
    Result := not FileExists(ExpandConstant('{sys}\MSVCP140.dll'));
    if Result then Log('MSVCP140.dll missing; VC++ runtime required.')
              else Log('MSVCP140.dll present.');
  end;
end;

function DownloadToTemp(const Url, FileName: string): string;
begin
  try
    Result := DownloadTemporaryFile(Url, FileName, '', nil);
    Log(Format('Downloaded %s to %s', [Url, Result]));
  except
    Log('Download failed for ' + Url + ': ' + GetExceptionMessage);
    Result := '';
  end;
end;

procedure InstallSilentlyIfNeeded(const Title, InstallerPath, Args: string);
var
  Code: Integer;
begin
  if InstallerPath = '' then Exit;
  Log(Format('Running %s: %s %s', [Title, InstallerPath, Args]));
  if not Exec(InstallerPath, Args, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    Log(Format('%s Exec failed. Code=%d', [Title, Code]))
  else
    Log(Format('%s exit code: %d', [Title, Code]));
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  VCRedistPath, WebView2Path: string;
begin
  if CurStep = ssInstall then
  begin
    if NeedsVCRedist() then
    begin
      VCUrl := 'https://aka.ms/vs/17/release/vc_redist.x64.exe';
      VCRedistPath := DownloadToTemp(VCUrl, 'vc_redist.x64.exe');
      InstallSilentlyIfNeeded('VC++ 2015–2022 (x64)', VCRedistPath, '/install /quiet /norestart');
    end;

    if NeedsWebView2Runtime() then
    begin
      WebView2Url := 'https://go.microsoft.com/fwlink/p/?LinkId=2124703';
      WebView2Path := DownloadToTemp(WebView2Url, 'MicrosoftEdgeWebView2Setup.exe');
      InstallSilentlyIfNeeded('WebView2 Evergreen', WebView2Path, '/silent /install');
    end;
  end;
end;