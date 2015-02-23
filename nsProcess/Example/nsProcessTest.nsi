Name "nsProcessTest"
OutFile "nsProcessTest.exe"

!include "nsProcess.nsh"
!include "Sections.nsh"

Var RADIOBUTTON

Page components
Page instfiles


Section "Find process" FindProcess
	${nsProcess::FindProcess} "Calc.exe" $R0
	MessageBox MB_OK "nsProcess::FindProcess$\n$\n\
			Errorlevel: [$R0]"

	${nsProcess::Unload}
SectionEnd


Section /o "Kill process" KillProcess
	loop:
	${nsProcess::FindProcess} "NoTePad.exe" $R0
	StrCmp $R0 0 0 +2
	MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION 'Close "notepad" before continue' IDOK loop IDCANCEL end

	${nsProcess::KillProcess} "NoTePad.exe" $R0
	MessageBox MB_OK "nsProcess::KillProcess$\n$\n\
			Errorlevel: [$R0]"

	Exec "notepad.exe"
	Exec "notepad.exe"
	Exec "notepad.exe"
	Sleep 1000
	BringToFront
	MessageBox MB_OK "Press OK and 3 notepad's windows will be closed (TERMINATED)"

	${nsProcess::KillProcess} "NoTePad.exe" $R0
	MessageBox MB_OK "nsProcess::KillProcess$\n$\n\
			Errorlevel: [$R0]"

	Exec "notepad.exe"
	Exec "notepad.exe"
	Exec "notepad.exe"
	Sleep 1000
	BringToFront
	MessageBox MB_OK "Press OK and 3 notepad's windows will be CLOSED"

	${nsProcess::CloseProcess} "NoTePad.exe" $R0
	MessageBox MB_OK "nsProcess::CloseProcess$\n$\n\
			Errorlevel: [$R0]"


	end:
	${nsProcess::Unload}
SectionEnd


Function .onInit
	StrCpy $RADIOBUTTON ${FindProcess}
FunctionEnd

Function .onSelChange
	!insertmacro StartRadioButtons $RADIOBUTTON
	!insertmacro RadioButton ${FindProcess}
	!insertmacro RadioButton ${KillProcess}
	!insertmacro EndRadioButtons
FunctionEnd
