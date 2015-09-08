// socks implements a SOCKS server that intercepts local host connections
// and forwards them through Lantern's HTTP proxy
package interceptor

import (
	"crypto/tls"
	"errors"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/protected"
	socks "github.com/getlantern/lantern-mobile/socks"
)

const (
	udpgwServer = "104.131.157.209:7300"
)

var (
	DIAL_TIMEOUT = 15 * time.Second
	log          = golog.LoggerFor("lantern-android.interceptor")
)

type Tunneler struct {
	socksAddr string
	httpAddr  string
	protector protected.SocketProtector

	mutex    *sync.Mutex
	isClosed bool
}

type dialResult struct {
	forwardConn net.Conn
	err         error
}

type SocksProxy struct {
	tunneler               Tunneler
	listener               *socks.SocksListener
	isMasquerade           func(string) bool
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

// NewSocksProxy initializes a new SOCKS server. It begins listening for
// connections, starts a goroutine that runs an accept loop, and returns
// leaving the accept loop running.
func NewSocksProxy(protector protected.SocketProtector, socksAddr, httpAddr string, isMasquerade func(string) bool) (proxy *SocksProxy, err error) {
	listener, err := socks.ListenSocks(
		"tcp", socksAddr)
	if err != nil {
		log.Errorf("Could not start SOCKS server: %v", err)
		return nil, err
	}
	proxy = &SocksProxy{
		tunneler: Tunneler{
			mutex:     new(sync.Mutex),
			isClosed:  false,
			protector: protector,
			socksAddr: socksAddr,
			httpAddr:  httpAddr,
		},
		isMasquerade:   isMasquerade,
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

func (tunnel *Tunneler) Dial(addr string, localConn net.Conn) (net.Conn, error) {

	tunnel.mutex.Lock()
	isClosed := tunnel.isClosed
	tunnel.mutex.Unlock()

	if isClosed {
		return nil, errors.New("tunnel is closed")
	}

	conn, err := protected.New(tunnel.protector, tunnel.httpAddr)
	if err != nil {
		log.Errorf("Error creating protected connection: %v", err)
		return nil, err
	}

	_, port, err := protected.SplitHostPort(addr)
	if err != nil {
		conn.Close()
		return nil, err
	}

	resultCh := make(chan *dialResult, 2)
	time.AfterFunc(DIAL_TIMEOUT, func() {
		resultCh <- &dialResult{nil,
			errors.New("dial timoue to tunnel")}
	})

	go func() {

		log.Debugf("Creating CONNECT request to %s", addr)

		scheme := "http"
		if port == 443 {
			scheme = "https"
		}

		connReq := &http.Request{
			Method: "CONNECT",
			URL:    &url.URL{Host: addr, Scheme: scheme},
			Host:   addr,
			Header: make(http.Header),
		}

		log.Debugf("Tunneling a new request to Lantern: %s", addr)
		client := &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
				Dial: func(netw, addr string) (net.Conn, error) {
					return conn.Dial()
				},
				ResponseHeaderTimeout: time.Second * 2,
			},
		}

		resp, err := client.Do(connReq)
		if err != nil {
			log.Errorf("Error reading HTTP CONNECT request response: %v", err)
			conn.Close()
			resultCh <- &dialResult{nil, err}
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != 200 {
			resp, _ := ioutil.ReadAll(resp.Body)
			conn.Close()
			resultCh <- &dialResult{nil, errors.New("proxy refused connection" + string(resp))}
		} else {
			log.Debugf("Successfully established an HTTP tunnel with remote end-point: %s", addr)
			resultCh <- &dialResult{conn, nil}
		}
	}()

	result := <-resultCh
	if result.err != nil {
		log.Errorf("Error dialing new request: %v", result.err)
		return nil, result.err
	}
	return result.forwardConn, nil
}

func (proxy *SocksProxy) httpConnectHandler(localConn *socks.SocksConn) (err error) {

	defer localConn.Close()
	defer proxy.openConns.Remove(localConn)
	proxy.openConns.Add(localConn)

	if localConn.Req.Target == udpgwServer {
		return proxy.directHandler(localConn)
	}

	if proxy.isMasquerade(localConn.Req.Target) {
		log.Debugf("Masquerade check...")
		return nil
	}

	remoteConn, err := proxy.tunneler.Dial(localConn.Req.Target, localConn)
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		return err
	}
	defer remoteConn.Close()
	err = localConn.Grant(&net.TCPAddr{IP: net.ParseIP("0.0.0.0"), Port: 0})
	if err != nil {
		log.Errorf("Error granting local connection: %v", err)
		return err
	}
	Relay(localConn, remoteConn)
	return nil
}

func (proxy *SocksProxy) directHandler(localConn *socks.SocksConn) (err error) {

	host, port, err := protected.SplitHostPort(localConn.Req.Target)
	if err != nil {
		log.Errorf("Could not extract IP Address: %v", err)
		return err
	}

	conn, err := protected.New(proxy.tunneler.protector, localConn.Req.Target)
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
			err := proxy.httpConnectHandler(socksConnection)
			if err != nil {
				log.Errorf("%v", err)
			}
		}()
	}
	log.Debugf("SOCKS proxy stopped")
}
