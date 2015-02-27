package main

import (
	"fmt"
	"path/filepath"

	"github.com/getlantern/filepersist"
	"github.com/getlantern/pac"

	"github.com/getlantern/flashlight/proxiedsites"
)

func setUpPacTool() bool {
	// We have to use a short filepath here because Cocoa won't display the
	// icon if the path is too long.
	iconFile := filepath.Join("/tmp", "escalatelantern.ico")
	icon, err := Asset("icons/32on.ico")
	if err != nil {
		log.Errorf("Unable to load escalation prompt icon: %v", err)
	} else {
		err := filepersist.Save(iconFile, icon, 0644)
		if err != nil {
			log.Errorf("Unable to persist icon to disk: %v", err)
		} else {
			log.Debugf("Saved icon file to: %v", iconFile)
		}
	}
	err = pac.EnsureHelperToolPresent("pac-cmd", "Lantern would like to set itself as your system proxy", iconFile)
	if err != nil {
		log.Errorf("Unable to set up pac setting tool: %v", err)
		return false
	}
	return true
}

func pacOn() {
	if proxiedsites.PACURL != "" {
		log.Debug("Setting lantern as system proxy")
		err := pac.On(proxiedsites.PACURL)
		if err != nil {
			log.Errorf("Unable to unset lantern as system proxy: %v", err)
			panic(fmt.Errorf("Unable to set Lantern as system proxy: %v", err))
		}
	}
}

func pacOff() {
	if proxiedsites.PACURL != "" {
		log.Debug("Unsetting lantern as system proxy")
		err := pac.Off()
		if err != nil {
			log.Errorf("Unable to unset lantern as system proxy: %v", err)
		}
	}
}
