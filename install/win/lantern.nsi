Name "Lantern"

# Note, this requires you to have the Inetc plugin installed
# http://nsis.sourceforge.net/Inetc_plug-in

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

!define INSTALLER_URL "https://s3.amazonaws.com/lantern/newest.exe"
!define INSTALLER_LOCAL_PATH "$TEMP\lanternInstaller.exe"

# Installer sections
Section -Main SEC0000
    SetOutPath $PROFILE
    SetOverwrite on
    File "../wrapper\.lantern-configurl.txt"
    SetFileAttributes "$PROFILE\.lantern-configurl.txt" HIDDEN
    Call GetMainInstaller

    #WriteRegStr HKLM "${REGKEY}\Components" Main 1
SectionEnd

# Installer functions
Function .onInit
    InitPluginsDir
FunctionEnd

Function GetMainInstaller
    #MessageBox MB_OK "Lantern is downloading components necessary for installation. Please be patient."
 
    # The "" is necessary per this article: http://stackoverflow.com/questions/4294313/how-to-get-around-nsis-download-error-connecting-to-host
    # I don't know why, but it works
    inetc::get /CONNECTTIMEOUT=40 /RECEIVETIMEOUT=40 /RESUME "" ${INSTALLER_URL} ${INSTALLER_LOCAL_PATH}
    Pop $R0 ;Get the return value
    StrCmp $R0 "OK" +3
    MessageBox MB_OK "We're sorry, but the Lantern install failed due to the \
        following error: $R0."  
    Quit
    ExecWait '${INSTALLER_LOCAL_PATH} /S'
    Delete ${INSTALLER_LOCAL_PATH}
FunctionEnd

