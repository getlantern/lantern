package detour

import (
	"sync"
	"time"
)

type wlEntry struct {
	permanent bool
	addTime   time.Time
}

var (
	muWhitelist sync.RWMutex
	whitelist   = make(map[string]wlEntry)
)

func InitWhitelist(wl map[string]time.Time) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	for k, v := range wl {
		whitelist[k] = wlEntry{true, v}
	}
	return
}

func DumpWhitelist() (wl map[string]time.Time) {
	wl = make(map[string]time.Time)
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	for k, v := range whitelist {
		wl[k] = v.addTime
	}
	return
}

func whitelisted(addr string) bool {
	muWhitelist.RLock()
	defer muWhitelist.RUnlock()
	_, in := whitelist[addr]
	return in
}

func wlTemporarily(addr string) bool {
	muWhitelist.RLock()
	defer muWhitelist.RUnlock()
	p, ok := whitelist[addr]
	return ok && p.permanent == false
}

func addToWl(addr string, permanent bool) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	whitelist[addr] = wlEntry{permanent, time.Now()}
}

func removeFromWl(addr string) {
	muWhitelist.Lock()
	defer muWhitelist.Unlock()
	delete(whitelist, addr)
}
