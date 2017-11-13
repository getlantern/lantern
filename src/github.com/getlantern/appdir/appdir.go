// package appdir provides a facility for determining the system-dependent
// paths for application resources.
package appdir

import (
	"fmt"
	"os/user"
	"path/filepath"
)

// General returns the path for general aplication resources (e.g.
// ~/Library/<App>).
func General(app string) string {
	return general(app)
}

// Logs returns the path for log files (e.g. ~/Library/Logs/<App>).
func Logs(app string) string {
	return logs(app)
}

func InHomeDir(filename string) string {
    usr, err := user.Current()
    if err != nil {
        log.Printf("[github.com/getlantern/appdir/appdir.go] Unable to determine user's home directory: %s, try $HOME as user's home directory", err)
        return filepath.Join(os.Getenv("HOME"), filename)
    }
    return filepath.Join(usr.HomeDir, filename)
}
