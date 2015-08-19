package detour

import (
	"strings"
	"sync"
)

type wlEntry struct {
	permanent bool
}

var (
	muWhitelist sync.RWMutex
	whitelist   = make(map[string]wlEntry)
)

// AddToWl adds a domain to whitelist, all subdomains of this domain
// are also considered to be in the whitelist.
func AddToWl(addr string, permanent bool) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	if addr != "" {
		whitelist[addr] = wlEntry{permanent}
	}
}

//RemoveFromWl removes an addr from whitelist
func RemoveFromWl(addr string) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	delete(whitelist, addr)
}

//DumpWhitelist dumps the whitelist for other usage
func DumpWhitelist() (wl []string) {
	wl = make([]string, 1)
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	for k, v := range whitelist {
		if v.permanent {
			wl = append(wl, k)
		}
	}
	return
}

func whitelisted(addr string) (in bool) {
	muWhitelist.RLock()
	defer muWhitelist.RUnlock()
	for ; addr != ""; addr = getParentDomain(addr) {
		_, in = whitelist[addr]
		if in {
			return
		}
	}
	return
}

func wlTemporarily(addr string) bool {
	muWhitelist.RLock()
	defer muWhitelist.RUnlock()
	// temporary domains are always full ones, just check map
	p, ok := whitelist[addr]
	return ok && p.permanent == false
}

func getParentDomain(addr string) string {
	parts := strings.SplitN(addr, ".", 2)
	if len(parts) < 2 {
		return ""
	}
	return parts[1]
}
