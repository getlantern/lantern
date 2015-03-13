package main

import (
	"fmt"
	"net/http"
	"path/filepath"
	"runtime"
	"sync/atomic"

	"github.com/getlantern/filepersist"
	"github.com/getlantern/pac"

	"github.com/getlantern/flashlight/ui"
)

var (
	isPacOn = int32(0)
	pacURL  string
	pacFile []byte
)

func setUpPacTool() error {
	var iconFile string
	if runtime.GOOS == "darwin" {
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
	}
	err := pac.EnsureHelperToolPresent("pac-cmd", "Lantern would like to be your system proxy", iconFile)
	if err != nil {
		return fmt.Errorf("Unable to set up pac setting tool: %v", err)
	}
	return nil
}

func setProxyAddr(addr string) {
	formatter := `function FindProxyForURL(url, host) {
  if (host == "localhost" || host == "127.0.0.1") {
       return "DIRECT";
  }
  return "PROXY %s; DIRECT";
}
`
	pacFile = []byte(fmt.Sprintf(formatter, addr))
}

func pacOn() {
	log.Debug("Setting lantern as system proxy")
	handler := func(resp http.ResponseWriter, req *http.Request) {
		resp.Header().Set("Content-Type", "application/x-ns-proxy-autoconfig")
		resp.WriteHeader(http.StatusOK)
		resp.Write(pacFile)
	}

	pacURL = ui.Handle("/proxy_on.pac", http.HandlerFunc(handler))
	log.Debugf("Serving PAC file at %v", pacURL)
	err := pac.On(pacURL)
	if err != nil {
		log.Errorf("Unable to set lantern as system proxy: %v", err)
		return
	}
	atomic.StoreInt32(&isPacOn, 1)
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
