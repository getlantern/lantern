// Copyright 2012 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build windows

package winapi

const (
	SC_MANAGER_CONNECT = 1 << iota
	SC_MANAGER_CREATE_SERVICE
	SC_MANAGER_ENUMERATE_SERVICE
	SC_MANAGER_LOCK
	SC_MANAGER_QUERY_LOCK_STATUS
	SC_MANAGER_MODIFY_BOOT_CONFIG
	SC_MANAGER_ALL_ACCESS = 0xf003f
)

//sys	OpenSCManager(machineName *uint16, databaseName *uint16, access uint32) (handle syscall.Handle, err error) [failretval==0] = advapi32.OpenSCManagerW

const (
	SERVICE_KERNEL_DRIVER = 1 << iota
	SERVICE_FILE_SYSTEM_DRIVER
	SERVICE_ADAPTER
	SERVICE_RECOGNIZER_DRIVER
	SERVICE_WIN32_OWN_PROCESS
	SERVICE_WIN32_SHARE_PROCESS
	SERVICE_WIN32               = SERVICE_WIN32_OWN_PROCESS | SERVICE_WIN32_SHARE_PROCESS
	SERVICE_INTERACTIVE_PROCESS = 256
	SERVICE_DRIVER              = SERVICE_KERNEL_DRIVER | SERVICE_FILE_SYSTEM_DRIVER | SERVICE_RECOGNIZER_DRIVER
	SERVICE_TYPE_ALL            = SERVICE_WIN32 | SERVICE_ADAPTER | SERVICE_DRIVER | SERVICE_INTERACTIVE_PROCESS
)

const (
	SERVICE_BOOT_START = iota
	SERVICE_SYSTEM_START
	SERVICE_AUTO_START
	SERVICE_DEMAND_START
	SERVICE_DISABLED
)

const (
	SERVICE_ERROR_IGNORE = iota
	SERVICE_ERROR_NORMAL
	SERVICE_ERROR_SEVERE
	SERVICE_ERROR_CRITICAL
)

const (
	SC_STATUS_PROCESS_INFO = 0
)

const (
	SERVICE_STOPPED = 1 + iota
	SERVICE_START_PENDING
	SERVICE_STOP_PENDING
	SERVICE_RUNNING
	SERVICE_CONTINUE_PENDING
	SERVICE_PAUSE_PENDING
	SERVICE_PAUSED
	SERVICE_NO_CHANGE = 0xffffffff
)

const (
	SERVICE_ACCEPT_STOP = 1 << iota
	SERVICE_ACCEPT_PAUSE_CONTINUE
	SERVICE_ACCEPT_SHUTDOWN
	SERVICE_ACCEPT_PARAMCHANGE
	SERVICE_ACCEPT_NETBINDCHANGE
	SERVICE_ACCEPT_HARDWAREPROFILECHANGE
	SERVICE_ACCEPT_POWEREVENT
	SERVICE_ACCEPT_SESSIONCHANGE
)

const (
	SERVICE_CONTROL_STOP = 1 + iota
	SERVICE_CONTROL_PAUSE
	SERVICE_CONTROL_CONTINUE
	SERVICE_CONTROL_INTERROGATE
	SERVICE_CONTROL_SHUTDOWN
	SERVICE_CONTROL_PARAMCHANGE
	SERVICE_CONTROL_NETBINDADD
	SERVICE_CONTROL_NETBINDREMOVE
	SERVICE_CONTROL_NETBINDENABLE
	SERVICE_CONTROL_NETBINDDISABLE
	SERVICE_CONTROL_DEVICEEVENT
	SERVICE_CONTROL_HARDWAREPROFILECHANGE
	SERVICE_CONTROL_POWEREVENT
	SERVICE_CONTROL_SESSIONCHANGE
)

const (
	SERVICE_ACTIVE = 1 + iota
	SERVICE_INACTIVE
	SERVICE_STATE_ALL
)

