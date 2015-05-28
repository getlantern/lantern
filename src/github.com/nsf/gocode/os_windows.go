package main

import (
	"flag"
	"fmt"
	"path/filepath"
	"syscall"
	"unsafe"
)

var (
	shell32  = syscall.NewLazyDLL("shell32.dll")
	kernel32 = syscall.NewLazyDLL("kernel32.dll")
)

var (
	proc_sh_get_folder_path   = shell32.NewProc("SHGetFolderPathW")
	proc_get_module_file_name = kernel32.NewProc("GetModuleFileNameW")
)

func create_sock_flag(name, desc string) *string {
	return flag.String(name, "tcp", desc)
}

// Full path of the current executable
func get_executable_filename() string {
	b := make([]uint16, syscall.MAX_PATH)
	ret, _, err := syscall.Syscall(proc_get_module_file_name.Addr(), 3,
		0, uintptr(unsafe.Pointer(&b[0])), uintptr(len(b)))
	if int(ret) == 0 {
		panic(fmt.Sprintf("GetModuleFileNameW : err %d", int(err)))
	}
	return syscall.UTF16ToString(b)
}

const (
	csidl_appdata = 0x1a
)

func get_appdata_folder_path() string {
	b := make([]uint16, syscall.MAX_PATH)
	ret, _, err := syscall.Syscall6(proc_sh_get_folder_path.Addr(), 5,
		0, csidl_appdata, 0, 0, uintptr(unsafe.Pointer(&b[0])), 0)
	if int(ret) != 0 {
		panic(fmt.Sprintf("SHGetFolderPathW : err %d", int(err)))
	}
	return syscall.UTF16ToString(b)
}

func config_dir() string {
	return filepath.Join(get_appdata_folder_path(), "gocode")
}

func config_file() string {
	return filepath.Join(get_appdata_folder_path(), "gocode", "config.json")
}
