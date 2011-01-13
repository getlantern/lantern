Rem @echo OFF
Rem The arguments are as follows:
Rem 1) The install path
Rem 2) Whether to install or uninstall
Rem Note the uninstall function doesn't really need all of these, but it's easier to be consistent
echo First arg %1 and %~1
echo Second arg %2 and %~2
if ""%1"" == "" goto error
echo Checked first
if "%2" == "" goto error
echo Checked second

goto setNetShVersion
:oldNetSh
set OLD_NETSH=true
echo Old netsh
goto install

:newNetSh
set NEW_NETSH=true
echo New netsh
goto install

:install
if defined NEW_NETSH netsh advfirewall firewall add rule name="Lantern" dir=in action=allow program="%~1\Lantern.exe" enable=yes profile=any
if defined OLD_NETSH netsh firewall add allowedprogram "%~1\Lantern.exe" "Lantern" ENABLE
goto :end

:removeNetSh
if defined NEW_NETSH netsh advfirewall firewall delete rule name="Lantern" program="%~1\Lantern.exe"
if defined OLD_NETSH netsh firewall delete allowedprogram "%~1\Lantern.exe"
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
