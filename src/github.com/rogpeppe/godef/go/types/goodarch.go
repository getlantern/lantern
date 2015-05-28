package types

import (
	"runtime"
	"strings"
)

// Code for determining system-specific files stolen from
// goinstall. We can't automatically generate goosList and
// goarchList if this package is to remain goinstallable.

const goosList = "darwin freebsd linux plan9 windows "
const goarchList = "386 amd64 arm "

// goodOSArch returns false if the filename contains a $GOOS or $GOARCH
// suffix which does not match the current system.
// The recognized filename formats are:
//
//     name_$(GOOS).*
//     name_$(GOARCH).*
//     name_$(GOOS)_$(GOARCH).*
//
func goodOSArch(filename string) (ok bool) {
	if dot := strings.Index(filename, "."); dot != -1 {
		filename = filename[:dot]
	}
	l := strings.Split(filename, "_")
	n := len(l)
	if n == 0 {
		return true
	}
	if good, known := goodOS[l[n-1]]; known {
		return good
	}
	if good, known := goodArch[l[n-1]]; known {
		if !good || n < 2 {
			return false
		}
		good, known = goodOS[l[n-2]]
		return good || !known
	}
	return true
}

var goodOS = make(map[string]bool)
var goodArch = make(map[string]bool)

func init() {
	goodOS = make(map[string]bool)
	goodArch = make(map[string]bool)
	for _, v := range strings.Fields(goosList) {
		goodOS[v] = v == runtime.GOOS
	}
	for _, v := range strings.Fields(goarchList) {
		goodArch[v] = v == runtime.GOARCH
	}
}
