// interceptor implements a service for intercepting VPN traffic on an Android device. It starts a local SOCKS server that forwards connections to Lantern's HTTP proxy
package interceptor

import (
	"errors"
	"io"
	"net"
	"sync"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/protected"
	socks "github.com/getlantern/lantern-mobile/socks"
)

// Errors introduced by the interceptor service
var (
	ErrTooManyFailures = errors.New("Too many connection failures")
	ErrNoSocksProxy    = errors.New("Unable to start local SOCKS proxy")
)

var (
	dialTimeout           = 15 * time.Second
	failureCountThreshold = 20
	log                   = golog.LoggerFor("lantern-android.interceptor")
)

type interceptor struct {
	client *client.Client

	socksAddr   string
	httpAddr    string
	udpgwServer string

	failureCount chan int
	isClosed     bool

	listener       *socks.SocksListener
	serveWaitGroup *sync.WaitGroup

	openConns              *Conns
	conns                  map[string]net.Conn
	stopListeningBroadcast chan struct{}

	mu *sync.Mutex
}

type dialResult struct {
	forwardConn net.Conn
	err         error
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

func (i *interceptor) startSocksProxy() error {
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

// New initializes the interceptor service. It also starts the local SOCKS
// proxy that we use to intercept traffic that arrives on the TUN interface
// We listen for connections on an accept loop
func New(client *client.Client,
	socksAddr, httpAddr, udpgwServer string) (i *interceptor, err error) {

	i = &interceptor{
		mu:             new(sync.Mutex),
		isClosed:       false,
		client:         client,
		socksAddr:      socksAddr,
		httpAddr:       httpAddr,
		udpgwServer:    udpgwServer,
		failureCount:   make(chan int, failureCountThreshold),
		serveWaitGroup: new(sync.WaitGroup),
		openConns:      new(Conns),
		conns:          map[string]net.Conn{},
		stopListeningBroadcast: make(chan struct{}),
	}

	err = i.startSocksProxy()
	if err != nil {
		return nil, err
	}

	return i, nil
}

// Close terminates the listener and waits for the accept loop
// goroutine to complete.
func (i *interceptor) Close() {
	close(i.stopListeningBroadcast)
	i.listener.Close()
	i.serveWaitGroup.Wait()
	i.openConns.CloseAll()
}

func (i *interceptor) Dial(addr string, localConn net.Conn) (net.Conn, error) {

	i.mu.Lock()
	isClosed := i.isClosed
	i.mu.Unlock()

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
	time.AfterFunc(dialTimeout, func() {
		resultCh <- &dialResult{nil,
			errors.New("dial timoue to tunnel")}
	})
	go func() {

		if port == 7300 {
			remoteConn, err := protected.Dial("tcp", addr)
			if err != nil {
				log.Errorf("Error creating protected connection: %v", err)
				resultCh <- &dialResult{nil, err}
				return
			}
			log.Debugf("Connecting to %s:%d", host, port)
			resultCh <- &dialResult{remoteConn, err}
			return
		}

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

func (i *interceptor) connectionHandler(localConn *socks.SocksConn) (err error) {

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

	Relay(localConn, remoteConn)
	return nil
}

func (i *interceptor) serve() {
	defer i.listener.Close()
	defer i.serveWaitGroup.Done()
loop:
	for {
		socksConnection, err := i.listener.AcceptSocks()
		select {
		case <-i.stopListeningBroadcast:
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
			log.Debugf("Got a new connection: %v", socksConnection)
			err := i.connectionHandler(socksConnection)
			if err != nil {
				log.Errorf("%v", err)
			}
		}()
	}
	log.Debugf("SOCKS proxy stopped")
}
