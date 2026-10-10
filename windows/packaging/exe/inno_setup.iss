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
  LegacyMigration: Boolean;

function ValidateInstallTarget: String; forward;

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
  // Validate before downloading/installing prerequisites or closing applications.
  Result := ValidateInstallTarget;
  if Result <> '' then exit;
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
              case SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbError, MB_RETRYCANCEL, IDCANCEL) of
                IDCANCEL: begin
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

          case SuppressibleMsgBox(FmtMessage(SetupMessage(msgErrorFunctionFailed), [Dependency_List[DependencyIndex].Title, IntToStr(ResultCode)]), mbError, MB_RETRYCANCEL, IDCANCEL) of
            IDCANCEL: begin
              Result := Dependency_List[DependencyIndex].Title;
              break;
            end;
          end;
        end;

        if Result <> '' then begin
          break;
        end;
      end;

      // A migration must be resumed by the original user's bridge, retaining its
      // source path and identity. Do not schedule an elevated, context-free retry.
      if NeedsRestart and not LegacyMigration then begin
        TempValue := '"' + ExpandConstant('{srcexe}') + '" /restart=1 /LANG="' + ExpandConstant('{language}') + '" /DIR="' + WizardDirValue + '" /GROUP="' + WizardGroupValue + '" /TYPE="' + WizardSetupType(False) + '" /COMPONENTS="' + WizardSelectedComponents(False) + '" /TASKS="' + WizardSelectedTasks(False) + '"';
        if WizardNoIcons then begin
          TempValue := TempValue + ' /NOICONS';
        end;
        RegWriteStringValue(HKA, 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', '{#SetupSetting("AppName")}', TempValue);
      end;
    end;

    Dependency_DownloadPage.Hide;
  end;
  if LegacyMigration and (NeedsRestart or Dependency_NeedToRestart) then begin
    NeedsRestart := True;
    Result := 'Restart Windows before retrying migration from the legacy Lantern app.';
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
#define ProgramDataDir   "{commonappdata}\Lantern"
#define DefaultInstallDir "{autopf}\{{DISPLAY_NAME}}"
// The pinned lanternd copies its service binary to this hard-coded directory.
// Keep migration fail-closed if Windows' Program Files location differs.
#define ServiceInstallDir "C:\Program Files\Lantern"

[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={#DefaultInstallDir}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupLogging=yes
SetupMutex=Global\LanternSetup-{{APP_ID}}
UninstallLogging=yes
CloseApplications=yes
RestartApplications=no
; v9 is a Flutter app; flutter_windows.dll links the system combined icu.dll,
; first shipped in Windows 10 1903 (build 18362). Gate here so pre-1903 / Win7
; users get a clear message instead of a cryptic "icu.dll missing" launch crash.
MinVersion=10.0.18362
; Multi-language installer: auto-detect from system UI locale, no picker dialog.
ShowLanguageDialog=no

[Languages]
{% for locale in LOCALES %}
{% if locale == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale == 'zh' %}Name: "chinesesimplified"; MessagesFile: "compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% if locale == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale == 'fa' %}Name: "farsi"; MessagesFile: "compiler:Languages\\Farsi.isl"{% endif %}
{% endfor %}

[Messages]
; Shown when MinVersion blocks install on pre-1903 Windows (no system icu.dll).
{% for locale in LOCALES %}
{% if locale == 'en' %}english.WindowsVersionNotSupported=Lantern requires Windows 10 version 1903 (May 2019) or later.%n%nYour version of Windows is no longer supported by this release.{% endif %}
{% if locale == 'zh' %}chinesesimplified.WindowsVersionNotSupported=Lantern 需要 Windows 10 1903 版本（2019 年 5 月）或更高版本。%n%n此版本不再支持您当前的 Windows 系统。{% endif %}
{% if locale == 'ja' %}japanese.WindowsVersionNotSupported=Lantern を実行するには Windows 10 バージョン 1903（2019年5月）以降が必要です。%n%nお使いの Windows はこのリリースではサポートされていません。{% endif %}
{% if locale == 'ru' %}russian.WindowsVersionNotSupported=Lantern требует Windows 10 версии 1903 (май 2019 г.) или новее.%n%nВаша версия Windows больше не поддерживается в этом выпуске.{% endif %}
{% if locale == 'fa' %}farsi.WindowsVersionNotSupported=Lantern به Windows 10 نسخه 1903 (مه ۲۰۱۹) یا جدیدتر نیاز دارد.%n%nنسخه ویندوز شما دیگر در این نسخه پشتیبانی نمی‌شود.{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}

[Dirs]
Name: "{#ProgramDataDir}"; Permissions: users-modify; Check: AllowSharedDataAccess
Name: "{#ProgramDataDir}"; Check: IsLegacyInstall

[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Check: IsOrdinaryInstall
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon; Check: IsOrdinaryInstall

[Run]
; Install LanternSvc service (creates Windows service, sets recovery actions, starts it)
; Migration checks the exit status and service state in InstallMigrationService.
Filename: "{code:LanterndExecutablePath}"; Parameters: "install"; Flags: runhidden; Check: IsOrdinaryInstall

; Launch Lantern app UI
Filename: "{app}\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; \
  Flags: runasoriginaluser nowait postinstall skipifsilent; Check: IsOrdinaryInstall

[UninstallRun]
Filename: "{code:LanterndExecutablePath}"; Parameters: "uninstall"; Flags: runhidden

; User/account data is intentionally retained when uninstalling the destination.
; In particular, uninstalling a failed migration must not erase recovery data.

[Code]
const
  ServiceDeleteTimeoutMs = 20000;
  ServicePollIntervalMs = 250;
  ServiceAbsent = 0;
  ServiceRunning = 4;
  DriveFixed = 3;
  SidTypeUser = 1;
  CstrEqual = 2;
  ErrorInsufficientBuffer = 122;
  UninstallRegSubKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1';

type
  TMigrationServiceStatus = record
    ServiceType, CurrentState, ControlsAccepted, Win32ExitCode,
      ServiceSpecificExitCode, CheckPoint, WaitHint: LongWord;
  end;

var
  LegacyDirectory, LegacySID, LegacyID, MigrationFailure: String;
  MigrationServiceReady: Boolean;

function MigrationGetFileAttributes(Path: String): LongWord;
  external 'GetFileAttributesW@kernel32.dll stdcall';
function MigrationGetDriveType(Root: String): LongWord;
  external 'GetDriveTypeW@kernel32.dll stdcall';
function MigrationStringToSID(Value: String; var SID: UINT_PTR): BOOL;
  external 'ConvertStringSidToSidW@advapi32.dll stdcall';
function MigrationSIDToString(SID: UINT_PTR; var Value: UINT_PTR): BOOL;
  external 'ConvertSidToStringSidW@advapi32.dll stdcall';
function MigrationCompareSID(Value: String; ValueLength: Integer; Canonical: UINT_PTR;
  CanonicalLength: Integer; IgnoreCase: BOOL): Integer;
  external 'CompareStringOrdinal@kernel32.dll stdcall';
function MigrationLookupAccountSID(SystemName, SID: UINT_PTR; Name: String;
  var NameLength: LongWord; Domain: String; var DomainLength, AccountType: LongWord): BOOL;
  external 'LookupAccountSidW@advapi32.dll stdcall';
function MigrationLocalFree(Memory: UINT_PTR): UINT_PTR;
  external 'LocalFree@kernel32.dll stdcall';
function MigrationOpenSCManager(MachineName, DatabaseName: Integer; Access: LongWord): LongWord;
  external 'OpenSCManagerW@advapi32.dll stdcall';
function MigrationOpenService(Manager: LongWord; Name: String; Access: LongWord): LongWord;
  external 'OpenServiceW@advapi32.dll stdcall';
function MigrationQueryServiceStatus(Service: LongWord; var Status: TMigrationServiceStatus): Boolean;
  external 'QueryServiceStatus@advapi32.dll stdcall';
function MigrationCloseServiceHandle(Handle: LongWord): Boolean;
  external 'CloseServiceHandle@advapi32.dll stdcall';

function IsOrdinaryInstall: Boolean;
begin
  Result := not LegacyMigration;
end;

function IsLegacyInstall: Boolean;
begin
  Result := LegacyMigration;
end;

function AllowSharedDataAccess: Boolean;
begin
  // Later ordinary upgrades must preserve migrated account storage permissions.
  Result := not LegacyMigration and
    not RegKeyExists(HKLM64, 'Software\Lantern\LegacyMigrationV1');
end;

function ValidLegacySID(const Value: String): Boolean;
var
  SID, CanonicalSID: UINT_PTR;
  Name, Domain: String;
  NameLength, DomainLength, AccountType: LongWord;
begin
  Result := False;
  if (Length(Value) < 9) or (Length(Value) > 184) or
    (Copy(Value, 1, 4) <> 'S-1-') then exit;
  if not MigrationStringToSID(Value, SID) then exit;
  try
    if not MigrationSIDToString(SID, CanonicalSID) then exit;
    try
      // Match the daemon's canonical SID check before prerequisites can run.
      if MigrationCompareSID(Value, Length(Value), CanonicalSID, -1, False) <> CstrEqual then exit;
    finally
      MigrationLocalFree(CanonicalSID);
    end;
    NameLength := 0;
    DomainLength := 0;
    MigrationLookupAccountSID(0, SID, '', NameLength, '', DomainLength, AccountType);
    if (DLLGetLastError <> ErrorInsufficientBuffer) or (NameLength = 0) then exit;
    SetLength(Name, NameLength);
    SetLength(Domain, DomainLength);
    // Resolve the original user, including domain users, not the UAC approver.
    if not MigrationLookupAccountSID(0, SID, Name, NameLength, Domain,
      DomainLength, AccountType) then exit;
    Result := AccountType = SidTypeUser;
  finally
    MigrationLocalFree(SID);
  end;
end;

function ValidLegacySourcePath(const Path: String): Boolean;
var
  Directory: String;
  I, ComponentStart: Integer;
begin
  Result := False;
  Directory := RemoveBackslashUnlessRoot(Path);
  if (Length(Directory) < 4) or (Directory[2] <> ':') or (Directory[3] <> '\') or
    not (((Directory[1] >= 'A') and (Directory[1] <= 'Z')) or
      ((Directory[1] >= 'a') and (Directory[1] <= 'z'))) then exit;
  // Check the supplied spelling before ExpandFileName can normalize it.
  Directory := AddBackslash(Directory);
  ComponentStart := 4;
  for I := 4 to Length(Directory) do begin
    if Directory[I] = '\' then begin
      if (I = ComponentStart) or (Directory[I - 1] = '.') or
        (Directory[I - 1] = ' ') then exit;
      ComponentStart := I + 1;
    end else if (Ord(Directory[I]) < 32) or
      (Pos(Directory[I], ':"<>|?*/') > 0) then exit;
  end;
  Result := MigrationGetDriveType(Copy(Directory, 1, 3)) = DriveFixed;
end;

function ValidLegacyID(const Value: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(Value) <> 32 then exit;
  for I := 1 to Length(Value) do
    if ((Value[I] < '0') or (Value[I] > '9')) and
      ((Value[I] < 'a') or (Value[I] > 'f')) then exit;
  Result := True;
end;

function IsAbsoluteWindowsPath(const Path: String): Boolean;
begin
  Result :=
    ((Length(Path) >= 3) and (Path[2] = ':') and (Path[3] = '\')) or
    ((Length(Path) >= 2) and (Copy(Path, 1, 2) = '\\'));
end;

function NormalizedDirectory(const Path: String): String;
var
  Existing, Parent, Suffix: String;
begin
  // Existing 8.3 aliases must compare equal to their long directory names.
  Existing := RemoveBackslashUnlessRoot(ExpandFileName(Path));
  Suffix := '';
  while not DirExists(Existing) do begin
    Parent := ExtractFileDir(Existing);
    if Parent = Existing then break;
    Suffix := '\' + ExtractFileName(Existing) + Suffix;
    Existing := Parent;
  end;
  Result := LowerCase(RemoveBackslashUnlessRoot(GetShortName(Existing)) + Suffix);
end;

function SameOrNestedDirectory(const Parent, Child: String): Boolean;
begin
  Result := Pos(AddBackslash(Parent), AddBackslash(Child)) = 1;
end;

function HasUnsafePathComponent(const Path: String): Boolean;
var
  Current, Parent: String;
  Attributes, ErrorCode: LongWord;
begin
  Result := True;
  Current := RemoveBackslashUnlessRoot(ExpandFileName(Path));
  while Current <> '' do begin
    Attributes := MigrationGetFileAttributes(Current);
    if Attributes = $FFFFFFFF then begin
      ErrorCode := DLLGetLastError;
      // An absent destination is expected. Access errors are not proof of safety.
      if (ErrorCode <> 2) and (ErrorCode <> 3) then exit;
    end else if (Attributes and $400) <> 0 then begin
      // Do not follow junctions/symlinks into an installation or user data tree.
      exit;
    end;
    Parent := ExtractFileDir(Current);
    if Parent = Current then break;
    Current := Parent;
  end;
  Result := False;
end;

function DirectoryHasEntries(const Path: String): Boolean;
var
  Entry: TFindRec;
begin
  Result := False;
  if FindFirst(AddBackslash(Path) + '*', Entry) then begin
    try
      repeat
        if (Entry.Name <> '.') and (Entry.Name <> '..') then begin
          Result := True;
          break;
        end;
      until not FindNext(Entry);
    finally
      FindClose(Entry);
    end;
  end else if DirExists(Path) then begin
    // Fail closed when an existing directory cannot be enumerated.
    Result := True;
  end;
end;

// -1 means unknown/error, 0 means absent; other values are SCM service states.
// Query the SCM directly: parsing localized sc.exe output is not reliable.
function GetServiceState: Integer;
var
  Manager, Service: LongWord;
  Status: TMigrationServiceStatus;
begin
  Result := -1;
  Manager := MigrationOpenSCManager(0, 0, 1);
  if Manager = 0 then exit;
  try
    Service := MigrationOpenService(Manager, '{#SvcName}', 4);
    if Service = 0 then begin
      if DLLGetLastError = 1060 then Result := ServiceAbsent;
      exit;
    end;
    try
      if MigrationQueryServiceStatus(Service, Status) then
        Result := Status.CurrentState;
    finally
      MigrationCloseServiceHandle(Service);
    end;
  finally
    MigrationCloseServiceHandle(Manager);
  end;
end;

function ValidateInstallTarget: String;
var
  Target, Source, DefaultTarget, DataDirectory: String;
  VersionMS, VersionLS: Cardinal;
begin
  Result := '';
  Target := ExpandConstant('{app}');

  // Manual installs must also preserve legacy settings and executables.
  if FileExists(AddBackslash(Target) + 'settings.yaml') then begin
    Result := 'Choose a separate installation folder. This folder contains legacy Lantern settings.';
    exit;
  end;
  if FileExists(AddBackslash(Target) + '{{EXECUTABLE_NAME}}') then begin
    if not GetVersionNumbers(AddBackslash(Target) + '{{EXECUTABLE_NAME}}', VersionMS, VersionLS) then begin
      Result := 'Cannot verify the existing Lantern installation. Choose a separate installation folder.';
      exit;
    end;
    if (VersionMS shr 16) < 9 then begin
      Result := 'The legacy Lantern installation must be kept for recovery. Choose a separate installation folder.';
      exit;
    end;
  end;

  if not LegacyMigration then exit;
  if not ValidLegacySourcePath(LegacyDirectory) then begin
    Result := 'Legacy migration requires an unambiguous installation folder on a fixed local drive.';
    exit;
  end;
  DefaultTarget := ExpandConstant('{#DefaultInstallDir}');
  DataDirectory := ExpandConstant('{#ProgramDataDir}');
  if CompareText(ExpandFileName(DefaultTarget), ExpandFileName('{#ServiceInstallDir}')) <> 0 then begin
    Result := 'Legacy migration is not supported with this Windows Program Files location.';
    exit;
  end;
  if CompareText(ExpandFileName(Target), ExpandFileName(DefaultTarget)) <> 0 then begin
    Result := 'Legacy migration requires the default Lantern installation folder.';
    exit;
  end;
  if HasUnsafePathComponent(Target) or HasUnsafePathComponent(LegacyDirectory) or
    HasUnsafePathComponent(DataDirectory) then begin
    Result := 'Legacy migration cannot use inaccessible folders, junctions, or symbolic links.';
    exit;
  end;
  Source := NormalizedDirectory(LegacyDirectory);
  Target := NormalizedDirectory(Target);
  DataDirectory := NormalizedDirectory(DataDirectory);
  if SameOrNestedDirectory(Source, Target) or SameOrNestedDirectory(Target, Source) or
    SameOrNestedDirectory(Source, DataDirectory) or SameOrNestedDirectory(DataDirectory, Source) then begin
    Result := 'The new installation and service data folders must be separate from legacy Lantern.';
    exit;
  end;
  if not FileExists(AddBackslash(LegacyDirectory) + 'lantern.exe') then begin
    Result := 'The legacy Lantern executable is missing. Restart migration from the legacy app.';
    exit;
  end;
  if FileExists(ExpandConstant('{app}')) or DirectoryHasEntries(ExpandConstant('{app}')) then begin
    Result := 'The destination already contains files. Repair or remove only the new Lantern installation before retrying; keep the legacy app and its settings.';
    exit;
  end;
  if FileExists(ExpandConstant('{#ProgramDataDir}')) or
    DirectoryHasEntries(ExpandConstant('{#ProgramDataDir}')) then begin
    Result := 'The new service data folder already contains data. Review the existing installation before migrating; do not delete account or settings data.';
    exit;
  end;
  if GetServiceState <> ServiceAbsent then begin
    Result := 'A Lantern service already exists or could not be checked. Repair the new installation before retrying migration.';
    exit;
  end;
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

procedure StopAndDeleteService;
var
  ExitCode: Integer;
begin
  ExecSc('stop "{#SvcName}"', ExitCode);
  ExecSc('delete "{#SvcName}"', ExitCode);
end;

function WaitForServiceState(const State, TimeoutMs: Integer): Boolean;
var
  ElapsedMs: Integer;
begin
  ElapsedMs := 0;
  while ElapsedMs <= TimeoutMs do begin
    if GetServiceState = State then begin
      Result := True;
      exit;
    end;
    Sleep(ServicePollIntervalMs);
    ElapsedMs := ElapsedMs + ServicePollIntervalMs;
  end;
  Result := False;
end;

function LanterndExecutablePath(_Param: String): String;
var
  Arm64Path: String;
begin
  Arm64Path := ExpandConstant('{app}\arm64\lanternd.exe');
  if IsArm64 and FileExists(Arm64Path) then
    Result := Arm64Path
  else
    Result := ExpandConstant('{app}\lanternd.exe');
end;

procedure InstallMigrationService;
var
  ExitCode: Integer;
begin
  MigrationFailure := 'Lantern could not start its new service. Your legacy app, account, and settings have been kept. Return to the legacy app; repair the new installation before retrying.';
  // This route never removes or reconfigures a service that predated migration.
  if GetServiceState <> ServiceAbsent then exit;
  // Bind enrollment to the original user before the LocalSystem service starts.
  // The daemon validates the SID and protects enrollment and account storage.
  if not Exec(LanterndExecutablePath(''),
    'prepare-legacy-migration --sid "' + LegacySID + '" --source "' +
    RemoveBackslashUnlessRoot(LegacyDirectory) + '" --migration-id "' + LegacyID + '"',
    '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then begin
    MigrationFailure := 'Lantern could not prepare identity transfer. Your legacy app and settings have been kept.';
    exit;
  end;
  if ExitCode <> 0 then begin
    MigrationFailure := 'Lantern could not authorize identity transfer. Your legacy app and settings have been kept.';
    Log('Migration enrollment failed: ' + IntToStr(ExitCode));
    exit;
  end;
  try
    if not Exec(LanterndExecutablePath(''), 'install', '', SW_HIDE,
      ewWaitUntilTerminated, ExitCode) then begin
      Log('Migration service install could not be launched');
      exit;
    end;
    if ExitCode <> 0 then begin
      Log('Migration service install failed: ' + IntToStr(ExitCode));
      exit;
    end;
    if WaitForServiceState(ServiceRunning, ServiceDeleteTimeoutMs) then begin
      MigrationServiceReady := True;
      MigrationFailure := '';
      Log('Migration destination installed; service is waiting for authenticated identity handoff.');
    end else begin
      Log('Migration service did not reach RUNNING');
    end;
  finally
    if not MigrationServiceReady then begin
      StopAndDeleteService;
      if not WaitForServiceState(ServiceAbsent, ServiceDeleteTimeoutMs) then
        Log('Migration service cleanup incomplete; legacy installation is still intact');
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ValidationError: String;
begin
  if CurStep = ssInstall then begin
    // Recheck after prerequisites and immediately before destination writes.
    ValidationError := ValidateInstallTarget;
    if ValidationError <> '' then RaiseException(ValidationError);
    if not LegacyMigration then begin
      Log('Pre-install service cleanup started');
      StopAndDeleteService;
      if not WaitForServiceState(ServiceAbsent, ServiceDeleteTimeoutMs) then
        RaiseException('The Lantern service could not be removed. Restart Windows and retry the installation.');
    end;
  end else if (CurStep = ssPostInstall) and LegacyMigration then begin
    // Inno has committed its files; GetCustomSetupExitCode reports service failure.
    InstallMigrationService;
    if MigrationFailure <> '' then begin
      Log(MigrationFailure);
      SuppressibleMsgBox(MigrationFailure, mbError, MB_OK, IDOK);
    end;
  end else if (CurStep = ssDone) and not LegacyMigration then begin
    // Cancelling before install must not modify existing registration.
    RemoveStaleUninstallEntry(HKLM, 'HKLM');
    RemoveStaleUninstallEntry(HKCU, 'HKCU');
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and (MigrationFailure <> '') then
    WizardForm.FinishedLabel.Caption := MigrationFailure;
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := 0;
  if LegacyMigration and not MigrationServiceReady then Result := 1;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Locator, Services, Processes, Process: Variant;
  Index: Integer;
  InstalledPath: String;
begin
  if CurUninstallStep <> usUninstall then exit;
  // A process-name-wide taskkill would also terminate the retained legacy app.
  InstalledPath := ExpandConstant('{app}\{{EXECUTABLE_NAME}}');
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Services := Locator.ConnectServer('', 'root\CIMV2');
    Processes := Services.ExecQuery('SELECT * FROM Win32_Process WHERE Name = ''{{EXECUTABLE_NAME}}''');
    for Index := 0 to Processes.Count - 1 do begin
      Process := Processes.ItemIndex(Index);
      if not VarIsNull(Process.ExecutablePath) then begin
        if CompareText(Process.ExecutablePath, InstalledPath) = 0 then
          Process.Terminate();
      end;
    end;
  except
    Log('Could not stop the installed Lantern process: ' + GetExceptionMessage);
  end;
end;

function InitializeSetup: Boolean;
var
  Mode, ErrorMessage: String;
begin
  Result := False;
  Mode := ExpandConstant('{param:LEGACYMIGRATION|0}');
  LegacyMigration := Mode = '1';
  LegacyDirectory := ExpandConstant('{param:LEGACYDIR|}');
  LegacySID := ExpandConstant('{param:LEGACYSID|}');
  LegacyID := ExpandConstant('{param:LEGACYID|}');
  ErrorMessage := '';
  if (Mode <> '0') and (Mode <> '1') then
    ErrorMessage := 'Unsupported legacy migration contract.'
  else if not LegacyMigration and ((LegacyDirectory <> '') or (LegacySID <> '') or (LegacyID <> '')) then
    ErrorMessage := 'Legacy handoff arguments require LEGACYMIGRATION=1.'
  else if LegacyMigration then begin
    if ProcessorArchitecture <> paX64 then
      ErrorMessage := 'Legacy migration requires native x64 Windows 10 version 1903 or later.'
    else if not ValidLegacySID(LegacySID) or not ValidLegacyID(LegacyID) then
      ErrorMessage := 'Restart migration from the legacy app to authorize identity transfer.'
    else if not ValidLegacySourcePath(LegacyDirectory) then
      ErrorMessage := 'Restart migration from the legacy app with its installation folder on a fixed local drive.'
    else if HasUnsafePathComponent(LegacyDirectory) or
      not FileExists(AddBackslash(LegacyDirectory) + 'lantern.exe') then
      ErrorMessage := 'The legacy Lantern installation could not be verified. It has not been changed.';
  end;
  if ErrorMessage <> '' then begin
    Log(ErrorMessage);
    SuppressibleMsgBox(ErrorMessage, mbError, MB_OK, IDOK);
    exit;
  end;

  Dependency_AddWebView2;
  Dependency_AddVC2015To2022;
  Result := True;
end;
