Name "Lantern"

# General Symbol Definitions
!define REGKEY "SOFTWARE\$(^Name)"
!define VERSION 0.1
!define COMPANY "Brave New Software Project, Inc"
!define URL https://www.getlantern.org

# MUI defines
!define MUI_ICON ../../lantern-ui/app/img/favicon.ico
#!define MUI_FINISHPAGE_NOAUTOCLOSE

!define MUI_UNICON ../../lantern-ui/app/img/favicon.ico 

# Included files
!include Sections.nsh
!include MUI.nsh

# Installer pages
# !insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
# Page instfiles

# Installer attributes
OutFile lantern-installer.exe
InstallDir $APPDATA\lantern-net-installer
CRCCheck on
XPStyle on
#SilentInstall silent
VIProductVersion 0.1.0.0
VIAddVersionKey ProductName "Lantern Loader"
VIAddVersionKey ProductVersion "${VERSION}"
VIAddVersionKey CompanyName "${COMPANY}"
VIAddVersionKey CompanyWebsite "${URL}"
VIAddVersionKey FileVersion "${VERSION}"
VIAddVersionKey FileDescription ""
VIAddVersionKey LegalCopyright ""

!define INSTALLER_URL "https://s3.amazonaws.com/lantern/latest.exe"

# Installer sections
Section -Main SEC0000
    SetOutPath $INSTDIR
    SetOverwrite on
    File "../wrapper/fallback.json"
    Call GetMainInstaller

    #WriteRegStr HKLM "${REGKEY}\Components" Main 1
SectionEnd

# Installer functions
Function .onInit
    InitPluginsDir
FunctionEnd

Function GetMainInstaller
    #MessageBox MB_OK "Lantern is downloading components necessary for installation. Please be patient."
 
    StrCpy $2 "$TEMP\lanternInstaller.exe"
    nsisdl::download /TIMEOUT=40000 ${INSTALLER_URL} $2
    Pop $R0 ;Get the return value
    StrCmp $R0 "success" +3
    MessageBox MB_OK "We're sorry, but the Lantern install failed due to the \
        following error: $R0."  
    Quit
    ExecWait '$2 /S'
    Delete $2
FunctionEnd

