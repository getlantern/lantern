; Tests execute the actual production functions, substituting only OS inputs
; and dependency execution. No registry writes or runtime installation occurs.
#define VCRedistVersion "14.99.12345.0"

[Setup]
AppName=Lantern installer prerequisite tests
AppVersion=0.0.0
DefaultDirName={tmp}\LanternInstallerTests
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
OutputDir=.
OutputBaseFilename=windows-installer-test

[Code]
var
  FixtureArm64, FixtureRedirection, FixtureFailToStart: Boolean;
  FixtureRoot: Integer;
  FixtureKey, FixtureVersion: String;
  FixtureInstalled: Cardinal;
  FixtureHasInstalled, FixtureHasVersion: Boolean;
  FixtureMsvcp, FixtureVcruntime, FixtureVcruntime1: String;
  FixtureExitCodes: array[1..2] of Integer;
  FixtureAfterVersions: array[1..2] of String;
  FixtureRepairFiles: array[1..2] of Boolean;
  ExecutedCount, ExtractedCount, TestCount: Integer;
  ExecutedOperations: String;
  Dependency_VCRuntimeEnabled: Boolean;
  Dependency_Memo: String;

procedure Assert(const Condition: Boolean; const Message: String);
begin
  if not Condition then RaiseException(Message);
end;

function Fixture_IsArm64: Boolean;
begin
  Result := FixtureArm64;
end;

function Fixture_RegQueryDWordValue(const RootKey: Integer; const SubKeyName, ValueName: String; var ResultDWord: Cardinal): Boolean;
begin
  Result := FixtureHasInstalled and (RootKey = FixtureRoot) and
    (SubKeyName = FixtureKey) and (ValueName = 'Installed');
  if Result then ResultDWord := FixtureInstalled;
end;

function Fixture_RegQueryStringValue(const RootKey: Integer; const SubKeyName, ValueName: String; var ResultString: String): Boolean;
begin
  Result := FixtureHasVersion and (RootKey = FixtureRoot) and
    (SubKeyName = FixtureKey) and (ValueName = 'Version');
  if Result then ResultString := FixtureVersion;
end;

procedure Fixture_Log(const Message: String);
begin
  Log(Message);
end;

function Fixture_ExpandConstant(const Value: String): String;
begin
  if Value = '{log}' then Result := 'C:\Test Logs\Lantern Setup.log'
  else if Value = '{sys}\' then Result := 'C:\Windows\System32\'
  else if Value = '{tmp}\VC_redist.x64.exe' then Result := 'C:\Temp Fixture\VC_redist.x64.exe'
  else RaiseException('Unexpected constant: ' + Value);
end;

function Fixture_EnableFsRedirection(const Enable: Boolean): Boolean;
begin
  Result := FixtureRedirection;
  FixtureRedirection := Enable;
end;

function Fixture_GetVersionNumbersString(const Filename: String; var Version: String): Boolean;
begin
  Assert(not FixtureRedirection, 'Must inspect native DLLs, not redirected SysWOW64');
  if Filename = 'C:\Windows\System32\msvcp140.dll' then Version := FixtureMsvcp
  else if Filename = 'C:\Windows\System32\vcruntime140.dll' then Version := FixtureVcruntime
  else if Filename = 'C:\Windows\System32\vcruntime140_1.dll' then Version := FixtureVcruntime1
  else RaiseException('Unexpected DLL: ' + Filename);
  Result := Version <> '';
end;

procedure Fixture_ExtractTemporaryFile(const Filename: String);
begin
  Assert(Filename = 'VC_redist.x64.exe', 'Wrong embedded redistributable');
  ExtractedCount := ExtractedCount + 1;
end;

procedure SetFiles(const Version: String);
begin
  FixtureMsvcp := Version;
  FixtureVcruntime := Version;
  FixtureVcruntime1 := Version;
end;

procedure SetRuntime(const RootKey: Integer; const Arch: String; const Installed: Cardinal; const Version: String);
begin
  FixtureRoot := RootKey;
  FixtureKey := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\' + Arch;
  FixtureInstalled := Installed;
  FixtureVersion := Version;
  FixtureHasInstalled := True;
  FixtureHasVersion := True;
end;

function Fixture_ShellExec(const Verb, Filename, Parameters, WorkingDir: String; const ShowCmd: Integer; const Wait: TExecWait; var ResultCode: Integer): Boolean;
var
  Operation, Arch: String;
