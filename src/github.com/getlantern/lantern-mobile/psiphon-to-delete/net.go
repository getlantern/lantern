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

package psiphon

import (
	"io"
	"net"
	"sync"
	"time"

	"github.com/Psiphon-Inc/dns"
)

const DNS_PORT = 53

// DialConfig contains parameters to determine the behavior
// of a Psiphon dialer (TCPDial, MeekDial, etc.)
type DialConfig struct {

	// UpstreamProxyUrl specifies a proxy to connect through.
	// E.g., "http://proxyhost:8080"
	//       "socks5://user:password@proxyhost:1080"
	//       "socks4a://proxyhost:1080"
	//       "http://NTDOMAIN\NTUser:password@proxyhost:3375"
	//
	// Certain tunnel protocols require HTTP CONNECT support
	// when a HTTP proxy is specified. If CONNECT is not
	// supported, those protocols will not connect.
	UpstreamProxyUrl string

	ConnectTimeout time.Duration

	// PendingConns is used to interrupt dials in progress.
	// The dial may be interrupted using PendingConns.CloseAll(): on platforms
	// that support this, the new conn is added to pendingConns before the network
	// connect begins and removed from pendingConns once the connect succeeds or fails.
	PendingConns *Conns

	// BindToDevice parameters are used to exclude connections and
	// associated DNS requests from VPN routing.
	// When DeviceBinder is set, any underlying socket is
	// submitted to the device binding servicebefore connecting.
	// The service should bind the socket to a device so that it doesn't route
	// through a VPN interface. This service is also used to bind UDP sockets used
	// for DNS requests, in which case DnsServerGetter is used to get the
	// current active untunneled network DNS server.
	DeviceBinder    DeviceBinder
	DnsServerGetter DnsServerGetter
}

// DeviceBinder defines the interface to the external BindToDevice provider
type DeviceBinder interface {
	BindToDevice(fileDescriptor int) error
}

// NetworkConnectivityChecker defines the interface to the external
// HasNetworkConnectivity provider
type NetworkConnectivityChecker interface {
	// TODO: change to bool return value once gobind supports that type
	HasNetworkConnectivity() int
}

// DnsServerGetter defines the interface to the external GetDnsServer provider
type DnsServerGetter interface {
	GetDnsServer() string
}

// TimeoutError implements the error interface
type TimeoutError struct{}

func (TimeoutError) Error() string   { return "timed out" }
func (TimeoutError) Timeout() bool   { return true }
func (TimeoutError) Temporary() bool { return true }

// Dialer is a custom dialer compatible with http.Transport.Dial.
type Dialer func(string, string) (net.Conn, error)

// Conns is a synchronized list of Conns that is used to coordinate
// interrupting a set of goroutines establishing connections, or
// close a set of open connections, etc.
// Once the list is closed, no more items may be added to the
// list (unless it is reset).
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

// Relay sends to remoteConn bytes received from localConn,
// and sends to localConn bytes received from remoteConn.
func Relay(localConn, remoteConn net.Conn) {
	copyWaitGroup := new(sync.WaitGroup)
	copyWaitGroup.Add(1)
	go func() {
		defer copyWaitGroup.Done()
		_, err := io.Copy(localConn, remoteConn)
		if err != nil {
			NoticeAlert("Relay failed: %s", ContextError(err))
		}
	}()
	_, err := io.Copy(remoteConn, localConn)
	if err != nil {
		NoticeAlert("Relay failed: %s", ContextError(err))
	}
	copyWaitGroup.Wait()
}

// WaitForNetworkConnectivity uses a NetworkConnectivityChecker to
// periodically check for network connectivity. It returns true if
// no NetworkConnectivityChecker is provided (waiting is disabled)
// or if NetworkConnectivityChecker.HasNetworkConnectivity() indicates
// connectivity. It polls the checker once a second. If a stop is
// broadcast, false is returned.
func WaitForNetworkConnectivity(
	connectivityChecker NetworkConnectivityChecker, stopBroadcast <-chan struct{}) bool {
	if connectivityChecker == nil || 1 == connectivityChecker.HasNetworkConnectivity() {
		return true
	}
	NoticeInfo("waiting for network connectivity")
	ticker := time.NewTicker(1 * time.Second)
	for {
		if 1 == connectivityChecker.HasNetworkConnectivity() {
			return true
		}
		select {
		case <-ticker.C:
			// Check again
		case <-stopBroadcast:
			return false
		}
	}
}

// ResolveIP uses a custom dns stack to make a DNS query over the
// given TCP or UDP conn. This is used, e.g., when we need to ensure
// that a DNS connection bypasses a VPN interface (BindToDevice) or
// when we need to ensure that a DNS connection is tunneled.
// Caller must set timeouts or interruptibility as required for conn.
func ResolveIP(host string, conn net.Conn) (addrs []net.IP, ttls []time.Duration, err error) {

	// Send the DNS query
	dnsConn := &dns.Conn{Conn: conn}
	defer dnsConn.Close()
	query := new(dns.Msg)
	query.SetQuestion(dns.Fqdn(host), dns.TypeA)
	query.RecursionDesired = true
	dnsConn.WriteMsg(query)

	// Process the response
	response, err := dnsConn.ReadMsg()
	if err != nil {
		return nil, nil, ContextError(err)
	}
	addrs = make([]net.IP, 0)
	ttls = make([]time.Duration, 0)
	for _, answer := range response.Answer {
		if a, ok := answer.(*dns.A); ok {
			addrs = append(addrs, a.A)
			ttl := time.Duration(a.Hdr.Ttl) * time.Second
			ttls = append(ttls, ttl)
		}
	}
	return addrs, ttls, nil
}
