:: Copyright 2014 The Go Authors. All rights reserved.
:: Use of this source code is governed by a BSD-style
:: license that can be found in the LICENSE file.

@echo off

setlocal

if not exist make.bat goto error-invalid-path

if not exist jni\armeabi mkdir jni\armeabi

set CGO_ENABLED=1
set GOOS=android
set GOARCH=arm
set GOARM=7

go build -ldflags="-shared" -o jni/armeabi/libbasic.so .
if errorlevel 1 goto error-go-build

if defined NDK_ROOT goto ndk-build
echo NDK_ROOT path not defined
goto end

:ndk-build
call %NDK_ROOT%\ndk-build.cmd NDK_DEBUG=1 >nul

if defined ANT_HOME goto ant-build
echo ANT_HOME path not defined
goto end

:ant-build
call %ANT_HOME%\bin\ant.bat debug >nul
goto end

:error-invalid-path
echo make.bat must be run from example\basic
goto end

:error-go-build
echo Error building go lib
goto end


:end