begin
  ExecutedCount := ExecutedCount + 1;
  Assert(ExecutedCount <= 2, 'Unbounded redistributable retry');
  Assert(Filename = 'C:\Temp Fixture\VC_redist.x64.exe', 'Must execute the embedded runtime');
  Operation := Copy(Parameters, 1, Pos(' ', Parameters) - 1);
  Assert((Operation = '/install') or (Operation = '/repair'), 'Unexpected operation');
  Assert(Parameters = Operation + ' /passive /norestart /log "C:\Test Logs\Lantern Setup-vcredist.log"', 'Wrong or unquoted runtime parameters');
  Assert((Verb = '') and (WorkingDir = '') and (Wait = ewWaitUntilTerminated), 'Wait for dependency completion');
  ExecutedOperations := ExecutedOperations + Operation + ';';
  Result := not FixtureFailToStart;
  ResultCode := FixtureExitCodes[ExecutedCount];
  if Result then begin
    if FixtureArm64 then Arch := 'arm64' else Arch := 'x64';
    if FixtureAfterVersions[ExecutedCount] <> '' then
      SetRuntime(HKLM64, Arch, 1, FixtureAfterVersions[ExecutedCount]);
    if FixtureRepairFiles[ExecutedCount] then SetFiles('{#VCRedistVersion}');
  end;
end;

#include "dependency-under-test.iss"

procedure SetMachine(const Arm64: Boolean);
var
  Index: Integer;
begin
  FixtureArm64 := Arm64;
  FixtureHasInstalled := False;
  FixtureHasVersion := False;
  FixtureRedirection := True;
  FixtureFailToStart := False;
  SetFiles('{#VCRedistVersion}');
  for Index := 1 to 2 do begin
    FixtureExitCodes[Index] := 0;
    FixtureAfterVersions[Index] := '{#VCRedistVersion}';
    FixtureRepairFiles[Index] := True;
  end;
end;

procedure ResetExecution;
begin
  ExecutedCount := 0;
  ExtractedCount := 0;
  ExecutedOperations := '';
  Dependency_Memo := '';
end;

procedure Check(const Name, ExpectedOperations: String);
var
  Error: String;
  NeedsRestart: Boolean;
begin
  Log('TEST: ' + Name);
  ResetExecution;
  Dependency_AddVCRuntime;
  NeedsRestart := False;
  Error := Dependency_EnsureVCRuntime(NeedsRestart);
  Assert(Error = '', Name + ': ' + Error);
  Assert(not NeedsRestart, Name + ': unexpected reboot');
  Assert(ExecutedOperations = ExpectedOperations, Name + ': wrong operation sequence');
  if ExpectedOperations <> '' then begin
    Assert(ExtractedCount = 1, Name + ': expected one extraction');
  end else begin
    Assert(ExecutedCount = 0, Name + ': sufficient runtime must be skipped');
    Assert(ExtractedCount = 0, Name + ': sufficient runtime needs no extraction');
  end;
  Assert(FixtureRedirection, Name + ': redirection must be restored');
  TestCount := TestCount + 1;
end;

procedure CheckFailure(const Name, ExpectedFragment: String; const ExpectedExecutions: Integer; const ExpectedRestart: Boolean);
var
  Error: String;
  NeedsRestart: Boolean;
begin
  Log('TEST: ' + Name);
  ResetExecution;
  Dependency_AddVCRuntime;
  NeedsRestart := False;
  Error := Dependency_EnsureVCRuntime(NeedsRestart);
  Assert(Pos(ExpectedFragment, Error) > 0, Name + ': unexpected error: ' + Error);
  Assert(ExecutedCount = ExpectedExecutions, Name + ': wrong execution count');
  Assert(NeedsRestart = ExpectedRestart, Name + ': wrong reboot state');
  Assert(FixtureRedirection, Name + ': redirection must be restored');
  TestCount := TestCount + 1;
end;

procedure RunTests;
begin
  SetMachine(True);
  Check('Clean ARM64 uses embedded x64 bundle', '/install;');
  // On ARM64, the x64 bundle installs ARM64X runtime DLLs for both ARM64 and x64 apps.
  SetRuntime(HKLM64, 'arm64', 1, 'v14.99.12345.0');
  Check('Minimum ARM64X runtime serves x64 UI without x64 key', '');
  SetRuntime(HKLM64, 'arm64', 1, 'V14.100.35719.0');
  Check('Newer ARM64 runtime with uppercase prefix', '');
  SetRuntime(HKLM64, 'arm64', 1, '14.99.12345.1');
  Check('Newer fourth component without prefix', '');
  SetRuntime(HKLM64, 'x64', 1, 'v14.100.35719.0');
  Check('x64 key alone cannot satisfy ARM64X runtime detection', '/install;');
  SetRuntime(HKLM32, 'arm64', 1, 'v14.100.35719.0');
  Check('Wrong registry view cannot satisfy ARM64', '/install;');
  SetRuntime(HKLM64, 'arm64', 1, 'v14.99.12344.0');
  Check('ARM64 runtime below minimum', '/install;');
  SetRuntime(HKLM64, 'arm64', 1, 'v14.9.12345.0');
  Check('Version comparison is numeric', '/install;');
  SetRuntime(HKLM64, 'arm64', 1, 'vnot-a-version');
  Check('Malformed runtime version', '/install;');
  SetRuntime(HKLM64, 'arm64', 1, '');
  Check('Empty runtime version', '/install;');
  SetRuntime(HKLM64, 'arm64', 0, 'v14.100.35719.0');
  Check('Installed flag is zero', '/install;');
  SetRuntime(HKLM64, 'arm64', 2, 'v14.100.35719.0');
  Check('Installed flag must equal one', '/install;');
  SetRuntime(HKLM64, 'arm64', 1, 'v14.100.35719.0');
  FixtureHasInstalled := False;
  Check('Installed flag is missing', '/install;');
  FixtureHasInstalled := True;
  FixtureHasVersion := False;
  Check('Version value is missing', '/install;');

  SetMachine(False);
  Check('Clean x64 uses embedded x64 bundle', '/install;');
  SetRuntime(HKLM64, 'x64', 1, '14.99.12345.0');
  Check('Minimum x64 runtime', '');
  SetRuntime(HKLM64, 'x64', 1, 'v14.100.35719.0');
  Check('Newer x64 runtime', '');
  SetRuntime(HKLM64, 'x64', 1, 'v14.99.12344.0');
  Check('Older x64 runtime', '/install;');
  SetRuntime(HKLM32, 'x64', 1, 'v14.100.35719.0');
  Check('Wrong registry view cannot satisfy x64', '/install;');
