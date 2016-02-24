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
	"time"

	"github.com/getlantern/detour"
	"github.com/getlantern/filepersist"
	"github.com/getlantern/pac"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/ui"
)

var (
	isPacOn        = int32(0)
	pacURL         string
	muPACFile      sync.RWMutex
	pacFile        []byte
	directHosts    = make(map[string]bool)
	shouldProxyAll = int32(0)
)

func ServeProxyAllPacFile(b bool) {
	if b {
		atomic.StoreInt32(&shouldProxyAll, 1)
	} else {
		atomic.StoreInt32(&shouldProxyAll, 0)
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

func genPACFile() {
	hostsString := "[]"
	// only bypass sites if proxy all option is unset
	if atomic.LoadInt32(&shouldProxyAll) == 0 {
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
			if (isPlainHostName(host) // including localhost
			|| shExpMatch(host, "*.local")) {
				return "DIRECT";
			}
			// only checks plain IP addresses to avoid leaking domain name
			if (/^[0-9.]+$/.test(host)) {
				if (isInNet(host, "10.0.0.0", "255.0.0.0") ||
				isInNet(host, "172.16.0.0",  "255.240.0.0") ||
				isInNet(host, "192.168.0.0",  "255.255.0.0") ||
				isInNet(host, "127.0.0.0", "255.255.255.0")) {
					return "DIRECT";
				}
			}
			// Lantern desktop version proxies only http and https
			if (url.substring(0, 4) != 'http') {
				return "DIRECT";
			}
			for (var d in bypassDomains) {
				if (host == bypassDomains[d]) {
					return "DIRECT";
				}
			}
			return "PROXY %s; DIRECT";
		}`
	proxyAddr, ok := client.Addr(5 * time.Minute)
	if !ok {
		panic("Unable to get proxy address within 5 minutes")
	}
	proxyAddrString := proxyAddr.(string)
	log.Debugf("Setting proxy address to %v", proxyAddrString)
	muPACFile.Lock()
	pacFile = []byte(fmt.Sprintf(formatter, hostsString, proxyAddrString))
	muPACFile.Unlock()
}

// watchDirectAddrs adds any site that has accessed directly without error to PAC file
func watchDirectAddrs() {
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
				doPACOff(pacURL)
				doPACOn(pacURL)
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
		if _, err := resp.Write(pacFile); err != nil {
			log.Debugf("Error writing response: %v", err)
		}
		muPACFile.RUnlock()
	}
	genPACFile()
	pacURL = ui.Handle("/proxy_on.pac", http.HandlerFunc(handler))
	log.Debugf("Serving PAC file at %v", pacURL)
	doPACOn(pacURL)
	atomic.StoreInt32(&isPacOn, 1)
}

func pacOff() {
	if atomic.CompareAndSwapInt32(&isPacOn, 1, 0) {
		log.Debug("Unsetting lantern as system proxy")
		doPACOff(pacURL)
		log.Debug("Unset lantern as system proxy")
	}
}

func doPACOn(pacURL string) {
	err := pac.On(pacURL)
	if err != nil {
		log.Errorf("Unable to set lantern as system proxy: %v", err)
	}
}

func doPACOff(pacURL string) {
	err := pac.Off(pacURL)
	if err != nil {
		log.Errorf("Unable to unset lantern as system proxy: %v", err)
	}
}
