Rem @echo OFF
Rem The arguments are as follows:
Rem 1) The install path
Rem 2) Whether to install or uninstall
Rem 3) The version
Rem Note the uninstall function doesn't really need all of these, but it's easier to be consistent
echo First arg %1 and %~1
echo Second arg %2 and %~2
echo Third arg %3 and %~3
if ""%1"" == "" goto error
echo Checked first
if "%2" == "" goto error
echo Checked second
if "%3" == "" goto error
echo Checked third

goto setNetShVersion
:oldNetSh
set OLD_NETSH=true
echo Old netsh
goto start

:newNetSh
set NEW_NETSH=true
echo New netsh
goto start

:start
Rem This is just to make testing easier -- can use a dummy value to avoid overwriting 'real' settings
set ID=LittleShoot
if %2 == "install" goto install
if %2 == "uninstall" goto uninstall

:install
Rem Note the "$~1" removes the surrounding quotes
REG ADD "HKLM\SOFTWARE\%ID%" /v Path /t REG_SZ /d "%~1" /f
REG ADD "HKLM\SOFTWARE\%ID%\Components" /v Main /t REG_SZ /d 1 /f
REG ADD "HKLM\SOFTWARE\MozillaPlugins\@littleshoot.org/%ID%" /v Path /t REG_SZ /d "%~1\nplittleshoot.dll" /f
REG ADD "HKLM\SOFTWARE\MozillaPlugins\@littleshoot.org/%ID%" /v ProductName /t REG_SZ /d "LittleShoot P2P Plugin" /f
REG ADD "HKLM\SOFTWARE\MozillaPlugins\@littleshoot.org/%ID%" /v Vendor /t REG_SZ /d "LittleShoot LLC" /f
REG ADD "HKLM\SOFTWARE\MozillaPlugins\@littleshoot.org/%ID%" /v Description /t REG_SZ /d "P2P Download Accelerator" /f
REG ADD "HKLM\SOFTWARE\MozillaPlugins\@littleshoot.org/%ID%" /v Version /t REG_SZ /d "%3" /f
REG ADD "HKCR\MIME\Database\Content Type\application/x-bittorrent" /v "CLSID" /t REG_SZ /d "{0CC00AEB-7E95-4a80-8C29-ED90939FC99F}" /f
REG ADD "HKCR\MIME\Database\Content Type\application/x-littleshoot" /v "CLSID" /t REG_SZ /d "{0CC00AEB-7E95-4a80-8C29-ED90939FC99F}" /f
Rem Make LittleShoot the default torrent handler for .torrent files.
REG ADD "HKCU\SOFTWARE\Classes\.torrent" /ve /t REG_SZ /d "LittleShoot" /f
REG ADD "HKCU\SOFTWARE\Classes\.torrent" /v "Content type" /t REG_SZ /d "application/x-bittorrent" /f
REG ADD "HKCU\SOFTWARE\Classes\%ID%\Content Type" /ve /t REG_SZ /d "application/x-bittorrent" /f
Rem The quotes get a little crazy on the value here, but it's correct
REG ADD "HKCU\SOFTWARE\Classes\%ID%\shell\open\command" /ve /t REG_SZ /d """"%~1\LittleShoot.exe""" ""%%1""" /f

goto :addNetSh

:uninstall
REG DELETE "HKLM\SOFTWARE\%ID%" /f
REG DELETE "HKLM\SOFTWARE\MozillaPlugins\@littleshoot.org/%ID%" /f
REG DELETE "HKCR\MIME\Database\Content Type\application/x-bittorrent" /f
REG DELETE "HKCR\MIME\Database\Content Type\application/x-littleshoot" /f
REG DELETE "HKCU\SOFTWARE\Classes\.torrent" /f
REG DELETE "HKCU\SOFTWARE\Classes\%ID%" /f

goto :removeNetSh

:addNetSh
Rem if defined NEW_NETSH netsh advfirewall firewall add rule name="LittleShoot" dir=in action=allow program="%1\LittleShoot.exe" enable=yes profile=any
if defined NEW_NETSH netsh advfirewall firewall add rule name="LittleShoot" dir=in action=allow program="%~1\LittleShoot.exe" enable=yes profile=any
if defined OLD_NETSH netsh firewall add allowedprogram "%~1\LittleShoot.exe" "LittleShoot" ENABLE
goto :end

:removeNetSh
if defined NEW_NETSH netsh advfirewall firewall delete rule name="LittleShoot" program="%~1\LittleShoot.exe"
if defined OLD_NETSH netsh firewall delete allowedprogram "%~1\LittleShoot.exe"
goto :end

:setNetShVersion 
ver | find "2003" > nul
if %ERRORLEVEL% == 0 goto oldNetSh

ver | find "XP" > nul
if %ERRORLEVEL% == 0 goto oldNetSh

ver | find "2000" > nul
if %ERRORLEVEL% == 0 goto oldNetSh

ver | find "NT" > nul
if %ERRORLEVEL% == 0 goto oldNetSh

Rem If we get here, we're using the new version
goto newNetSh

:error
echo Missing arguments!
goto :EOF 

:end
echo Done!