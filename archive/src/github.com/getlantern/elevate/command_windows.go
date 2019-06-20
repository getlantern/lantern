package elevate

import (
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
)

var (
	scriptFile *os.File
	scriptPath string
)

func init() {
	var err error
	scriptFile, err = ioutil.TempFile("", "elevate_")
	if err != nil {
		panic(fmt.Errorf("Unable to create temporary script file: %v", err))
	}
	defer scriptFile.Close()
	_, err = scriptFile.WriteString(vbscript)
	if err != nil {
		panic(fmt.Errorf("Unable to write script to temporary script file: %v", err))
	}
	scriptPath = scriptFile.Name() + ".vbs"
	scriptFile.Close()
	err = os.Rename(scriptFile.Name(), scriptPath)
	if err != nil {
		panic(fmt.Errorf("Unable to move elevate script to %v: %v", scriptPath, err))
	}
}

func buildCommand(prompt string, icon string, name string, args ...string) (*exec.Cmd, error) {
	allArgs := make([]string, 0, len(args)+2)
	allArgs = append(allArgs, scriptPath, name)
	allArgs = append(allArgs, args...)
	return exec.Command("wscript.exe", allArgs...), nil
}

const vbscript = `'--------------------------------------------
'Run an application under elevated privileges
'25.2.2011 FNL
'--------------------------------------------
Dim sApp, sParms
Const DQ=""""

If WScript.Arguments.count = 0 Then
    MsgBox "Usage: Elevate NameOfApplication", 0, "UAC Elevation"
    WScript.Quit
End If

If WScript.Arguments(0) <> "|" Then 
    ElevateUAC
    WScript.Quit
End If

GetParms(1)
Set oWshShell = CreateObject("WScript.Shell")
oWshShell.run sApp & sParms, 1

'-----------------------------------------
'Run this script under elevated privileges
'-----------------------------------------
Sub ElevateUAC
    GetParms(0)
    Set oShell = CreateObject("Shell.Application")
    oShell.ShellExecute "wscript.exe", DQ & WScript.ScriptFullName & DQ _
    & " | " & sApp & sParms, , "runas", 1
    WScript.Quit
End Sub
'--------------------------------
'Assemble command line parameters
'--------------------------------
Sub GetParms(iFirst)
    sParms = " "
    sApp = DQ & WScript.Arguments(iFirst) & DQ & " "
    For i = iFirst+1 To WScript.Arguments.Count-1
          sParms = sParms & DQ & WScript.Arguments(i) & DQ & " "
    Next
End Sub`