const (
	SERVICE_QUERY_CONFIG = 1 << iota
	SERVICE_CHANGE_CONFIG
	SERVICE_QUERY_STATUS
	SERVICE_ENUMERATE_DEPENDENTS
	SERVICE_START
	SERVICE_STOP
	SERVICE_PAUSE_CONTINUE
	SERVICE_INTERROGATE
	SERVICE_USER_DEFINED_CONTROL
	SERVICE_ALL_ACCESS             = STANDARD_RIGHTS_REQUIRED | SERVICE_QUERY_CONFIG | SERVICE_CHANGE_CONFIG | SERVICE_QUERY_STATUS | SERVICE_ENUMERATE_DEPENDENTS | SERVICE_START | SERVICE_STOP | SERVICE_PAUSE_CONTINUE | SERVICE_INTERROGATE | SERVICE_USER_DEFINED_CONTROL
	SERVICE_RUNS_IN_SYSTEM_PROCESS = 1
	SERVICE_CONFIG_DESCRIPTION     = 1
	SERVICE_CONFIG_FAILURE_ACTIONS = 2
)

const (
	NO_ERROR = 0
)

type SERVICE_STATUS struct {
	ServiceType             uint32
	CurrentState            uint32
	ControlsAccepted        uint32
	Win32ExitCode           uint32
	ServiceSpecificExitCode uint32
	CheckPoint              uint32
	WaitHint                uint32
}

type SERVICE_TABLE_ENTRY struct {
	ServiceName *uint16
	ServiceProc uintptr
}

type QUERY_SERVICE_CONFIG struct {
	ServiceType      uint32
	StartType        uint32
	ErrorControl     uint32
	BinaryPathName   *uint16
	LoadOrderGroup   *uint16
	TagId            uint32
	Dependencies     *uint16
	ServiceStartName *uint16
	DisplayName      *uint16
}

type SERVICE_DESCRIPTION struct {
	Description *uint16
}

//sys	CloseServiceHandle(handle syscall.Handle) (err error) = advapi32.CloseServiceHandle
//sys	CreateService(mgr syscall.Handle, serviceName *uint16, displayName *uint16, access uint32, srvType uint32, startType uint32, errCtl uint32, pathName *uint16, loadOrderGroup *uint16, tagId *uint32, dependencies *uint16, serviceStartName *uint16, password *uint16) (handle syscall.Handle, err error) [failretval==0] = advapi32.CreateServiceW
//sys	OpenService(mgr syscall.Handle, serviceName *uint16, access uint32) (handle syscall.Handle, err error) [failretval==0] = advapi32.OpenServiceW
//sys	DeleteService(service syscall.Handle) (err error) = advapi32.DeleteService
//sys	StartService(service syscall.Handle, numArgs uint32, argVectors **uint16) (err error) = advapi32.StartServiceW
//sys	QueryServiceStatus(service syscall.Handle, status *SERVICE_STATUS) (err error) = advapi32.QueryServiceStatus
//sys	ControlService(service syscall.Handle, control uint32, status *SERVICE_STATUS) (err error) = advapi32.ControlService
//sys	StartServiceCtrlDispatcher(serviceTable *SERVICE_TABLE_ENTRY) (err error) = advapi32.StartServiceCtrlDispatcherW
//sys	SetServiceStatus(service syscall.Handle, serviceStatus *SERVICE_STATUS) (err error) = advapi32.SetServiceStatus
//sys	ChangeServiceConfig(service syscall.Handle, serviceType uint32, startType uint32, errorControl uint32, binaryPathName *uint16, loadOrderGroup *uint16, tagId *uint32, dependencies *uint16, serviceStartName *uint16, password *uint16, displayName *uint16) (err error) = advapi32.ChangeServiceConfigW
//sys	QueryServiceConfig(service syscall.Handle, serviceConfig *QUERY_SERVICE_CONFIG, bufSize uint32, bytesNeeded *uint32) (err error) = advapi32.QueryServiceConfigW
//sys	ChangeServiceConfig2(service syscall.Handle, infoLevel uint32, info *byte) (err error) = advapi32.ChangeServiceConfig2W
//sys	QueryServiceConfig2(service syscall.Handle, infoLevel uint32, buff *byte, buffSize uint32, bytesNeeded *uint32) (err error) = advapi32.QueryServiceConfig2W
