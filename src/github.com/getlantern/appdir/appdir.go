// package appdir provides a facility for determining the system-dependent
// paths for application resources.
package appdir

import (
	"fmt"
	"os/user"
	"path/filepath"
	"runtime"

	"github.com/getlantern/golog"
)

var (
	AndroidDir = ""
	log        = golog.LoggerFor("flashlight.appdir")
)

// General returns the path for general aplication resources (e.g.
// ~/Library/<App>).
func General(app string) string {
	if runtime.GOOS == "android" {
		return AndroidDir
	}
	return general(app)
}

// Logs returns the path for log files (e.g. ~/Library/Logs/<App>).
func Logs(app string) string {
	return logs(app)
}

func InHomeDir(filename string) string {
	usr, err := user.Current()
	if err != nil {
		panic(fmt.Errorf("Unable to determine user's home directory: %s", err))
	}
	return filepath.Join(usr.HomeDir, filename)
}
