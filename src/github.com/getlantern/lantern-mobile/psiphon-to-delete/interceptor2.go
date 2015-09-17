// socks implements a SOCKS server that intercepts local host connections
// and forwards them through Lantern's HTTP proxy
package interceptor

import (
	"errors"
	"io"
	"net"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/protected"
	socks "github.com/getlantern/lantern-mobile/socks"
	"golang.org/x/crypto/ssh"
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
	sshClient *ssh.Client

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
	copyWaitGroup := new(sync.WaitGroup)
	copyWaitGroup.Add(1)
	go func() {
		defer copyWaitGroup.Done()
		_, err := io.Copy(localConn, remoteConn)
		if err != nil {
			log.Errorf("Relay failed: %s", err)
		}
	}()
	_, err := io.Copy(remoteConn, localConn)
	if err != nil {
		log.Errorf("Relay failed: %s", err)
	}
	copyWaitGroup.Wait()
}

func dialSsh(protector protected.SocketProtector) (conn net.Conn, sshClient *ssh.Client, err error) {

	pConn, err := protected.New(protector, "104.236.158.87:22")
	if err != nil {
		log.Errorf("Could not open connection: %v", err)
		return nil, nil, err
	}

	remoteConn, err := pConn.Dial()
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		return nil, nil, err
	}

	sshClientConfig := &ssh.ClientConfig{
		User: "test123",
		Auth: []ssh.AuthMethod{
			ssh.Password("test123"),
		},
	}

	type sshNewClientResult struct {
		sshClient *ssh.Client
		err       error
	}
	resultChannel := make(chan *sshNewClientResult, 2)
	time.AfterFunc(DIAL_TIMEOUT, func() {
		resultChannel <- &sshNewClientResult{nil, errors.New("ssh dial timeout")}
	})

	go func() {
		sshAddress := ""
		sshClientConn, sshChans, sshReqs, err := ssh.NewClientConn(remoteConn, sshAddress, sshClientConfig)
		var sshClient *ssh.Client
		if err == nil {
			sshClient = ssh.NewClient(sshClientConn, sshChans, sshReqs)
		}
		resultChannel <- &sshNewClientResult{sshClient, err}
	}()
	result := <-resultChannel
	if result.err != nil {
		log.Errorf("Could not dial to ssh server: %v", err)
		return nil, nil, err
	}
	log.Debugf("Successfully dialed to ssh server")

	return remoteConn, result.sshClient, nil
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

	_, sshClient, err := dialSsh(protector)
	if err != nil {
		log.Errorf("Couldn't dial ssh server: %v", err)
		return nil, err
	}

	proxy = &SocksProxy{
		tunneler: Tunneler{
			mutex:               new(sync.Mutex),
			isClosed:            false,
			protector:           protector,
			socksAddr:           socksAddr,
			sshClient:           sshClient,
			httpAddr:            httpAddr,
			portForwardFailures: make(chan int, 20),
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

	resultCh := make(chan *dialResult, 2)
	time.AfterFunc(DIAL_TIMEOUT, func() {
		resultCh <- &dialResult{nil,
			errors.New("dial timoue to tunnel")}
	})
	go func() {
		forwardConn, err := tunnel.sshClient.Dial("tcp", addr)
		resultCh <- &dialResult{forwardConn, err}
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

/* go func() {

	log.Debugf("Creating CONNECT request to %s", addr)

	connReq := &http.Request{
		Method: "CONNECT",
		URL:    &url.URL{Opaque: addr},
		Host:   addr,
		Header: make(http.Header),
	}

	remoteConn, err := conn.Dial()
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		resultCh <- &dialResult{nil, err}
		return
	}
	log.Debugf("Tunneling a new request to Lantern: %s", addr)
	connReq.WriteProxy(remoteConn)

	br := bufio.NewReader(remoteConn)
	resp, err := http.ReadResponse(br, connReq)
	if err != nil {
		log.Errorf("Error reading HTTP CONNECT request response: %v", err)
		conn.Close()
		remoteConn.Close()
		resultCh <- &dialResult{nil, err}
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		resp, _ := ioutil.ReadAll(resp.Body)
		conn.Close()
		remoteConn.Close()
		resultCh <- &dialResult{nil, errors.New("proxy refused connection" + string(resp))}
	} else {
		log.Debugf("Successfully established an HTTP tunnel with remote end-point: %s", addr)
		resultCh <- &dialResult{remoteConn, nil}
	}
}()*/

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
	addr, err := net.ResolveTCPAddr("tcp", proxy.tunneler.httpAddr)
	if err != nil {
		log.Errorf("Error resolving TCP address: %v", err)
		return err
	}
	log.Debugf("Connection granted to %v", addr)

	defer remoteConn.Close()

	err = localConn.Grant(&net.TCPAddr{IP: net.ParseIP("0.0.0.0"), Port: 0})
	if err != nil {
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
