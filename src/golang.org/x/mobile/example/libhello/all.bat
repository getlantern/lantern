:: Copyright 2014 The Go Authors. All rights reserved.
:: Use of this source code is governed by a BSD-style
:: license that can be found in the LICENSE file.

@echo off

setlocal

echo # building libhello
call make.bat

echo # installing bin/Hello-debug.apk
adb install -r bin/Hello-debug.apk >nul

echo # starting com.example.hello.MainActivity
adb shell am start -a android.intent.action.MAIN -n com.example.hello/com.example.hello.MainActivity >nul