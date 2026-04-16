[Code]
// https://github.com/DomGries/InnoDependencyInstaller

// types and variables
type
  TDependency_Entry = record
    Filename: String;
    Parameters: String;
    Title: String;
    URL: String;
    Checksum: String;
    ForceSuccess: Boolean;
    RestartAfter: Boolean;
  end;

var
  Dependency_Memo: String;
  Dependency_List: array of TDependency_Entry;
  Dependency_NeedToRestart, Dependency_ForceX86: Boolean;
  Dependency_DownloadPage: TDownloadWizardPage;
  PreInstallCleanupDone: Boolean;

procedure PreInstallLanternCleanup; forward;

procedure Dependency_Add(const Filename, Parameters, Title, URL, Checksum: String; const ForceSuccess, RestartAfter: Boolean);
var
  Dependency: TDependency_Entry;
  DependencyCount: Integer;
begin
  Dependency_Memo := Dependency_Memo + #13#10 + '%1' + Title;

  Dependency.Filename := Filename;
  Dependency.Parameters := Parameters;
  Dependency.Title := Title;

  if FileExists(ExpandConstant('{tmp}{\}') + Filename) then begin
    Dependency.URL := '';
  end else begin
    Dependency.URL := URL;
  end;

  Dependency.Checksum := Checksum;
  Dependency.ForceSuccess := ForceSuccess;
  Dependency.RestartAfter := RestartAfter;

  DependencyCount := GetArrayLength(Dependency_List);
  SetArrayLength(Dependency_List, DependencyCount + 1);
  Dependency_List[DependencyCount] := Dependency;
end;

<event('InitializeWizard')>
procedure Dependency_InitializeWizard;
begin
  Dependency_DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

<event('PrepareToInstall')>
function Dependency_PrepareToInstall(var NeedsRestart: Boolean): String;
var
  DependencyCount, DependencyIndex, ResultCode: Integer;
  Retry: Boolean;
  TempValue: String;
begin
  DependencyCount := GetArrayLength(Dependency_List);

  if DependencyCount > 0 then begin
    Dependency_DownloadPage.Show;

    for DependencyIndex := 0 to DependencyCount - 1 do begin
      if Dependency_List[DependencyIndex].URL <> '' then begin
        Dependency_DownloadPage.Clear;
        Dependency_DownloadPage.Add(Dependency_List[DependencyIndex].URL, Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Checksum);

        Retry := True;
        while Retry do begin
          Retry := False;

          try
            Dependency_DownloadPage.Download;
          except
            if Dependency_DownloadPage.AbortedByUser then begin
              Result := Dependency_List[DependencyIndex].Title;
              DependencyIndex := DependencyCount;
            end else begin
              case SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbError, MB_ABORTRETRYIGNORE, IDIGNORE) of
                IDABORT: begin
                  Result := Dependency_List[DependencyIndex].Title;
                  DependencyIndex := DependencyCount;
                end;
                IDRETRY: begin
                  Retry := True;
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    if Result = '' then begin
      for DependencyIndex := 0 to DependencyCount - 1 do begin
        Dependency_DownloadPage.SetText(Dependency_List[DependencyIndex].Title, '');
        Dependency_DownloadPage.SetProgress(DependencyIndex + 1, DependencyCount + 1);

        while True do begin
          ResultCode := 0;
