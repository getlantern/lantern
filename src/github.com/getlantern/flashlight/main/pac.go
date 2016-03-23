package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"text/template"
	"time"

	"github.com/getlantern/detour"
	"github.com/getlantern/filepersist"
	"github.com/getlantern/pac"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/ui"
)

var (
	bypassPAC   = false
	isPacOn     = int32(0)
	pacURL      string
	directHosts = make(map[string]bool)
	cfgMutex    sync.RWMutex
)

func ServePACFile() {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()
	if pacURL == "" {
		pacURL = ui.Handle("/proxy_on.pac", http.HandlerFunc(servePACFile))
	}
}

func servePACFile(resp http.ResponseWriter, req *http.Request) {
	log.Trace("Serving PAC file")
	resp.Header().Set("Content-Type", "application/x-ns-proxy-autoconfig")
	resp.WriteHeader(http.StatusOK)
	cfgMutex.RLock()
	defer cfgMutex.RUnlock()
	if _, err := genPACFile(resp); err != nil {
		log.Debugf("Error writing response: %v", err)
	}
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

func genPACFile(w io.Writer) (int, error) {
	var hosts []string

	// only bypass sites if proxy all option is unset
	if !settings.GetProxyAll() {
		log.Trace("Not proxying all")
		for k, v := range directHosts {
			if v {
				hosts = append(hosts, k)
			}
		}
	} else {
		log.Trace("Proxying all")
	}

	hosts = []string{}

	formatter := `
		var bypassDomains = {{ .BypassDomains | json }};
		var bypassPAC = {{ .BypassPAC | json }};

		function FindProxyForURL(url, host) {
			if (isPlainHostName(host) // including localhost
			|| shExpMatch(host, "*.local") || bypassPAC) {
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
			// Lantern desktop version proxies only http(s) and ws(s)
			if (url.substring(0, 4) != 'http' && (url.substring(0, 2) != 'ws')) {
				return "DIRECT";
			}
			for (var d in bypassDomains) {
				if (host == bypassDomains[d]) {
					return "DIRECT";
				}
			}
			return "PROXY {{.ProxyAddr}}; DIRECT";
		}
	`

	tpl := template.Must(template.New("pac").Funcs(map[string]interface{}{
		"json": func(in interface{}) (string, error) {
			b, err := json.Marshal(in)
			if err != nil {
				return "", err
			}
			return string(b), nil
		},
	}).Parse(formatter))

	proxyAddr, ok := client.Addr(5 * time.Minute)
	if !ok {
		panic("Unable to get proxy address within 5 minutes")
	}
	log.Tracef("Setting proxy address to %v", proxyAddr)

	buf := bytes.NewBuffer(nil)
	err := tpl.Execute(buf, struct {
		BypassPAC     bool
		BypassDomains []string
		ProxyAddr     string
	}{
		bypassPAC,
		hosts,
		proxyAddr.(string),
	})
	if err != nil {
		return 0, err
	}

	return w.Write(buf.Bytes())
}

// watchDirectAddrs adds any site that has accessed directly without error to PAC file
func watchDirectAddrs() {
	go func() {
		for {
			addr := <-detour.DirectAddrCh
			host, _, err := net.SplitHostPort(addr)
			if err != nil {
				panic("watchDirectAddrs() got malformated host:port pair")
			}
			addDirectHost(host)
		}
	}()
}

func addDirectHost(host string) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()
	if !directHosts[host] {
		directHosts[host] = true
		cyclePAC()
	}
}

func pacOn() {
	log.Debug("Setting lantern as system proxy")
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

func cyclePAC() {
	// prevents Lantern from accidently leave pac on after exits
	if atomic.LoadInt32(&isPacOn) == 1 {
		// reapply so browser will fetch the PAC URL again
		doPACOff(pacURL)
		doPACOn(pacURL)
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
