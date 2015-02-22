Name "Lantern"

# Installs Lantern and launchs it
# See http://nsis.sourceforge.net/Run_an_application_shortcut_after_an_install

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

    # Launch Lantern
    ExecShell "" "$SMPROGRAMS\Lantern\Lantern.lnk"
SectionEnd
 
# uninstaller section start
Section "uninstall"
    RMDir /r "$SMPROGRAMS\Lantern"
    RMDir /r "$INSTDIR" 
 
# uninstaller section end
SectionEnd

Function .onInit

    ;Language selection dialog

    Push ""
    Push ${LANG_ENGLISH}
    Push English
    Push ${LANG_CZECH}
    Push Czech
    Push ${LANG_DUTCH}
    Push Dutch
    Push ${LANG_FARSI}
    Push Farsi
    Push ${LANG_FRENCH}
    Push French
    Push ${LANG_GERMAN}
    Push German
    Push ${LANG_KOREAN}
    Push Korean
    Push ${LANG_RUSSIAN}
    Push Russian
    Push ${LANG_SPANISH}
    Push Spanish
    Push ${LANG_SWEDISH}
    Push Swedish
    Push ${LANG_TRADCHINESE}
    Push "Traditional Chinese"
    Push ${LANG_SIMPCHINESE}
    Push "Simplified Chinese"
    Push ${LANG_SLOVAK}
    Push Slovak
    Push A ; A means auto count languages
           ; for the auto count to work the first empty push (Push "") must remain
    LangDLL::LangDialog "Installer Language" "Please select the language of the installer"

    Pop $LANGUAGE
    StrCmp $LANGUAGE "cancel" 0 +2
        Abort
FunctionEnd