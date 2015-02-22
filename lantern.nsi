Name "Lantern"

# Installs Lantern and launchs it
# See http://nsis.sourceforge.net/Run_an_application_shortcut_after_an_install

# Use the modern ui
!include MUI.nsh
!define MUI_ICON lantern.ico
!insertmacro MUI_PAGE_INSTFILES
    # These indented statements modify settings for MUI_PAGE_FINISH
    !define MUI_FINISHPAGE_NOAUTOCLOSE
    !define MUI_FINISHPAGE_RUN
    !define MUI_FINISHPAGE_RUN_CHECKED
    !define MUI_FINISHPAGE_RUN_TEXT "Run Lantern"
    !define MUI_FINISHPAGE_RUN_FUNCTION "LaunchLantern"
!insertmacro MUI_PAGE_FINISH

;Languages
!insertmacro MUI_LANGUAGE "English"

# define name of installer
OutFile "lantern-installer-unsigned.exe"
 
# define installation directory
InstallDir $PROGRAMFILES\Lantern
 
# For removing Start Menu shortcut in Windows 7
RequestExecutionLevel user
    
# start default section
Section
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
SectionEnd
 
# uninstaller section start
Section "uninstall"
    RMDir /r "$SMPROGRAMS\Lantern"
    RMDir /r "$INSTDIR" 
 
# uninstaller section end
SectionEnd

Function LaunchLantern
    ExecShell "" "$SMPROGRAMS\Lantern\Lantern.lnk"
FunctionEnd