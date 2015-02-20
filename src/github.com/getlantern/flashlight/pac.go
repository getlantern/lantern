package main

import (
	"fmt"
	"io/ioutil"

	"github.com/getlantern/pac"

	"github.com/getlantern/flashlight/proxiedsites"
)

func pacOn() {
	if proxiedsites.PACURL != "" {
		iconFile := ""
		icon, err := Asset("icons/64on.ico")
		if err != nil {
			log.Errorf("Unable to get escalation prompt icon: %v", err)
		} else {
			f, err := ioutil.TempFile("", "")
			if err != nil {
				log.Errorf("Unable to create temp file for icon: %v", err)
			} else {
				defer f.Close()
				_, err := f.Write(icon)
				if err != nil {
					log.Errorf("Unable to write icon to temp file: %v", err)
				} else {
					f.Close()
					iconFile = f.Name()
				}
			}
		}
		err = pac.EnsureHelperToolPresent("pac-cmd", "Lantern would like to set itself as your system proxy", iconFile)
		if err != nil {
			panic(err)
		}
		log.Debug("Setting lantern as system proxy")
		err = pac.On(proxiedsites.PACURL)
		if err != nil {
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
