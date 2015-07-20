package main

import (
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/getlantern/detour"
	"github.com/getlantern/filepersist"
	"github.com/getlantern/pac"

	"github.com/getlantern/flashlight/ui"
)

var (
	isPacOn     = int32(0)
	proxyAddr   string
	pacURL      string
	muPACFile   sync.RWMutex
	pacFile     []byte
	directHosts = make(map[string]bool)
	proxyAll    = int32(0)
)

func ServeProxyAllPacFile(b bool) {
	if b {
		atomic.StoreInt32(&proxyAll, 1)
	} else {
		atomic.StoreInt32(&proxyAll, 0)
	}
	genPACFile()
}

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
	proxyAddr = addr
}

func genPACFile() {
	hostsString := "[]"
	// only bypass sites if proxy all option is unset
	if atomic.LoadInt32(&proxyAll) == 0 {
		var hosts []string
		for k, v := range directHosts {
			if v {
				hosts = append(hosts, k)
			}
		}
		hostsString = "['" + strings.Join(hosts, "', '") + "']"
	}
	formatter :=
		`var bypassDomains = %s;
		function FindProxyForURL(url, host) {
			if (host == "localhost" || host == "127.0.0.1") {
				return "DIRECT";
			}
			for (var d in bypassDomains) {
				if (host == bypassDomains[d]) {
					return "DIRECT";
				}
			}
			return "PROXY %s; DIRECT";
		}`
	muPACFile.Lock()
	pacFile = []byte(fmt.Sprintf(formatter, hostsString, proxyAddr))
	muPACFile.Unlock()
}

// watchDirectAddrs adds any site that has accessed directly without error to PAC file
func watchDirectAddrs() {
	detour.DirectAddrCh = make(chan string)
	go func() {
		for {
			addr := <-detour.DirectAddrCh
			// prevents Lantern from accidently leave pac on after exits
			if atomic.LoadInt32(&isPacOn) == 0 {
				return
			}
			host, _, err := net.SplitHostPort(addr)
			if err != nil {
				panic("watchDirectAddrs() got malformated host:port pair")
			}
			if !directHosts[host] {
				directHosts[host] = true
				genPACFile()
				// reapply so browser will fetch the PAC URL again
				doPACOff()
				doPACOn()
			}
		}
	}()
}

func pacOn() {
	log.Debug("Setting lantern as system proxy")
	handler := func(resp http.ResponseWriter, req *http.Request) {
		resp.Header().Set("Content-Type", "application/x-ns-proxy-autoconfig")
		resp.WriteHeader(http.StatusOK)
		muPACFile.RLock()
		resp.Write(pacFile)
		muPACFile.RUnlock()
	}
	genPACFile()
	pacURL = ui.Handle("/proxy_on.pac", http.HandlerFunc(handler))
	log.Debugf("Serving PAC file at %v", pacURL)
	doPACOn()
	atomic.StoreInt32(&isPacOn, 1)
}

func pacOff() {
	if atomic.CompareAndSwapInt32(&isPacOn, 1, 0) {
		log.Debug("Unsetting lantern as system proxy")
		doPACOff()
		log.Debug("Unset lantern as system proxy")
	}
}

func doPACOn() {
	err := pac.On(pacURL)
	if err != nil {
		log.Errorf("Unable to set lantern as system proxy: %v", err)
	}
}

func doPACOff() {
	err := pac.Off()
	if err != nil {
		log.Errorf("Unable to unset lantern as system proxy: %v", err)
	}
}
