:: Copyright 2014 The Go Authors. All rights reserved.
:: Use of this source code is governed by a BSD-style
:: license that can be found in the LICENSE file.

@echo off

setlocal

if not exist make.bat goto error-invalid-path

set CGO_ENABLED=1
set GOOS=android
set GOARCH=arm
set GOARM=7
set ANDROID_APP=%CD%

if not exist src\main\jniLibs\armeabi mkdir src\main\jniLibs\armeabi
if not exist src\main\java\go mkdir src\main\java\go
if not exist src\main\java\demo mkdir src\main\java\demo

xcopy /y ..\..\app\*.java %ANDROID_APP%\src\main\java\go >nul
xcopy /y ..\..\bind\java\*.java %ANDROID_APP%\src\main\java\go >nul
xcopy /y %CD%\*.java %ANDROID_APP%\src\main\java\demo >nul

go build -ldflags="-shared" .
if errorlevel 1 goto error-go-build

move /y libhellojni %ANDROID_APP%\src\main\jniLibs\armeabi\libgojni.so >nul
goto end

:error-invalid-path
echo make.bat must be run from example\libhellojni
goto end

:error-go-build
echo Error building go lib
goto end

:end