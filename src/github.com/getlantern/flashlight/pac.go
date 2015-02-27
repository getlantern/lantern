package main

import (
	"fmt"
	"path/filepath"
	"sync/atomic"

	"github.com/getlantern/filepersist"
	"github.com/getlantern/pac"

	"github.com/getlantern/flashlight/proxiedsites"
)

var (
	isPacOn = int32(0)
)

func setUpPacTool() error {
	// We have to use a short filepath here because Cocoa won't display the
	// icon if the path is too long.
	iconFile := filepath.Join("/tmp", "escalatelantern.ico")
	icon, err := Asset("icons/32on.ico")
	if err != nil {
		return fmt.Errorf("Unable to load escalation prompt icon: %v", err)
	} else {
		err := filepersist.Save(iconFile, icon, 0644)
		if err != nil {
			return fmt.Errorf("Unable to persist icon to disk: %v", err)
		} else {
			log.Debugf("Saved icon file to: %v", iconFile)
		}
	}
	err = pac.EnsureHelperToolPresent("pac-cmd", "Lantern would like to be your system proxy", iconFile)
	if err != nil {
		return fmt.Errorf("Unable to set up pac setting tool: %v", err)
	}
	return nil
}

func pacOn() {
	if proxiedsites.PACURL != "" {
		log.Debug("Setting lantern as system proxy")
		err := pac.On(proxiedsites.PACURL)
		if err != nil {
			log.Errorf("Unable to set lantern as system proxy: %v", err)
			return
		}
		atomic.StoreInt32(&isPacOn, 1)
	}
}

func pacOff() {
	if atomic.LoadInt32(&isPacOn) == 1 {
		log.Debug("Unsetting lantern as system proxy")
		err := pac.Off()
		if err != nil {
			log.Errorf("Unable to unset lantern as system proxy: %v", err)
		}
		log.Debug("Unset lantern as system proxy")
	}
}
