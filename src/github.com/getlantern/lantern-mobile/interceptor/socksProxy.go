/*
* Copyright (c) 2015, Psiphon Inc.
* All rights reserved.
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
 */

package interceptor

import (
	"bufio"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"sync"
	"syscall"

	"github.com/getlantern/lantern-mobile/protected"

	socks "github.com/Psiphon-Inc/goptlib"
)

// SocksProxy is a SOCKS server that accepts local host connections
// and, for each connection, establishes a port forward through
// the tunnel SSH client and relays traffic through the port
// forward.
type SocksProxy struct {
	interceptor            *Interceptor
	listener               *socks.SocksListener
	serveWaitGroup         *sync.WaitGroup
	openConns              *Conns
	conns                  map[string]net.Conn
	stopListeningBroadcast chan struct{}
}

type Conns struct {
	mutex    sync.Mutex
	isClosed bool
	conns    map[net.Conn]bool
}

func (conns *Conns) Reset() {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	conns.isClosed = false
	conns.conns = make(map[net.Conn]bool)
}

func (conns *Conns) Add(conn net.Conn) bool {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	if conns.isClosed {
		return false
	}
	if conns.conns == nil {
		conns.conns = make(map[net.Conn]bool)
	}
	conns.conns[conn] = true
	return true
}

func (conns *Conns) Remove(conn net.Conn) {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	delete(conns.conns, conn)
}

func (conns *Conns) CloseAll() {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	conns.isClosed = true
	for conn, _ := range conns.conns {
		conn.Close()
	}
	conns.conns = make(map[net.Conn]bool)
}

func Relay(localConn, remoteConn net.Conn) {
	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		io.Copy(localConn, remoteConn)
		wg.Done()
	}()
	go func() {
		io.Copy(remoteConn, localConn)
		wg.Done()
	}()

	wg.Wait()
}

// IsAddressInUseError returns true when the err is due to EADDRINUSE/WSAEADDRINUSE.
func IsAddressInUseError(err error) bool {
	if err, ok := err.(*net.OpError); ok {
		if err, ok := err.Err.(*os.SyscallError); ok {
			if err.Err == syscall.EADDRINUSE {
				return true
			}
			// Special case for Windows (WSAEADDRINUSE = 10048)
			if errno, ok := err.Err.(syscall.Errno); ok {
				if 10048 == int(errno) {
					return true
				}
			}
		}
	}
	return false
}

// NewSocksProxy initializes a new SOCKS server. It begins listening for
// connections, starts a goroutine that runs an accept loop, and returns
// leaving the accept loop running.
func NewSocksProxy(i *Interceptor) (proxy *SocksProxy, err error) {
	listener, err := socks.ListenSocks(
		"tcp", i.socksAddr)
	if err != nil {
		if IsAddressInUseError(err) {
			log.Errorf("SOCKS proxy port in use")
		}
		return nil, err
	}
	proxy = &SocksProxy{
		interceptor:    i,
		listener:       listener,
		serveWaitGroup: new(sync.WaitGroup),
		openConns:      new(Conns),
		conns:          map[string]net.Conn{},
		stopListeningBroadcast: make(chan struct{}),
	}
	proxy.serveWaitGroup.Add(1)
	go proxy.serve()
	log.Debugf("SOCKS proxy now listening on port: %v",
		proxy.listener.Addr().(*net.TCPAddr).Port)
	return proxy, nil
}

// Close terminates the listener and waits for the accept loop
// goroutine to complete.
func (proxy *SocksProxy) Close() {
	close(proxy.stopListeningBroadcast)
	proxy.listener.Close()
	proxy.serveWaitGroup.Wait()
	proxy.openConns.CloseAll()
}