#ifdef Dependency_CustomExecute
          if {#Dependency_CustomExecute}(ExpandConstant('{tmp}{\}') + Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Parameters, ResultCode) then begin
#else
          if ShellExec('', ExpandConstant('{tmp}{\}') + Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Parameters, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then begin
#endif
            if Dependency_List[DependencyIndex].RestartAfter then begin
              if DependencyIndex = DependencyCount - 1 then begin
                Dependency_NeedToRestart := True;
              end else begin
                NeedsRestart := True;
                Result := Dependency_List[DependencyIndex].Title;
              end;
              break;
            end else if (ResultCode = 0) or Dependency_List[DependencyIndex].ForceSuccess then begin // ERROR_SUCCESS (0)
              break;
            end else if ResultCode = 1641 then begin // ERROR_SUCCESS_REBOOT_INITIATED (1641)
              NeedsRestart := True;
              Result := Dependency_List[DependencyIndex].Title;
              break;
            end else if ResultCode = 3010 then begin // ERROR_SUCCESS_REBOOT_REQUIRED (3010)
              Dependency_NeedToRestart := True;
              break;
            end;
          end;

          case SuppressibleMsgBox(FmtMessage(SetupMessage(msgErrorFunctionFailed), [Dependency_List[DependencyIndex].Title, IntToStr(ResultCode)]), mbError, MB_ABORTRETRYIGNORE, IDIGNORE) of
            IDABORT: begin
              Result := Dependency_List[DependencyIndex].Title;
              break;
            end;
            IDIGNORE: begin
              break;
            end;
          end;
        end;

        if Result <> '' then begin
          break;
        end;
      end;

      if NeedsRestart then begin
        TempValue := '"' + ExpandConstant('{srcexe}') + '" /restart=1 /LANG="' + ExpandConstant('{language}') + '" /DIR="' + WizardDirValue + '" /GROUP="' + WizardGroupValue + '" /TYPE="' + WizardSetupType(False) + '" /COMPONENTS="' + WizardSelectedComponents(False) + '" /TASKS="' + WizardSelectedTasks(False) + '"';
        if WizardNoIcons then begin
          TempValue := TempValue + ' /NOICONS';
        end;
        RegWriteStringValue(HKA, 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', '{#SetupSetting("AppName")}', TempValue);
      end;
    end;

    if Result = '' then begin
      PreInstallLanternCleanup;
    end;

    Dependency_DownloadPage.Hide;
  end;
end;

#ifndef Dependency_NoUpdateReadyMemo
<event('UpdateReadyMemo')>
#endif
function Dependency_UpdateReadyMemo(const Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := '';
  if MemoUserInfoInfo <> '' then begin
    Result := Result + MemoUserInfoInfo + Newline + NewLine;
  end;
  if MemoDirInfo <> '' then begin
    Result := Result + MemoDirInfo + Newline + NewLine;
  end;
  if MemoTypeInfo <> '' then begin
    Result := Result + MemoTypeInfo + Newline + NewLine;
  end;
  if MemoComponentsInfo <> '' then begin
    Result := Result + MemoComponentsInfo + Newline + NewLine;
  end;
  if MemoGroupInfo <> '' then begin
    Result := Result + MemoGroupInfo + Newline + NewLine;
  end;
  if MemoTasksInfo <> '' then begin
    Result := Result + MemoTasksInfo;
  end;

  if Dependency_Memo <> '' then begin
    if MemoTasksInfo = '' then begin
      Result := Result + SetupMessage(msgReadyMemoTasks);
    end;
    Result := Result + FmtMessage(Dependency_Memo, [Space]);
  end;
end;

<event('NeedRestart')>
function Dependency_NeedRestart: Boolean;
begin
  Result := Dependency_NeedToRestart;
end;

function Dependency_IsX64: Boolean;
begin
  Result := not Dependency_ForceX86 and Is64BitInstallMode;
end;

function Dependency_String(const x86, x64: String): String;
begin
  if Dependency_IsX64 then begin
    Result := x64;
  end else begin
    Result := x86;
  end;
end;

function Dependency_ArchSuffix: String;
begin
  Result := Dependency_String('', '_x64');
end;

function Dependency_ArchTitle: String;
begin
  Result := Dependency_String(' (x86)', ' (x64)');
end;

procedure Dependency_AddVC2015To2022;
begin
  // https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
  if not IsMsiProductInstalled(Dependency_String('{65E5BD06-6392-3027-8C26-853107D3CF1A}', '{36F68A90-239C-34DF-B58C-64B30153CE35}'), PackVersionComponents(14, 42, 34433, 0)) then begin
    Dependency_Add('vcredist2022' + Dependency_ArchSuffix + '.exe',
      '/passive /norestart',
      'Visual C++ 2015-2022 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://aka.ms/vs/17/release/vc_redist.x86.exe', 'https://aka.ms/vs/17/release/vc_redist.x64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddWebView2;
begin
  // https://developer.microsoft.com/en-us/microsoft-edge/webview2
  if not RegValueExists(HKLM, Dependency_String('SOFTWARE', 'SOFTWARE\WOW6432Node') + '\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv') then begin
    Dependency_Add('MicrosoftEdgeWebview2Setup.exe',
      '/silent /install',
      'WebView2 Runtime',
      'https://go.microsoft.com/fwlink/p/?LinkId=2124703',
      '', False, False);
  end;
end;

#define SourceDirMacro   "{{SOURCE_DIR}}"
#define SvcName          "LanternSvc"
#define SvcDisplayName   "Lantern Service"
#define UiExeName        "{{EXECUTABLE_NAME}}"
#define SvcExeName       "lanternsvc.exe"
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
ForceCloseApplications=yes
ArchitecturesAllowed=x64compatible arm64
ArchitecturesInstallIn64BitMode=x64compatible arm64
SetupLogging=yes
UninstallLogging=yes
CloseApplications=yes
RestartApplications=no

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

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon

[Run]
; Launch Lantern app UI
Filename: "{app}\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; \
  Flags: runasoriginaluser nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\sc.exe"; Parameters: "stop ""{#SvcName}"""; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete ""{#SvcName}"""; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{#ProgramDataDir}"

[Code]
const
  ServiceDeleteTimeoutMs = 20000;
  ServiceStartTimeoutMs = 30000;
  TokenReadyTimeoutMs = 30000;
  ServicePollIntervalMs = 250;
  ServiceStopTimeoutMs = 20000;
  ServiceNotRunningExitCode = 1062;
  ServiceDoesNotExistExitCode = 1060;
  ServiceAlreadyRunningExitCode = 1056;
  ServiceExistsExitCode = 1073;
  UninstallRegSubKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1';

function WaitForServiceStopped(const TimeoutMs: Integer): Boolean; forward;

function IsAbsoluteWindowsPath(const Path: String): Boolean;
begin
  Result :=
    ((Length(Path) >= 3) and (Path[2] = ':') and (Path[3] = '\')) or
    ((Length(Path) >= 2) and (Copy(Path, 1, 2) = '\\'));
end;

function ExtractExecutablePath(const CommandLine: String): String;
var
  S: String;
  Candidate: String;
  LowerS: String;
  ExePos: Integer;
  EndQuote: Integer;
  FirstSpace: Integer;
begin
  Result := '';
  S := Trim(CommandLine);
  if S = '' then begin
    exit;
  end;

  if S[1] = '"' then begin
    Delete(S, 1, 1);
    EndQuote := Pos('"', S);
    if EndQuote > 0 then begin
      Result := Copy(S, 1, EndQuote - 1);
    end else begin
      Result := S;
    end;
    if not IsAbsoluteWindowsPath(Result) then begin
      Result := '';
    end;
    exit;
  end;

  // UninstallString can be unquoted even when the path contains spaces.
  // Extract through ".exe" and only trust absolute paths.
  LowerS := LowerCase(S);
  ExePos := Pos('.exe', LowerS);
  if ExePos > 0 then begin
    if (Length(S) = ExePos + 3) or (S[ExePos + 4] = ' ') then begin
      Candidate := Copy(S, 1, ExePos + 3);
      if IsAbsoluteWindowsPath(Candidate) then begin
        Result := Candidate;
        exit;
      end;
    end;
  end;

  FirstSpace := Pos(' ', S);
  if FirstSpace > 0 then begin
    Candidate := Copy(S, 1, FirstSpace - 1);
  end else begin
    Candidate := S;
  end;

  if IsAbsoluteWindowsPath(Candidate) then begin
    Result := Candidate;
  end;
end;

procedure RemoveStaleUninstallEntry(const RootKey: Integer; const RootName: String);
var
  UninstallString: String;
  UninstallExePath: String;
begin
  if not RegQueryStringValue(RootKey, UninstallRegSubKey, 'UninstallString', UninstallString) then begin
    exit;
  end;

  UninstallExePath := ExtractExecutablePath(UninstallString);
  if (UninstallExePath = '') or FileExists(UninstallExePath) then begin
    exit;
  end;

  Log(
    'Removing stale uninstall entry at root=' + RootName +
    ' key=' + UninstallRegSubKey +
    ' (missing uninstaller: ' + UninstallExePath + ')'
  );
  if not RegDeleteKeyIncludingSubkeys(RootKey, UninstallRegSubKey) then begin
    Log('Failed to remove stale uninstall entry');
  end;
end;

function ExecSc(const Parameters: String; var ExitCode: Integer): Boolean;
begin
  Result := Exec(
    ExpandConstant('{sys}\sc.exe'),
    Parameters,
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ExitCode
  );
  if Result then begin
    Log('sc.exe ' + Parameters + ' (exit=' + IntToStr(ExitCode) + ')');
  end else begin
    Log('failed to launch sc.exe ' + Parameters);
  end;
end;

function ExecCmd(const Parameters: String; var ExitCode: Integer): Boolean;
begin
  Result := Exec(
    ExpandConstant('{sys}\cmd.exe'),
    Parameters,
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ExitCode
  );
  if Result then begin
    Log('cmd.exe ' + Parameters + ' (exit=' + IntToStr(ExitCode) + ')');
  end else begin
    Log('failed to launch cmd.exe ' + Parameters);
  end;
end;

procedure TryKillProcessImage(const ImageName: String);
var
  ExitCode: Integer;
begin
  if not ExecCmd('/C taskkill /F /T /IM "' + ImageName + '" >NUL 2>&1', ExitCode) then begin
    Log('failed to launch taskkill for ' + ImageName);
    exit;
  end;
  Log('taskkill image "' + ImageName + '" exit=' + IntToStr(ExitCode));
end;

procedure StopLanternProcesses;
begin
  Log('Stopping old Lantern UI/service processes');
  TryKillProcessImage('{#UiExeName}');
  TryKillProcessImage('{#SvcExeName}');
end;

function LegacyUserInstallDir: String;
begin
  Result := ExpandConstant('{localappdata}\Programs\{#SetupSetting("AppName")}');
end;

function PathStartsWith(const Path: String; const Prefix: String): Boolean;
var
  NormalizedPath: String;
  NormalizedPrefix: String;
begin
  NormalizedPath := LowerCase(RemoveBackslashUnlessRoot(Trim(Path)));
  NormalizedPrefix := LowerCase(RemoveBackslashUnlessRoot(Trim(Prefix)));
  if (NormalizedPath = '') or (NormalizedPrefix = '') then begin
    Result := False;
    exit;
  end;

  if NormalizedPath = NormalizedPrefix then begin
    Result := True;
    exit;
  end;

  Result :=
    (Length(NormalizedPath) > Length(NormalizedPrefix)) and
    (Copy(NormalizedPath, 1, Length(NormalizedPrefix)) = NormalizedPrefix) and
    (NormalizedPath[Length(NormalizedPrefix) + 1] = '\');
end;

procedure TryDeleteFileIfExists(const Path: String);
begin
  if not FileExists(Path) then begin
    exit;
  end;
  if DeleteFile(Path) then begin
    Log('Removed stale shortcut: ' + Path);
  end else begin
    Log('Failed to remove stale shortcut: ' + Path);
  end;
end;

procedure RemoveLegacyUserShortcuts;
begin
  TryDeleteFileIfExists(ExpandConstant('{userprograms}\{#SetupSetting("AppName")}.lnk'));
  TryDeleteFileIfExists(ExpandConstant('{userdesktop}\{#SetupSetting("AppName")}.lnk'));
  TryDeleteFileIfExists(
    ExpandConstant('{userappdata}\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\{#SetupSetting("AppName")}.lnk')
  );
  TryDeleteFileIfExists(
    ExpandConstant('{userappdata}\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\{#SetupSetting("AppName")}.lnk')
  );
end;

procedure RemoveLegacyUserUninstallEntryIfPresent(const UserInstallDir: String);
var
  UninstallString: String;
  UninstallExePath: String;
begin
  if not RegQueryStringValue(HKCU, UninstallRegSubKey, 'UninstallString', UninstallString) then begin
    exit;
  end;

  UninstallExePath := ExtractExecutablePath(UninstallString);
  if not PathStartsWith(UninstallExePath, UserInstallDir) then begin
    exit;
  end;

  Log('Removing legacy per-user uninstall entry: ' + UninstallRegSubKey);
  if not RegDeleteKeyIncludingSubkeys(HKCU, UninstallRegSubKey) then begin
    Log('Failed to remove legacy per-user uninstall entry');
  end;
end;

procedure RemoveLegacyUserInstallIfPresent;
var
  UserInstallDir: String;
begin
  UserInstallDir := LegacyUserInstallDir;
  if not DirExists(UserInstallDir) then begin
    exit;
  end;

  Log('Removing legacy per-user Lantern install: ' + UserInstallDir);
  RemoveLegacyUserUninstallEntryIfPresent(UserInstallDir);
  RemoveLegacyUserShortcuts;

  if DelTree(UserInstallDir, True, True, True) then begin
    Log('Removed legacy per-user Lantern install');
  end else begin
    Log('Failed to fully remove legacy per-user Lantern install');
  end;
end;

procedure FailInstall(const Message: String);
begin
  Log('Installation failed: ' + Message);
  RaiseException(Message);
end;

procedure StopAndDeleteService;
var
  ExitCode: Integer;
begin
  ExitCode := -1;
  if not ExecSc('stop "{#SvcName}"', ExitCode) then begin
    Log('Unable to run sc stop for {#SvcName}; continuing cleanup');
  end;
  if ExitCode = 0 then begin
    if not WaitForServiceStopped(ServiceStopTimeoutMs) then begin
      Log('{#SvcName} did not report STOPPED in time; forcing process termination');
      TryKillProcessImage('{#SvcExeName}');
    end;
  end else if ExitCode = ServiceNotRunningExitCode then begin
    Log('{#SvcName} already stopped');
  end else if ExitCode = ServiceDoesNotExistExitCode then begin
    Log('{#SvcName} does not exist');
  end else begin
    Log('sc stop returned exit ' + IntToStr(ExitCode) + '; forcing process termination');
    TryKillProcessImage('{#SvcExeName}');
    if not WaitForServiceStopped(ServiceStopTimeoutMs) then begin
      Log('{#SvcName} did not report STOPPED in time after forced termination');
    end;
  end;

  ExecSc('delete "{#SvcName}"', ExitCode);
end;

function WaitForServiceDelete(const TimeoutMs: Integer): Boolean;
var
  ExitCode: Integer;
  ElapsedMs: Integer;
begin
  ElapsedMs := 0;
  while ElapsedMs <= TimeoutMs do begin
    if ExecSc('query "{#SvcName}"', ExitCode) then begin
      // SERVICE_DOES_NOT_EXIST
      if ExitCode = ServiceDoesNotExistExitCode then begin
        Result := True;
        exit;
      end;
    end;
    Sleep(ServicePollIntervalMs);
    ElapsedMs := ElapsedMs + ServicePollIntervalMs;
  end;
  Result := False;
end;

function IsServiceState(const StateCode: String; const StateName: String): Boolean;
var
  ExitCode: Integer;
begin
  Result := ExecCmd(
    '/C sc.exe query {#SvcName} | findstr /R /C:"STATE *: *' +
      StateCode + ' *' + StateName + '" >NUL',
    ExitCode
  ) and (ExitCode = 0);
end;

function IsServiceRunning: Boolean;
begin
  Result := IsServiceState('4', 'RUNNING');
end;

function IsServiceStopped: Boolean;
begin
  Result := IsServiceState('1', 'STOPPED');
end;

function WaitForServiceRunning(const TimeoutMs: Integer): Boolean;
var
  ElapsedMs: Integer;
begin
  ElapsedMs := 0;
  while ElapsedMs <= TimeoutMs do begin
    if IsServiceRunning then begin
      Result := True;
      exit;
    end;
    Sleep(ServicePollIntervalMs);
    ElapsedMs := ElapsedMs + ServicePollIntervalMs;
  end;
  Result := False;
end;

function WaitForServiceStopped(const TimeoutMs: Integer): Boolean;
var
  ElapsedMs: Integer;
begin
  ElapsedMs := 0;
  while ElapsedMs <= TimeoutMs do begin
    if IsServiceStopped then begin
      Result := True;
      exit;
    end;
    Sleep(ServicePollIntervalMs);
    ElapsedMs := ElapsedMs + ServicePollIntervalMs;
  end;
  Result := False;
end;

function HasNonEmptyTokenFile: Boolean;
var
  TokenValue: AnsiString;
  TokenFilePath: String;
begin
  TokenFilePath := ExpandConstant('{#TokenFile}');
  Result := False;
  if not FileExists(TokenFilePath) then begin
    exit;
  end;
  if not LoadStringFromFile(TokenFilePath, TokenValue) then begin
    exit;
  end;
  Result := Trim(String(TokenValue)) <> '';
end;

function WaitForTokenFile(const TimeoutMs: Integer): Boolean;
var
  ElapsedMs: Integer;
begin
  ElapsedMs := 0;
  while ElapsedMs <= TimeoutMs do begin
    if HasNonEmptyTokenFile then begin
      Result := True;
      exit;
    end;
    Sleep(ServicePollIntervalMs);
    ElapsedMs := ElapsedMs + ServicePollIntervalMs;
  end;
  Result := False;
end;

function ServiceExecutablePath(_Param: String): String;
var
  Arm64ServicePath: String;
begin
  Arm64ServicePath := ExpandConstant('{app}\arm64\lanternsvc.exe');
  if IsArm64 and FileExists(Arm64ServicePath) then
    Result := Arm64ServicePath
  else
    Result := ExpandConstant('{app}\lanternsvc.exe');
end;

procedure CreateOrUpdateService(const ServicePath: String);
var
  ExitCode: Integer;
  CreateParams: String;
  ConfigParams: String;
begin
  CreateParams :=
    'create "{#SvcName}" binPath= "' + ServicePath +
    '" start= delayed-auto DisplayName= "{#SvcDisplayName}"';
  if not ExecSc(CreateParams, ExitCode) then begin
    FailInstall('Unable to run sc create for {#SvcName}.');
  end;

  if ExitCode = 0 then begin
    Log('Windows service {#SvcName} created');
    exit;
  end;

  if ExitCode = 5 then begin
    FailInstall(
      'Administrator privileges are required to install {#SvcName}. ' +
      'Please re-run the installer as administrator.'
    );
  end;

  if ExitCode <> ServiceExistsExitCode then begin
    FailInstall(
      'sc create returned exit ' + IntToStr(ExitCode) +
      ' while configuring {#SvcName}.'
    );
  end;

  Log('Windows service {#SvcName} already exists, applying updated config');
  ConfigParams :=
    'config "{#SvcName}" binPath= "' + ServicePath +
    '" start= delayed-auto DisplayName= "{#SvcDisplayName}"';
  if not ExecSc(ConfigParams, ExitCode) then begin
    FailInstall('Unable to run sc config for {#SvcName}.');
  end;
  if ExitCode <> 0 then begin
    FailInstall('sc config returned exit ' + IntToStr(ExitCode) + '.');
  end;
end;

procedure ConfigureServiceRecovery;
var
  ExitCode: Integer;
begin
  if not ExecSc('failure "{#SvcName}" reset= 60 actions= restart/5000/restart/5000/""""/5000', ExitCode) then begin
    FailInstall('Unable to configure service recovery settings.');
  end;
  if ExitCode <> 0 then begin
    FailInstall('Failed to configure service recovery (exit=' + IntToStr(ExitCode) + ').');
  end;
  if not ExecSc('failureflag "{#SvcName}" 1', ExitCode) then begin
    FailInstall('Unable to set service failure flag.');
  end;
  if ExitCode <> 0 then begin
    FailInstall('Failed to set service failure flag (exit=' + IntToStr(ExitCode) + ').');
  end;
  if not ExecSc('description "{#SvcName}" "Lantern Windows service"', ExitCode) then begin
    FailInstall('Unable to set service description.');
  end;
  if ExitCode <> 0 then begin
    FailInstall('Failed to set service description (exit=' + IntToStr(ExitCode) + ').');
  end;
end;

procedure StartServiceAndValidate;
var
  ExitCode: Integer;
begin
  if FileExists(ExpandConstant('{#TokenFile}')) then begin
    if DeleteFile(ExpandConstant('{#TokenFile}')) then
      Log('Deleted stale token file before service start')
    else
      Log('Failed to delete stale token file before service start');
  end;

  if not ExecSc('query "{#SvcName}"', ExitCode) then begin
    FailInstall('Unable to query {#SvcName} after install.');
  end;
  if ExitCode <> 0 then begin
    FailInstall('Service {#SvcName} was not created (sc query exit=' + IntToStr(ExitCode) + ').');
  end;

  if not ExecSc('stop "{#SvcName}"', ExitCode) then begin
    FailInstall('Unable to stop {#SvcName} before restart.');
  end;
  if (ExitCode <> 0) and (ExitCode <> ServiceNotRunningExitCode) then begin
    FailInstall('sc stop returned exit ' + IntToStr(ExitCode) + ' for {#SvcName}.');
  end;
  if not WaitForServiceStopped(ServiceStopTimeoutMs) then begin
    FailInstall('{#SvcName} did not stop before restart.');
  end;

  if not ExecSc('start "{#SvcName}"', ExitCode) then begin
    FailInstall('Unable to start {#SvcName}.');
  end;
  if (ExitCode <> 0) and (ExitCode <> ServiceAlreadyRunningExitCode) then begin
    FailInstall('sc start returned exit ' + IntToStr(ExitCode) + ' for {#SvcName}.');
  end;

  if not WaitForServiceRunning(ServiceStartTimeoutMs) then begin
    FailInstall('{#SvcName} did not reach Running state after install.');
  end;
  if not WaitForTokenFile(TokenReadyTimeoutMs) then begin
    FailInstall('IPC token file missing or empty at {#TokenFile}.');
  end;
end;

procedure ProvisionWindowsService;
var
  ServicePath: String;
begin
  ServicePath := ServiceExecutablePath('');
  if (ServicePath = '') or (not FileExists(ServicePath)) then begin
    FailInstall('Service executable not found at ' + ServicePath + '.');
  end;

  Log('Provisioning Windows service from ' + ServicePath);
  CreateOrUpdateService(ServicePath);
  ConfigureServiceRecovery;
  StartServiceAndValidate;
end;

procedure PreInstallLanternCleanup;
begin
  if PreInstallCleanupDone then begin
    Log('PrepareToInstall cleanup already completed');
    exit;
  end;

  Log('PrepareToInstall cleanup started');
  StopLanternProcesses;
  RemoveLegacyUserInstallIfPresent;
  StopAndDeleteService;
  if not WaitForServiceDelete(ServiceDeleteTimeoutMs) then begin
    FailInstall('{#SvcName} could not be removed before install.');
  end;
  PreInstallCleanupDone := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then begin
    Log('Pre-install service cleanup started');
    PreInstallLanternCleanup;
    exit;
  end;

  if CurStep = ssPostInstall then begin
    Log('Post-install service validation started');
    ProvisionWindowsService;
  end;
end;

function InitializeSetup: Boolean;
begin
  RemoveStaleUninstallEntry(HKLM, 'HKLM');
  RemoveStaleUninstallEntry(HKCU, 'HKCU');

  Dependency_AddWebView2;
  Dependency_AddVC2015To2022;
  Result := True;
end;
