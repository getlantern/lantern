package gowin

import (

)

const (
	ALL=true//Use for make ShellFolders.Context
	USER=false//Use for make ShellFolders.Context
)

type ShellFolders struct {
	Context bool 
}

// Return string with ProgramFiles path 
// Its don't use the Context value
func(s *ShellFolders)ProgramFiles()(val string){
	val, _ = GetReg("HKLM", `SOFTWARE\Microsoft\Windows\CurrentVersion`, "ProgramFilesDir")
	return
}

// Return string with AppData path, its use the Context defined in the ShellFolders struct
func(s *ShellFolders)AppData()(val string){
	if s.Context {
		val, _ = GetReg("HKLM", `Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders`, "Common AppData")
		return
	}
	val, _ = GetReg("HKCU", `Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders`, "AppData")
	return
}

// Return string with Desktop path, its use the Context defined in the ShellFolders struct
func(s *ShellFolders)Desktop()(val string){
	if s.Context {
		val, _ = GetReg("HKLM", `Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders`, "Common Desktop")
		return
	}
	val, _ = GetReg("HKCU", `Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders`, "Desktop")
	return
}

// Return string with Documents path, its use the Context defined in the ShellFolders struct
func(s *ShellFolders)Documents()(val string){
	if s.Context {
		val, _ = GetReg("HKLM", `Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders`, "Common Documents")
		return
	}
	val, _ = GetReg("HKCU", `Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders`, "Personal")
	return
}

// Return string with StarMenu root path, its use the Context defined in the ShellFolders struct
func(s *ShellFolders)StartMenu()(val string){
	if s.Context {
		val, _ = GetReg("HKLM", `Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders`, "Common Start Menu")
		return
	}
	val, _ = GetReg("HKCU", `Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders`, "Start Menu")
	return
}

// Return string with StarMenu programs path, its use the Context defined in the ShellFolders struct
func(s *ShellFolders)StartMenuPrograms()(val string){
	if s.Context {
		val, _ = GetReg("HKLM", `Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders`, "Common Programs")
		return
	}
	val, _ = GetReg("HKCU", `Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders`, "Programs")
	return
}
