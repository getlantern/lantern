package apps

import (
	"errors"
	"fmt"
	"syscall"
	"unsafe"
)

const appExtension = ".exe"

func defaultAppDirs() []string {
	return []string{
		"C:\\Program Files",
	}
}

var excludeDirs = []string{}

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	// Load kernel32.dll
	//kernel32 := syscall.NewLazyDLL("kernel32.dll")
	//loadLibraryExW := kernel32.NewProc("LoadLibraryExW")
	// ... other kernel32 functions

	// Load user32.dll
	//user32 := syscall.NewLazyDLL("user32.dll")
	// ... user32 functions

	// Load shell32.dll
	shell32 := syscall.NewLazyDLL("shell32.dll")
	extractIconExW := shell32.NewProc("ExtractIconExW")

	executablePath, err := syscall.UTF16PtrFromString("C:\\Windows\\System32\\notepad.exe")
	if err != nil {
		return "", fmt.Errorf("Could not get executable path %w", err)
	}

	// Example of calling ExtractIconExW (simplified)
	// You would need to allocate memory for large and small icons
	// and handle the return values and errors properly.
	_, _, err = extractIconExW.Call(
		uintptr(unsafe.Pointer(executablePath)),
		0, // Icon index
		0, // Large icon handle (output)
		0, // Small icon handle (output)
		1, // Number of icons to extract
	)

	if err != nil && err.(syscall.Errno) != 0 {
		fmt.Printf("Error calling ExtractIconExW: %v\n", err)
	} else {
		fmt.Println("ExtractIconExW called (check for icon handles)")
	}
}

func getAppID(appPath string) (string, error) {
	return "", errors.New("Not implemented")
}
