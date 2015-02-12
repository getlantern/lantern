:: Copyright 2014 The Go Authors. All rights reserved.
:: Use of this source code is governed by a BSD-style
:: license that can be found in the LICENSE file.

@echo off

setlocal

echo # building sprite
call make.bat

echo # installing bin/nativeactivity-debug.apk
adb install -r bin/nativeactivity-debug.apk >nul

echo # starting android.app.NativeActivity
adb shell am start -a android.intent.action.MAIN -n com.example.sprite/android.app.NativeActivity >nul