func (proxy *SocksProxy) socksConnectionHttpHandler(localConn *socks.SocksConn) (err error) {
	defer localConn.Close()
	defer proxy.openConns.Remove(localConn)

	if proxy.conns[localConn.Req.Target] != nil {
		// existing connection
		Relay(localConn, proxy.conns[localConn.Req.Target])
		return nil
	}

	if localConn.Req.Target == "104.131.157.209:7300" {
		log.Debugf("UDP request....")
		return proxy.socksConnectionHandler(localConn)
	}

	conn, err := protected.New(proxy.interceptor.protector, proxy.interceptor.httpAddr)
	if err != nil {
		log.Errorf("Error creating protected connection: %v", err)
		return err
	}
	defer conn.Close()

	remoteConn, err := conn.Dial()
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		return err
	}
	defer remoteConn.Close()

	log.Debugf("Creating CONNECT request to %s", localConn.Req.Target)
	connReq := &http.Request{
		Method: "CONNECT",
		URL:    &url.URL{Opaque: localConn.Req.Target},
		Host:   localConn.Req.Target,
		Header: make(http.Header),
	}
	connReq.Write(remoteConn)

	br := bufio.NewReader(remoteConn)
	resp, err := http.ReadResponse(br, connReq)

	if err != nil {
		log.Errorf("Error processing CONNECT response: %v", err)
		conn.Close()
		return err
	}
	if resp.StatusCode == 200 {
		log.Debugf("Successfully established an HTTP tunnel with remote end-point: %s", localConn.Req.Target)

		if err := remoteConn.(*net.TCPConn).SetKeepAlive(true); err != nil {
			log.Errorf("Could not set keep alive on connection: %s", localConn.Req.Target)
		}
		addr, err := conn.Addr()
		if err != nil {
			log.Errorf("Could not resolve address: %v", err)
			return err
		}

		proxy.conns[localConn.Req.Target] = localConn
		err = localConn.Grant(addr)
		if err != nil {
			log.Errorf("Error granting access to connection: %v", err)
			return err
		}
		Relay(localConn, remoteConn)
	} else {
		log.Errorf("Got invalid HTTP response code: %v", resp.StatusCode)
	}
	return nil
}

func (proxy *SocksProxy) socksConnectionHandler(localConn *socks.SocksConn) (err error) {
	defer localConn.Close()
	defer proxy.openConns.Remove(localConn)

	if proxy.conns[localConn.Req.Target] != nil {
		// existing connection
		Relay(localConn, proxy.conns[localConn.Req.Target])
		return nil
	}

	host, port, err := protected.SplitHostPort(localConn.Req.Target)
	if err != nil {
		log.Errorf("Could not extract IP Address: %v", err)
		return err
	}

	conn, err := protected.New(proxy.interceptor.protector, localConn.Req.Target)
	if err != nil {
		log.Errorf("Error creating protected connection: %v", err)
		return err
	}
	defer conn.Close()
	log.Debugf("Connecting to %s:%d", host, port)

	remoteConn, err := conn.Dial()
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		return err
	}
	defer remoteConn.Close()
	addr, err := conn.Addr()
	if err != nil {
		log.Errorf("Could not resolve address: %v", err)
		return err
	}

	//proxy.conns[localConn.Req.Target] = localConn
	err = localConn.Grant(addr)
	if err != nil {
		log.Errorf("Error granting access to connection: %v", err)
		return err
	}
	Relay(localConn, remoteConn)
	return nil
}

func (proxy *SocksProxy) serve() {
	defer proxy.listener.Close()
	defer proxy.serveWaitGroup.Done()
loop:
	for {
		// Note: will be interrupted by listener.Close() call made by proxy.Close()
		socksConnection, err := proxy.listener.AcceptSocks()
		// Can't check for the exact error that Close() will cause in Accept(),
		// (see: https://code.google.com/p/go/issues/detail?id=4373). So using an
		// explicit stop signal to stop gracefully.
		select {
		case <-proxy.stopListeningBroadcast:
			break loop
		default:
		}
		if err != nil {
			log.Errorf("SOCKS proxy accept error: %v", err)
			if e, ok := err.(net.Error); ok && e.Temporary() {
				// Temporary error, keep running
				continue
			}
			// Fatal error, stop the proxy
			log.Fatalf("Fatal component failure: %v", err)
			break loop
		}
		go func() {
			log.Debugf("Got a new connection: %v", socksConnection)
			err := proxy.socksConnectionHandler(socksConnection)
			if err != nil {
				log.Errorf("%v", err)
			}
		}()
	}
	log.Debugf("SOCKS proxy stopped")
}
