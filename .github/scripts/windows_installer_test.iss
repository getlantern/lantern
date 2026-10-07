; Tests use the actual dependency functions extracted by test_windows_installer.py.
; No real registry access, downloads, services, or dependency execution occur.
; Use a different minimum from the old fixed floor to catch hardcoded versions.
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
  FixtureArm64: Boolean;
  FixtureRoot: Integer;
  FixtureKey, FixtureVersion: String;
  FixtureInstalled: Cardinal;
  FixtureHasInstalled, FixtureHasVersion: Boolean;
  AddedCount, ExtractedCount, TestCount: Integer;
  AddedFilename, AddedParameters, AddedURL: String;

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
  Assert(Value = '{log}', 'Unexpected constant: ' + Value);
  Result := 'C:\Test Logs\Lantern Setup.log';
end;

procedure Fixture_ExtractTemporaryFile(const Filename: String);
begin
  Assert(Filename = 'VC_redist.x64.exe', 'Wrong embedded redistributable');
  ExtractedCount := ExtractedCount + 1;
end;

procedure Fixture_Dependency_Add(const Filename, Parameters, Title, URL, Checksum: String; const ForceSuccess, RestartAfter: Boolean);
begin
  AddedCount := AddedCount + 1;
  AddedFilename := Filename;
  AddedParameters := Parameters;
  AddedURL := URL;
  Assert(not ForceSuccess, 'Do not treat all redistributable exit codes as success');
  Assert(not RestartAfter, 'Do not request unconditional reboot');
end;

#include "dependency-under-test.iss"

procedure SetMachine(const Arm64: Boolean);
begin
  FixtureArm64 := Arm64;
  FixtureHasInstalled := False;
  FixtureHasVersion := False;
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

procedure Check(const Name: String; const ShouldQueue: Boolean);
begin
  Log('TEST: ' + Name);
  AddedCount := 0;
  ExtractedCount := 0;
  Dependency_AddVCRuntime;
  if ShouldQueue then begin
    Assert(AddedCount = 1, Name + ': expected one dependency');
    Assert(ExtractedCount = 1, Name + ': expected extraction of embedded runtime');
    Assert(AddedFilename = 'VC_redist.x64.exe', Name + ': wrong filename');
    Assert(AddedURL = '', Name + ': runtime must use embedded bundle');
    Assert(AddedParameters = '/install /passive /norestart /log "C:\Test Logs\Lantern Setup-vcredist.log"', Name + ': wrong arguments or unquoted log path');
  end else begin
    Assert(AddedCount = 0, Name + ': sufficient runtime must be skipped');
    Assert(ExtractedCount = 0, Name + ': sufficient runtime needs no extraction');
  end;
  TestCount := TestCount + 1;
end;

procedure RunTests;
begin
  SetMachine(True);
  Check('Clean ARM64 uses embedded x64 bundle', True);
  SetRuntime(HKLM64, 'arm64', 1, 'v14.99.12345.0');
  Check('Minimum ARM64 runtime without x64 key', False);
  SetRuntime(HKLM64, 'arm64', 1, 'V14.100.35719.0');
  Check('Newer ARM64 runtime with uppercase prefix', False);
  SetRuntime(HKLM64, 'arm64', 1, '14.99.12345.1');
  Check('Newer fourth component without prefix', False);
  SetRuntime(HKLM64, 'x64', 1, 'v14.100.35719.0');
  Check('x64 key alone cannot satisfy ARM64', True);
  SetRuntime(HKLM32, 'arm64', 1, 'v14.100.35719.0');
  Check('Wrong registry view cannot satisfy ARM64', True);
  SetRuntime(HKLM64, 'arm64', 1, 'v14.99.12344.0');
  Check('ARM64 runtime below minimum', True);
  SetRuntime(HKLM64, 'arm64', 1, 'v14.9.12345.0');
  Check('Version comparison is numeric', True);
  SetRuntime(HKLM64, 'arm64', 1, 'vnot-a-version');
  Check('Malformed runtime version', True);
  SetRuntime(HKLM64, 'arm64', 1, '');
  Check('Empty runtime version', True);
  SetRuntime(HKLM64, 'arm64', 0, 'v14.100.35719.0');
  Check('Installed flag is zero', True);
  SetRuntime(HKLM64, 'arm64', 2, 'v14.100.35719.0');
  Check('Installed flag must equal one', True);
  SetRuntime(HKLM64, 'arm64', 1, 'v14.100.35719.0');
  FixtureHasInstalled := False;
  Check('Installed flag is missing', True);
  FixtureHasInstalled := True;
  FixtureHasVersion := False;
  Check('Version value is missing', True);

  SetMachine(False);
  Check('Clean x64 uses embedded x64 bundle', True);
  SetRuntime(HKLM64, 'x64', 1, '14.99.12345.0');
  Check('Minimum x64 runtime', False);
  SetRuntime(HKLM64, 'x64', 1, 'v14.100.35719.0');
  Check('Newer x64 runtime', False);
  SetRuntime(HKLM64, 'x64', 1, 'v14.99.12344.0');
  Check('Older x64 runtime', True);
  SetRuntime(HKLM32, 'x64', 1, 'v14.100.35719.0');
  Check('Wrong registry view cannot satisfy x64', True);
end;

function InitializeSetup: Boolean;
var
  Outcome: String;
begin
  try
    RunTests;
    Outcome := 'PASS: ' + IntToStr(TestCount) + ' prerequisite scenarios';
  except
    Outcome := 'FAIL: ' + GetExceptionMessage;
  end;
  SaveStringToFile(ExpandConstant('{param:RESULTS}'), Outcome, False);
  Result := False;
end;
