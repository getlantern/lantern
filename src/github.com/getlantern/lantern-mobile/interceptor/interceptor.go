// socks implements a SOCKS server that intercepts local host connections
// and forwards them through Lantern's HTTP proxy
package interceptor

import (
	"errors"
	"io"
	"net"
	"sync"
	"time"

	"github.com/getlantern/balancer"
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/protected"
	socks "github.com/getlantern/lantern-mobile/socks"
)

var (
	DIAL_TIMEOUT = 15 * time.Second
	log          = golog.LoggerFor("lantern-android.interceptor")
)

type Tunneler struct {
	socksAddr   string
	httpAddr    string
	udpgwServer string
	balancer    *balancer.Balancer
	protector   protected.SocketProtector

	portForwardFailures chan int
	mutex               *sync.Mutex
	isClosed            bool
}

type TunneledConn struct {
	net.Conn
	tunnel         *Tunneler
	downstreamConn net.Conn
}

func (conn *TunneledConn) Read(buffer []byte) (n int, err error) {
	n, err = conn.Conn.Read(buffer)
	if err != nil && err != io.EOF {
		// Report 1 new failure. Won't block; assumes the receiver
		// has a sufficient buffer for the threshold number of reports.
		// TODO: conditional on type of error or error message?
		select {
		case conn.tunnel.portForwardFailures <- 1:
		default:
		}
	}
	return
}

func (conn *TunneledConn) Write(buffer []byte) (n int, err error) {
	n, err = conn.Conn.Write(buffer)
	if err != nil && err != io.EOF {
		// Same as TunneledConn.Read()
		select {
		case conn.tunnel.portForwardFailures <- 1:
		default:
		}
	}
	return
}

type dialResult struct {
	forwardConn net.Conn
	err         error
}

type SocksProxy struct {
	tunneler               Tunneler
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
		_, err := io.Copy(localConn, remoteConn)
		if err != nil {
			log.Errorf("Relay failed: %v", err)
		}
		wg.Done()
	}()

	go func() {
		io.Copy(remoteConn, localConn)
		wg.Done()
	}()

	wg.Wait()
}

// New initializes a local SOCKS server. It begins listening for
// connections, starts a goroutine that runs an accept loop, and returns
// leaving the accept loop running.
func New(protector protected.SocketProtector,
	balancer *balancer.Balancer,
	socksAddr, httpAddr, udpgwServer string) (proxy *SocksProxy, err error) {

	listener, err := socks.ListenSocks(
		"tcp", socksAddr)
	if err != nil {
		log.Errorf("Could not start SOCKS server: %v", err)
		return nil, err
	}

	proxy = &SocksProxy{
		tunneler: Tunneler{
			mutex:               new(sync.Mutex),
			isClosed:            false,
			balancer:            balancer,
			protector:           protector,
			socksAddr:           socksAddr,
			httpAddr:            httpAddr,
			udpgwServer:         udpgwServer,
			portForwardFailures: make(chan int, 20),
		},
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

	host, port, err := protected.SplitHostPort(addr)
	if err != nil {
		return nil, err
	}
	if port != 80 && port != 443 && port != 7300 {
		log.Errorf("Invalid port %d for address %s", port, addr)
		return nil, errors.New("invalid port")
	}

	resultCh := make(chan *dialResult, 2)
	time.AfterFunc(DIAL_TIMEOUT, func() {
		resultCh <- &dialResult{nil,
			errors.New("dial timoue to tunnel")}
	})
	go func() {

		if port == 7300 {
			conn, err := protected.New(tunnel.protector, addr)
			if err != nil {
				log.Errorf("Error creating protected connection: %v", err)
				resultCh <- &dialResult{nil, err}
				return
			}
			log.Debugf("Connecting to %s:%d", host, port)

			remoteConn, err := conn.Dial()
			if err != nil {
				log.Errorf("Error tunneling request: %v", err)
				conn.Close()
				resultCh <- &dialResult{nil, err}
				return
			}
			resultCh <- &dialResult{remoteConn, err}
			return
		}

		forwardConn, err := tunnel.balancer.Dial("tcp", addr)
		if err != nil {
			log.Errorf("Could not connect: %v", err)
			resultCh <- &dialResult{nil, err}
			return
		}
		resultCh <- &dialResult{forwardConn, nil}
	}()
	result := <-resultCh
	if result.err != nil {
		log.Errorf("Error dialing new request: %v", result.err)
		return nil, result.err
	}

	tConn := &TunneledConn{
		Conn:           result.forwardConn,
		tunnel:         tunnel,
		downstreamConn: localConn,
	}
	return tConn, nil
}

func (proxy *SocksProxy) connectionHandler(localConn *socks.SocksConn) (err error) {

	defer localConn.Close()
	defer proxy.openConns.Remove(localConn)
	proxy.openConns.Add(localConn)

	remoteConn, err := proxy.tunneler.Dial(localConn.Req.Target, localConn)
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		return err
	}
	defer remoteConn.Close()

	err = localConn.Grant(&net.TCPAddr{IP: net.ParseIP("0.0.0.0"), Port: 0})
	if err != nil {
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
			err := proxy.connectionHandler(socksConnection)
			if err != nil {
				log.Errorf("%v", err)
			}
		}()
	}
	log.Debugf("SOCKS proxy stopped")
}
