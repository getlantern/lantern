// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package eventlog

import (
	"code.google.com/p/winsvc/registry"
	"code.google.com/p/winsvc/winapi"
	"errors"
	"syscall"
)

const (
	// Log levels.
	Info    = winapi.EVENTLOG_INFORMATION_TYPE
	Warning = winapi.EVENTLOG_WARNING_TYPE
	Error   = winapi.EVENTLOG_ERROR_TYPE
)

const addKeyName = `SYSTEM\CurrentControlSet\Services\EventLog\Application`

// Install modifies PC registry to allow logging with event source src.
// It adds all required keys/values to event log key. Install uses msgFile
// as event message file, creating key as REG_EXPAND_SZ, if useExpandKey
// is true, otherwise as REG_SZ. Use bitwise of log.Error, log.Warning
// and log.Info to specify events supported.
func Install(src, msgFile string, useExpandKey bool, eventsSupported uint32) error {
	appkey, err := registry.OpenKey(syscall.HKEY_LOCAL_MACHINE, addKeyName)
	if err != nil {
		return err
	}
	defer appkey.Close()
	sk, alreadyExist, err := appkey.CreateSubKey(src)
	if err != nil {
		return err
	}
	defer sk.Close()
	if alreadyExist {
		return errors.New(addKeyName + `\` + src + " registry key already exists")
	}
	err = sk.SetUInt32("CustomSource", 1)
	if err != nil {
		return err
	}
	if useExpandKey {
		err = sk.SetStringExpand("EventMessageFile", msgFile)
	} else {
		err = sk.SetString("EventMessageFile", msgFile)
	}
	if err != nil {
		return err
	}
	err = sk.SetUInt32("TypesSupported", eventsSupported)
	if err != nil {
		return err
	}
	return nil
}

// InstallAsEventCreate is the same as Install, but uses
// %SystemRoot%\System32\EventCreate.exe as event message file.
func InstallAsEventCreate(src string, eventsSupported uint32) error {
	return Install(src, "%SystemRoot%\\System32\\EventCreate.exe", true, eventsSupported)
}

// Remove deletes all registry elements installed by correspondent Install.
func Remove(src string) error {
	appkey, err := registry.OpenKey(syscall.HKEY_LOCAL_MACHINE, addKeyName)
	if err != nil {
		return err
	}
	defer appkey.Close()
	return appkey.DeleteSubKey(src)
}
