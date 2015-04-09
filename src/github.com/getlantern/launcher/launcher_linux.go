// Package launcher configures Lantern to run on system start
package launcher

import (
	"github.com/getlantern/golog"
	"github.com/takama/daemon"
)

var (
	log = golog.LoggerFor("launcher")
)

func CreateLaunchFile(autoLaunch bool) {

	service, err := daemon.New("name", "lantern")
	if err != nil {
		log.Errorf("Could not create new daemon: %q", err)
		return
	}

	if autoLaunch {
		status, err := service.Status()
		if err == nil {
			log.Debugf("Service already installed")
			return
		}
		status, err = service.Install()
		if err != nil {
			log.Errorf("Could not install service: %q", err)
			return
		}
		log.Debugf("Successfully installed new service: %s", status)
	} else {
		status, err := service.Remove()
		if err != nil {
			log.Errorf("Could not remove service: %q", err)
			return
		}
		log.Debugf("Successfully removed Lantern service: %s", status)
	}
}
