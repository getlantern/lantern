:: Copyright 2014 The Go Authors. All rights reserved.
:: Use of this source code is governed by a BSD-style
:: license that can be found in the LICENSE file.

@echo off

setlocal

if not exist make.bat goto error-invalid-path

:go-build
if not exist libs\armeabi-v7a mkdir libs\armeabi-v7a 
if not exist src\go\hi mkdir src\go\hi 
if not exist jni\armeabi mkdir jni\armeabi

set CGO_ENABLED=1
set GOOS=android
set GOARCH=arm
set GOARM=7
set ANDROID_APP=%CD%

xcopy /y ..\..\app\*.java %ANDROID_APP%\src\go >nul
copy /y ..\..\bind\java\Seq.java %ANDROID_APP%\src\go\Seq.java >nul

go build -ldflags="-shared" .
if errorlevel 1 goto error-go-build

move /y libhello libs\armeabi-v7a\libgojni.so >nul

if defined ANT_HOME goto ant-build
echo ANT_HOME path not defined
goto end

:ant-build
call %ANT_HOME%\bin\ant.bat debug >nul
goto end

:error-invalid-path
echo make.bat must be run from example\libhello
goto end

:error-go-build
echo Error building go lib
goto end

:end