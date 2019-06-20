package osversion

/*
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

int darwin_get_os(char* str, size_t size) {
    return sysctlbyname("kern.osrelease", str, &size, NULL, 0);
}
*/
import "C"

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
	"unsafe"
)

func GetString() (string, error) {
	bufferSize := C.size_t(256)
	str := (*C.char)(C.malloc(bufferSize))
	defer C.free(unsafe.Pointer(str))

	err := C.darwin_get_os(str, bufferSize)
	if err == -1 {
		return "", errors.New(fmt.Sprintf("Error running sysctl: %v", err))
	}
	return C.GoString(str), nil
}

func GetHumanReadable() (string, error) {
	version, err := GetSemanticVersion()
	if err != nil {
		return "", err
	}
	if version.Major < 4 || version.Major > 15 {
		return fmt.Sprintf("Unknown OS X version: %s", version.String()), nil
	}

	return strings.Replace(versions[version.Major-4],
		"{patch}",
		strconv.FormatUint(version.Patch, 10),
		1), nil
}

var versions = []string{
	"OS X 10.0.{patch} Cheetah",
	"OS X 10.1.{patch} Puma",
	"OS X 10.2.{patch} Jaguar",
	"OS X 10.3.{patch} Panther",
	"OS X 10.4.{patch} Tiger",
	"OS X 10.5.{patch} Leopard",
	"OS X 10.6.{patch} Snow Leopard",
	"OS X 10.7.{patch} Lion",
	"OS X 10.8.{patch} Mountain Lion",
	"OS X 10.9.{patch} Mavericks",
	"OS X 10.10.{patch} Yosemite",
	"OS X 10.11.{patch} El Capitan",
}
