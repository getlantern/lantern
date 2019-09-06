package server

import (
	"sync"

	"github.com/getlantern/http-proxy/listeners"
)

// connBag is a just bag of connections. You can put a connection in and
// withdraw it afterwards, or purge it regardless it's withdrawed or not.
type connBag struct {
	mu sync.Mutex
	m  map[string]listeners.WrapConn
}

func NewConnBag() *connBag {
	return &connBag{m: make(map[string]listeners.WrapConn)}
}

func (cb *connBag) Put(c listeners.WrapConn) {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	cb.m[c.RemoteAddr().String()] = c
}

func (cb *connBag) Withdraw(remoteAddr string) (c listeners.WrapConn) {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	c = cb.m[remoteAddr]
	delete(cb.m, remoteAddr)
	return
}

func (cb *connBag) Purge(remoteAddr string) {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	// non-op if item doesn't exist
	delete(cb.m, remoteAddr)
}
