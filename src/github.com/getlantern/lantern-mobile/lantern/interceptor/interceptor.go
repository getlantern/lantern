// interceptor implements a service for intercepting VPN traffic on an Android device. It starts a local SOCKS server that forwards connections to Lantern's HTTP proxy
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
	dialTimeout = 15 * time.Second
	// threshold of errors that we are withstanding
	maxErrCount = 20
	// how often to print stats of current interceptor
	statsInterval = 15 * time.Second
	log           = golog.LoggerFor("lantern-android.interceptor")
)

type Interceptor struct {
	client *client.Client

	socksAddr string
	httpAddr  string

	errCh         chan error
	totalErrCount int
	isClosed      bool

	listener       *socks.SocksListener
	serveWaitGroup *sync.WaitGroup

	openConns   *Conns
	conns       map[string]net.Conn
	stopSignal  chan struct{}
	showMessage func(string)

	mu *sync.Mutex
}

type dialResult struct {
	forwardConn net.Conn
	err         error
}

func pipe(localConn, remoteConn net.Conn) {

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

func (i *Interceptor) startSocksProxy() error {
	listener, err := socks.ListenSocks("tcp", i.socksAddr)

	if err != nil {
		log.Errorf("Could not start SOCKS server: %v", err)
		return ErrNoSocksProxy
	}

	i.listener = listener

	i.serveWaitGroup.Add(1)
	go i.serve()
	log.Debugf("SOCKS proxy now listening on port: %v",
		i.listener.Addr().(*net.TCPAddr).Port)

	return nil
}

// New initializes the Interceptor service. It also starts the local SOCKS
// proxy that we use to intercept traffic that arrives on the TUN interface
// We listen for connections on an accept loop
func New(client *client.Client,
	socksAddr, httpAddr string, notice func(string)) (i *Interceptor, err error) {

	i = &Interceptor{
		mu:             new(sync.Mutex),
		isClosed:       false,
		client:         client,
		socksAddr:      socksAddr,
		httpAddr:       httpAddr,
		errCh:          make(chan error, maxErrCount),
		showMessage:    notice,
		totalErrCount:  0,
		serveWaitGroup: new(sync.WaitGroup),
		openConns:      new(Conns),
		conns:          map[string]net.Conn{},
		stopSignal:     make(chan struct{}),
	}

	err = i.startSocksProxy()
	if err != nil {
		return nil, err
	}
	go i.inspect()
	return i, nil
}

// Stop terminates listener and wait for the accept loop
// goroutine to complete.
func (i *Interceptor) Stop() {
	close(i.stopSignal)

	i.mu.Lock()
	isClosed := i.isClosed
	i.isClosed = true
	i.mu.Unlock()

	if !isClosed {
		i.listener.Close()
		i.serveWaitGroup.Wait()
		i.openConns.CloseAll()
	}
}

func (i *Interceptor) Dial(addr string, localConn net.Conn) (net.Conn, error) {

	i.mu.Lock()
	isClosed := i.isClosed
	i.mu.Unlock()

	if isClosed {
		return nil, errors.New("tunnel is closed")
	}

	_, port, err := protected.SplitHostPort(addr)
	if err != nil {
		return nil, err
	}

	if port != 80 && port != 443 && port != 53 {
		log.Errorf("Invalid port %d for address %s", port, addr)
		return nil, errors.New("invalid port")
	}

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

	return &InterceptedConn{
		Conn:           result.forwardConn,
		interceptor:    i,
		downstreamConn: localConn,
	}, nil
}

// inspect is used to send periodic updates about the current inceptor (such as traffic stats) and to monitor for total number of connection failures
func (i *Interceptor) inspect() {

	updatesTimer := time.NewTimer(15 * time.Second)
	defer updatesTimer.Stop()
L:
	for {
		select {
		case <-updatesTimer.C:
			statsMsg := fmt.Sprintf("Number of open connections: %d", i.openConns.Size())
			log.Debug(statsMsg)
			i.showMessage(statsMsg)
			updatesTimer.Reset(statsInterval)
		case err := <-i.errCh:
			log.Debugf("New error: %v", err)
			i.totalErrCount += 1
			if i.totalErrCount > maxErrCount {
				log.Errorf("Total errors: %d %v", i.totalErrCount, ErrTooManyFailures)
				i.Stop()
				break L
			}
		}
	}
}

func (i *Interceptor) handler(localConn *socks.SocksConn) (err error) {

	log.Debugf("Got a new connection: %v", localConn)

	defer localConn.Close()
	defer i.openConns.Remove(localConn)
	i.openConns.Add(localConn)

	remoteConn, err := i.Dial(localConn.Req.Target, localConn)
	if err != nil {
		log.Errorf("Error tunneling request: %v", err)
		return err
	}
	defer remoteConn.Close()

	err = localConn.Grant(&net.TCPAddr{IP: net.ParseIP("0.0.0.0"), Port: 0})
	if err != nil {
		return err
	}

	pipe(localConn, remoteConn)
	return nil
}

func (i *Interceptor) serve() {
	defer i.listener.Close()
	defer i.serveWaitGroup.Done()
loop:
	for {
		socksConnection, err := i.listener.AcceptSocks()
		select {
		case <-i.stopSignal:
			log.Debugf("SOCKS proxy shutting down")
			break loop
		default:
		}
		if err != nil {
			log.Errorf("SOCKS proxy accept error: %v", err)
			if e, ok := err.(net.Error); ok && e.Temporary() {
				continue
			}
			log.Fatalf("Fatal component failure: %v", err)
			break loop
		}
		go func() {
			err := i.handler(socksConnection)
			if err != nil {
				log.Errorf("%v", err)
			}
		}()
	}
}
