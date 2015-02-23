Name "Lantern"

# Installs Lantern and launchs it
# See http://nsis.sourceforge.net/Run_an_application_shortcut_after_an_install

AutoCloseWindow true

!addplugindir nsis_plugins
!include "nsis_includes/nsProcess.nsh"

# Use the modern ui
!include MUI.nsh
!define MUI_ICON lantern.ico

;Languages
!insertmacro MUI_LANGUAGE "Farsi"
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Czech"
!insertmacro MUI_LANGUAGE "Dutch"
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "German"
!insertmacro MUI_LANGUAGE "Korean"
!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "Swedish"
!insertmacro MUI_LANGUAGE "TradChinese"
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "Slovak"

# define name of installer
OutFile "lantern-installer-unsigned.exe"
 
# define installation directory
InstallDir $PROGRAMFILES\Lantern
 
# For removing Start Menu shortcut in Windows 7
RequestExecutionLevel admin
    
# start default section
Section
    # Stop existing Lantern if necessary
    ${nsProcess::KillProcess} "lantern.exe" $R0
    # Sleep for 1 second to give file lock a chance to clear
    Sleep 1000

    # Remove anything that may currently be installed
    RMDir /r "$SMPROGRAMS\Lantern"
    RMDir /r "$INSTDIR"
    
    # set the installation directory as the destination for the following actions
    SetOutPath $INSTDIR

    File lantern.exe
    File lantern.ico
 
    # Store installation folder
    WriteRegStr HKCU "Software\Lantern" "" $INSTDIR

    WriteUninstaller "$INSTDIR\uninstall.exe"

    # Support uninstalling via Add/Remove programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Lantern" \
                     "DisplayName" "Lantern"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Lantern" \
                     "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
 
    CreateDirectory "$SMPROGRAMS\Lantern"
    CreateShortCut "$SMPROGRAMS\Lantern\Lantern.lnk" "$INSTDIR\lantern.exe" "" "$INSTDIR\lantern.ico" 0
    CreateShortCut "$SMPROGRAMS\Lantern\Uninstall Lantern.lnk" "$INSTDIR\uninstall.exe"

    # Launch Lantern
    ShellExecAsUser::ShellExecAsUser "" "$INSTDIR\lantern.exe"

    ${nsProcess::Unload}
SectionEnd
 
# uninstaller section start
Section "uninstall"
    # Stop Lantern if necessary
    ${nsProcess::KillProcess} "lantern.exe" $R0

    RMDir /r "$SMPROGRAMS\Lantern"
    RMDir /r "$INSTDIR" 
 
# uninstaller section end
SectionEnd