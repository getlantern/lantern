// interceptor implements a service for intercepting VPN traffic
// on an Android device. It starts a local SOCKS server that
// forwards connections to Lantern's HTTP proxy
package interceptor

import (
	"errors"
	"fmt"
	"io"
	"net"
	"sync"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/lantern/protected"
	socks "github.com/getlantern/lantern-mobile/lantern/socks"
)

// Errors introduced by the interceptor service
var (
	ErrTooManyFailures = errors.New("Too many connection failures")
	ErrNoSocksProxy    = errors.New("Unable to start local SOCKS proxy")
)

var (
	dialTimeout = 10 * time.Second
	// threshold of errors that we are withstanding
	maxErrCount = 20
	// how often to print stats of current interceptor
	statsInterval = 15 * time.Second
	log           = golog.LoggerFor("lantern-android.interceptor")
)

// Interceptor intercepts traffic on a VPN interface
// and tunnels it through the Lantern HTTP proxy
type Interceptor struct {
	client *client.Client

	socksAddr string
	httpAddr  string

	errCh         chan error
	totalErrCount int

	listener   *socks.SocksListener
	serveGroup *sync.WaitGroup

	clientGone bool

	openConns  *Conns
	conns      map[string]*InterceptedConn
	connsMutex sync.RWMutex
	stopSignal chan struct{}
	stopStats  chan struct{}

	sendAlert func(string, bool)

	mu *sync.Mutex
}

type dialResult struct {
	forwardConn net.Conn
	err         error
}

func (i *Interceptor) pipe(localConn net.Conn, remoteConn *InterceptedConn) {

	var wg sync.WaitGroup
	wg.Add(2)

	removeConn := func() {
		i.connsMutex.Lock()
		i.conns[remoteConn.id] = nil
		i.connsMutex.Unlock()
	}

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
	removeConn()
}

func (i *Interceptor) startSocksProxy() error {
	listener, err := socks.ListenSocks("tcp", i.socksAddr)

	if err != nil {
		log.Errorf("Could not start SOCKS server: %v", err)
		return ErrNoSocksProxy
	}

	i.listener = listener
	i.serveGroup.Add(1)

	go i.serve()
	log.Debugf("SOCKS proxy now listening on port: %v",
		i.listener.Addr().(*net.TCPAddr).Port)
	return nil
}

// New initializes the Interceptor service. It also starts the local SOCKS
// proxy that we use to intercept traffic that arrives on the TUN interface
// We listen for connections on an accept loop
func New(client *client.Client,
	socksAddr, httpAddr string, notice func(string, bool)) (i *Interceptor, err error) {

	i = &Interceptor{
		mu:            new(sync.Mutex),
		clientGone:    false,
		client:        client,
		socksAddr:     socksAddr,
		httpAddr:      httpAddr,
		errCh:         make(chan error, maxErrCount),
		sendAlert:     notice,
		totalErrCount: 0,
		serveGroup:    new(sync.WaitGroup),
		openConns:     new(Conns),
		conns:         make(map[string]*InterceptedConn),
		stopSignal:    make(chan struct{}),
		stopStats:     make(chan struct{}),
	}

	err = i.startSocksProxy()
	if err != nil {
		return nil, err
	}
	go i.inspect()
	return i, nil
}

// Stop closes the SOCKS listener and stats service
// it also closes all pending connections
func (i *Interceptor) Stop() {
	close(i.stopSignal)
	close(i.stopStats)

	i.mu.Lock()
	clientGone := i.clientGone
	i.clientGone = true
	i.mu.Unlock()

	if !clientGone {
		i.listener.Close()
		i.serveGroup.Wait()
		i.openConns.CloseAll()
	}
}

// Dial dials addr using our actively configured balancer
// and relays data between the connection and our local SOCKS connection
func (i *Interceptor) Dial(addr string, localConn net.Conn) (*InterceptedConn, error) {

	i.mu.Lock()
	clientGone := i.clientGone
	i.mu.Unlock()

	if clientGone {
		return nil, errors.New("tunnel is closed")
	}

	_, port, err := protected.SplitHostPort(addr)
	if err != nil {
		return nil, err
	}

	// check if it's traffic we actually support
	if port != 80 && port != 443 && port != 53 {
		log.Errorf("Invalid port %d for address %s", port, addr)
		return nil, errors.New("invalid port")
	}
	id := fmt.Sprintf("%s:%s", localConn.LocalAddr(), addr)
	log.Debugf("Got a new connection: %s", id)

	resultCh := make(chan *dialResult, 2)
	time.AfterFunc(dialTimeout, func() {
		resultCh <- &dialResult{nil,
			errors.New("dial timeout to tunnel")}
	})
	go func() {
		balancer := i.client.GetBalancer()
		forwardConn, err := balancer.Dial("tcp", addr)
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

	conn := &InterceptedConn{
		Conn:        result.forwardConn,
		id:          id,
		interceptor: i,
		localConn:   localConn,
	}

	log.Debugf("Created new connection with id %s", id)
	i.connsMutex.Lock()
	i.conns[id] = conn
	i.connsMutex.Unlock()

	return conn, nil
}

// inspect is used to send periodic updates about the
// current inceptor (such as traffic stats) and to
// monitor for total number of connection failures
func (i *Interceptor) inspect() {

	updatesTimer := time.NewTimer(15 * time.Second)
	defer updatesTimer.Stop()
L:
	for {
		select {
		case <-i.stopStats:
			log.Debug("Stopping stats service")
			break L
		case <-updatesTimer.C:
			statsMsg := fmt.Sprintf("Number of open connections: %d", i.openConns.Size())
			log.Debug(statsMsg)
			i.sendAlert(statsMsg, false)
			updatesTimer.Reset(statsInterval)
		case err := <-i.errCh:
			log.Debugf("New error: %v", err)
			i.totalErrCount += 1
			if i.totalErrCount > maxErrCount {
				log.Errorf("Total errors: %d %v", i.totalErrCount, ErrTooManyFailures)
				i.sendAlert(err.Error(), true)
				i.Stop()
				break L
			}
		}
	}
}

func (i *Interceptor) handle(localConn *socks.SocksConn) (err error) {

	defer localConn.Close()
	defer i.openConns.Remove(localConn)
	i.openConns.Add(localConn)

	remoteConn, err := i.Dial(localConn.Req.Target, localConn)
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		return err
	}
	defer remoteConn.Close()

	err = localConn.Grant(&net.TCPAddr{
		IP: net.ParseIP("0.0.0.0"), Port: 0})
	if err != nil {
		return err
	}

	i.pipe(localConn, remoteConn)
	return nil
}

// serve processes all incoming SOCKS requests
func (i *Interceptor) serve() {
	defer i.listener.Close()
	defer i.serveGroup.Done()

L:
	for {
		socksConnection, err := i.listener.AcceptSocks()
		select {
		case <-i.stopSignal:
			log.Debugf("SOCKS proxy shutting down")
			break L
		default:
		}
		if err != nil {
			log.Errorf("SOCKS proxy accept error: %v", err)
			if e, ok := err.(net.Error); ok && e.Temporary() {
				continue
			}
			log.Fatalf("Fatal component failure: %v", err)
			break L
		}
		go func() {
			err := i.handle(socksConnection)
			if err != nil {
				log.Errorf("%v", err)
			}
		}()
	}
}
