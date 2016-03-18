package detour

import (
	"strings"
	"sync"
)

type wlEntry struct {
	permanent bool
}

var (
	muWhitelist    sync.RWMutex
	whitelist      = make(map[string]wlEntry)
	forceWhitelist = make(map[string]wlEntry)
)

func ForceWhitelist(addr string) {
	log.Tracef("Force whitelisting %v", addr)
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	forceWhitelist[addr] = wlEntry{true}
}

// AddToWl adds a domain to whitelist, all subdomains of this domain
// are also considered to be in the whitelist.
func AddToWl(addr string, permanent bool) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	whitelist[addr] = wlEntry{permanent}
}

func RemoveFromWl(addr string) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	delete(whitelist, addr)
}

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
		_, forced := forceWhitelist[addr]
		if forced {
			log.Tracef("%v is force whitelisted", addr)
			return true
		}
		_, whitelisted := whitelist[addr]
		if whitelisted {
			log.Tracef("%v is whitelisted", addr)
			return true
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
