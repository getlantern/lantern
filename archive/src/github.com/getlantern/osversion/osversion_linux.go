// +build !android

package osversion

import (
	"C"
	"errors"
	"fmt"
	"io/ioutil"
	"regexp"
	"syscall"
)

func GetString() (string, error) {
	var uts syscall.Utsname
	err := syscall.Uname(&uts)
	if err != nil {
		return "", errors.New(fmt.Sprintf("Error calling system function 'uname': %s", err))
	}

	// Due to a mismatch in the uts.Release types depending on the architecture, we are
	// forced to implement it right here to bypass Go's type checking of slices
	utsRelease := uts.Release[:]
	s := make([]byte, len(utsRelease))
	strpos := 0
	for strpos < len(utsRelease) {
		if utsRelease[strpos] == 0 {
			break
		}
		s[strpos] = uint8(utsRelease[strpos])
		strpos++
	}

	return fmt.Sprintf("%s", string(s[:strpos])), nil
}

func GetHumanReadable() (string, error) {
	// Kernel version
	kernel, err := GetString()
	if err != nil {
		return "", err
	}

	// Try to get the distribution info
	fData, err := ioutil.ReadFile("/etc/os-release")
	if err != nil {
		return fmt.Sprintf("kernel: %s", kernel), nil
	}

	// At least Fedora, Debian, Ubuntu and Arch support this approach
	// and provide the PRETTY_NAME field
	reg1 := regexp.MustCompile("PRETTY_NAME=\".+\"")
	reg2 := regexp.MustCompile("\".+\"")
	dstrBytes := reg2.Find(reg1.Find(fData))
	distribution := string(dstrBytes[1 : len(dstrBytes)-1])

	return fmt.Sprintf("%s kernel: %s", distribution, kernel), nil
}
