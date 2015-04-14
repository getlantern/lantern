// Package launcher configures Lantern to run on system start
package launcher

import (
	"github.com/kardianos/osext"
	"github.com/luisiturrios/gowin"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("launcher")
)

func CreateLaunchFile(autoLaunch bool) {
	var err error
	RunDir := `Software\Microsoft\Windows\CurrentVersion\Run`

	if autoLaunch {
		lanternPath, err := osext.Executable()
		if err != nil {
			log.Errorf("Could not get Lantern directory path: %q", err)
			return
		}
		err = gowin.WriteStringReg("HKCU", RunDir, "value", lanternPath)
		if err != nil {
			log.Errorf("Error inserting Lantern auto-start registry key: %q", err)
		}
	} else {
		err = gowin.DeleteKey("HKCU", RunDir, "value")
		if err != nil {
			log.Errorf("Error removing Lantern auto-start registry key: %q", err)
		}
	}
}
