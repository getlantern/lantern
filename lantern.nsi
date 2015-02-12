# define name of installer
OutFile "lantern-installer.exe"
 
# define installation directory
InstallDir $PROGRAMFILES\Lantern
 
!define MUI_ICON windows.ico
!define MUI_UNICON windows.ico

# Included files
!include MUI.nsh

# For removing Start Menu shortcut in Windows 7
RequestExecutionLevel user
 
# start default section
Section
 
    # set the installation directory as the destination for the following actions
    SetOutPath $INSTDIR

    File lantern.exe
 
    # create the uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"
 
    CreateDirectory "$SMPROGRAMS\Lantern"
    CreateShortCut "$SMPROGRAMS\Lantern\Lantern.lnk" "$INSTDIR\lantern.exe"
    CreateShortCut "$SMPROGRAMS\Lantern\Uninstall.lnk" "$INSTDIR\uninstall.exe"
SectionEnd
 
# uninstaller section start
Section "uninstall"
 
    # first, delete the uninstaller
    Delete "$INSTDIR\uninstall.exe"
 
    # second, remove the link from the start menu
    Delete "$SMPROGRAMS\Lantern"
 
# uninstaller section end
SectionEnd