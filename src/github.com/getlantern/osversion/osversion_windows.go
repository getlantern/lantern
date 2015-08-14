package osversion

import (
	"errors"
	"fmt"
	"syscall"
)

func GetString() (string, error) {
	dll, err := syscall.LoadDLL("kernel32.dll")
	if err != nil {
		return "", errors.New(fmt.Sprintf("Error loading kernel32.dll: %v", err))
	}
	p, err := dll.FindProc("GetVersion")
	if err != nil {
		return "", errors.New(fmt.Sprintf("Error finding GetVersion procedure: %v", err))
	}
	// The error is alway non-nil, as it returns the s
	v, _, _ := p.Call()
	return fmt.Sprintf("%d.%d.%d", byte(v), byte(v>>8), uint16(v>>16)), nil
}

func GetHumanReadable() (string, error) {
	versions := map[string]string{
		"5.0":  "Windows 2000 Professional / Windows 2000 Server",
		"5.1":  "Windows XP",
		"5.2":  "Windows XP Professional x64 / Windows Server 2003",
		"6.0":  "Windows Vista / Windows Server 2008",
		"6.1":  "Windows 7 / Windows Server 2008 R2",
		"6.2":  "Windows 8 / Windows Server 2012",
		"6.3":  "Windows 8.1 / Windows Server 2012 R2",
		"10.0": "Windows 10 / Windows Server 2016",
	}

	version, err := GetSemanticVersion()
	if err != nil {
		return "", err
	}

	vstr := fmt.Sprintf("%d.%d", version.Major, version.Minor)
	if str, ok := versions[vstr]; ok {
		return str, nil
	} else {
		return "", errors.New("Unknown OS X version")
	}
}
