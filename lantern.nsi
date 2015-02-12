Name "Lantern"

# Use the modern ui
!include MUI.nsh
!define MUI_ICON lantern.ico
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

# define name of installer
OutFile "lantern-installer.exe"
 
# define installation directory
InstallDir $PROGRAMFILES\Lantern
 
# start default section
Section
 
    # set the installation directory as the destination for the following actions
    SetOutPath $INSTDIR

    File lantern.exe
    File lantern.ico
 
    WriteUninstaller "$INSTDIR\uninstall.exe"
 
    # Apply Start Menu settings to all users
    SetShellVarContext all

    CreateDirectory "$SMPROGRAMS\Lantern"
    CreateShortCut "$SMPROGRAMS\Lantern\Lantern.lnk" "$INSTDIR\lantern.exe" "" "$INSTDIR\lantern.ico" 0
    CreateShortCut "$SMPROGRAMS\Lantern\Uninstall Lantern.lnk" "$INSTDIR\uninstall.exe"
SectionEnd
 
# uninstaller section start
Section "uninstall"
    # Apply Start Menu settings to all users
    SetShellVarContext all

    Delete "$INSTDIR\uninstall.exe" 
    Delete "$SMPROGRAMS\Lantern"
 
# uninstaller section end
SectionEnd