end;

procedure RunRepairTests;
begin
  SetMachine(False);
  SetRuntime(HKLM64, 'x64', 1, 'v{#VCRedistVersion}');
  FixtureMsvcp := '14.15.26706.0';
  Check('Current registration with old msvcp is repaired', '/repair;');
  FixtureVcruntime := '';
  Check('Missing vcruntime is repaired', '/repair;');
  FixtureVcruntime1 := 'unreadable';
  Check('Invalid vcruntime_1 is repaired', '/repair;');

  SetMachine(True);
  SetRuntime(HKLM64, 'arm64', 1, 'v{#VCRedistVersion}');
  FixtureMsvcp := '14.15.26706.0';
  Check('ARM64X native DLL mismatch is repaired', '/repair;');

  SetMachine(False);
  SetRuntime(HKLM64, 'x64', 1, '14.100.35719.0');
  FixtureMsvcp := '14.15.26706.0';
  CheckFailure('Newer registration and old DLLs cannot use old offline bundle', 'is older and cannot repair it', 0, False);

  SetMachine(False);
  SetRuntime(HKLM64, 'x64', 1, 'v14.98.12344.0');
  FixtureExitCodes[1] := 1638;
  FixtureAfterVersions[1] := '14.100.35719.0';
  FixtureRepairFiles[1] := False;
  FixtureMsvcp := '14.15.26706.0';
  CheckFailure('1638 with newer damaged runtime does not loop or downgrade', 'still do not meet minimum', 1, False);

  SetMachine(False);
  FixtureExitCodes[1] := 1638;
  Check('1638 is acceptable only when postcheck proves health', '/install;');
  SetMachine(False);
  FixtureExitCodes[1] := -2147023258;
  Check('HRESULT product-version response requires healthy postcheck', '/install;');

  SetMachine(False);
  FixtureRepairFiles[1] := False;
  FixtureMsvcp := '14.15.26706.0';
  Check('Repair once after install leaves stale files', '/install;/repair;');

  SetMachine(False);
  FixtureRepairFiles[1] := False;
  FixtureRepairFiles[2] := False;
  FixtureMsvcp := '14.15.26706.0';
  CheckFailure('Successful process codes cannot hide stale DLLs', 'still do not meet minimum', 2, False);
  SetMachine(False);
  SetRuntime(HKLM64, 'x64', 1, '{#VCRedistVersion}');
  FixtureRepairFiles[1] := False;
  FixtureMsvcp := '14.15.26706.0';
  CheckFailure('Failed same-version repair is not repeated', 'still do not meet minimum', 1, False);
  SetMachine(False);
  FixtureFailToStart := True;
  FixtureExitCodes[1] := 5;
  CheckFailure('Failed redistributable launch blocks installation', 'could not start', 1, False);
  SetMachine(False);
  FixtureExitCodes[1] := 1603;
  CheckFailure('Failed redistributable blocks installation', 'failed (exit 1603)', 1, False);
  SetMachine(False);
  FixtureExitCodes[1] := 3010;
  CheckFailure('Reboot required stops before app installation', 'Restart Windows', 1, True);
  SetMachine(False);
  FixtureExitCodes[1] := 1641;
  CheckFailure('Reboot initiated stops before app installation', 'Restart Windows', 1, True);
end;

function InitializeSetup: Boolean;
var
  Outcome: String;
begin
  try
    RunTests;
    RunRepairTests;
    Outcome := 'PASS: ' + IntToStr(TestCount) + ' prerequisite scenarios';
  except
    Outcome := 'FAIL: ' + GetExceptionMessage;
  end;
  SaveStringToFile(ExpandConstant('{param:RESULTS}'), Outcome, False);
  Result := False;
end;
