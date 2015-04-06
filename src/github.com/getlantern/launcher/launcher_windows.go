// Package launcher configures Lantern to run on system start
package launcher

import (
	"os"
	"path/filepath"

	"github.com/luisiturrios/gowin"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("launcher")
)

func CreateLaunchFile(autoLaunch bool) {
	var err error
	if autoLaunch {
		lanternPath := filepath.Join(os.Getenv("SYSTEMROOT"), "Lantern", "lantern.exe")
		err = gowin.WriteStringReg("HKCU", "Lantern", "value", lanternPath)
		if err != nil {
			log.Errorf("Error inserting Lantern auto-start registry key: %q", err)
		}
	} else {
		err = gowin.DeleteKey("HKCU", "", "Lantern")
		if err != nil {
			log.Errorf("Error removing Lantern auto-start registry key: %q", err)
		}
	}
}
