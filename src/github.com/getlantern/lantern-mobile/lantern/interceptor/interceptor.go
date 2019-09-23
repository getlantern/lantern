// interceptor acts as an intermediary between a local SOCKS proxy
// intercepting VPN traffic and Lantern
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

	socks "github.com/getlantern/lantern-mobile/lantern/socks"
)

// Errors introduced by the interceptor service
var (
	defaultClient Interceptor
	dialTimeout   = 20 * time.Second
	// threshold of errors that we are withstanding
	maxErrCount = 15

	statsInterval = 15 * time.Second
	log           = golog.LoggerFor("lantern-android.interceptor")

	ErrTooManyFailures = errors.New("Too many connection failures")
	ErrNoSocksProxy    = errors.New("Unable to start local SOCKS proxy")
	ErrDialTimeout     = errors.New("Error dialing tunnel: timeout")
)

type DialFunc func(network, addr string) (net.Conn, error)

// Interceptor is responsible for intercepting
// traffic on the VPN interface.
type Interceptor struct {
	client *client.Client

	clientGone bool

	socksAddr string
	httpAddr  string

	sendAlert func(string, bool)

	listener   *socks.SocksListener
	serveGroup *sync.WaitGroup

	// Maximum duration for full request writing (including body).
	//
	// By default request write timeout is unlimited.
	WriteTimeout time.Duration

	ReadTimeout time.Duration

	Dial DialFunc

	requestPool    sync.Pool
	responsePool   sync.Pool
	errorChPool    sync.Pool
	clientConnPool sync.Pool

	errCh         chan error
	totalErrCount int

	mu sync.Mutex

	connsLock  sync.Mutex
	conns      map[string]*InterceptedConn
	connsCount int
}

type dialResult struct {
	forwardConn net.Conn
	err         error
}

func (i *Interceptor) dialHost(addr string) (net.Conn, error) {
	dial := i.client.GetBalancer().Dial
	if dial == nil {
		dial = net.Dial
	}
	conn, err := dial("connect", addr)

	if err != nil {
		return nil, err
	}
	if conn == nil {
		log.Fatalf("Dial func returned nil: %v", err)
	}
	return conn, nil
}

func (i *Interceptor) startSocksProxy() error {
	listener, err := socks.ListenSocks("tcp", i.socksAddr)

	if err != nil {
		log.Errorf("Could not start SOCKS server: %v", err)
		return ErrNoSocksProxy
	}

	i.listener = listener
	i.serveGroup.Add(1)

	go i.acceptSocks()
	log.Debugf("SOCKS proxy now listening on port: %v",
		i.listener.Addr().(*net.TCPAddr).Port)
	return nil
}

// serve processes all incoming SOCKS requests
func (i *Interceptor) acceptSocks() {
	defer i.listener.Close()
	defer i.serveGroup.Done()

L:
	for {
		socksConnection, err := i.listener.AcceptSocks()

		i.mu.Lock()
		clientGone := i.clientGone
		i.mu.Unlock()
		if clientGone {
			break L
		}

		if err != nil {
			log.Errorf("SOCKS proxy accept error: %v", err)
			if e, ok := err.(net.Error); ok && e.Temporary() {
				continue
			}
			log.Errorf("Fatal component failure: %v", err)
			i.closeAll()
			break L
		}
		go func() {
			err := i.Do(socksConnection)
			if err != nil {
				log.Errorf("SOCKS error: %v", err)
			}
		}()
	}
}

func (ic *InterceptedConn) Do() error {
	var wg sync.WaitGroup
	wg.Add(1)

	go func() {
		_, err := io.Copy(ic, ic.localConn)
		if err != nil {
			log.Errorf("Relay failed: %v", err)
		}
		wg.Done()
	}()
	_, err := io.Copy(ic.localConn, ic)
	if err != nil {
		log.Errorf("Error reading from server: %v", err)
	}
	wg.Wait()
	return err
}

func createId(conn net.Conn, addr string) string {
	return fmt.Sprintf("%s:%s", conn.RemoteAddr(), addr)
}

func (i *Interceptor) Do(conn *socks.SocksConn) error {
	addr := conn.Req.Target

	id := createId(conn, addr)
	i.connsLock.Lock()
	ic := i.acquireClientConn(id, conn)
	log.Debugf("Got a new connection: %s", id)
	i.conns[id] = ic
	i.connsCount++
	i.connsLock.Unlock()

	defer i.closeConn(ic)

	resultCh := make(chan *dialResult, 2)
	time.AfterFunc(dialTimeout, func() {
		resultCh <- &dialResult{nil, ErrDialTimeout}
	})

	go func() {
		forwardConn, err := i.dialHost(addr)
		if err != nil {
			log.Errorf("Could not connect: %v", err)
		}
		resultCh <- &dialResult{forwardConn, err}
	}()

	result := <-resultCh
	if result.err != nil {
		log.Errorf("Error dialing new request: %v", result.err)
		return result.err
	}
	ic.Conn = result.forwardConn

	// inform proxy client that access to the given
	// address is granted
	err := conn.Grant(&net.TCPAddr{
		IP: net.ParseIP("0.0.0.0"), Port: 0})
	if err != nil {
		log.Errorf("Unable to grant connection: %v", err)
		return err
	}
	return ic.Do()
}

func Do(client *client.Client,
	socksAddr, httpAddr string, notice func(string, bool)) (*Interceptor, error) {

	defaultClient = Interceptor{
		clientGone:    false,
		client:        client,
		socksAddr:     socksAddr,
		httpAddr:      httpAddr,
		errCh:         make(chan error, maxErrCount),
		sendAlert:     notice,
		WriteTimeout:  dialTimeout,
		ReadTimeout:   dialTimeout,
		totalErrCount: 0,
		serveGroup:    new(sync.WaitGroup),
		conns:         make(map[string]*InterceptedConn),
	}

	err := defaultClient.startSocksProxy()
	if err != nil {
		return nil, err
	}

	go defaultClient.monitor()
	go defaultClient.connsCleaner()

	return &defaultClient, nil
}

func (i *Interceptor) closeAll() {
	i.connsLock.Lock()
	for _, conn := range i.conns {
		if conn != nil {
			i.closeConn(conn)
		}
	}
	i.connsCount = 0
	i.conns = make(map[string]*InterceptedConn)
	i.connsLock.Unlock()
}

func (i *Interceptor) connsCleaner() {
	stop := false
	for {
		t := time.Now()
		i.connsLock.Lock()
		m := i.conns
		for _, conn := range m {
			if conn != nil && t.Sub(conn.t) > 20*time.Second {
				i.closeConn(conn)
				i.connsCount--
			}
		}
		i.connsLock.Unlock()

		i.mu.Lock()
		clientGone := i.clientGone
		i.mu.Unlock()
		if !clientGone {
			stop = true
		}

		if stop {
			break
		}
		time.Sleep(10 * time.Second)
	}
}

func (i *Interceptor) closeConn(conn *InterceptedConn) {
	log.Debugf("Closing a connection with id: %s", conn.id)
	if conn.Conn != nil {
		conn.Conn.Close()
	}
	if conn.localConn != nil {
		conn.localConn.Close()
	}
	i.conns[conn.id] = nil
	i.connsCount--
	i.releaseClientConn(conn)
}

func (i *Interceptor) acquireClientConn(id string, localConn net.Conn) *InterceptedConn {
	conn := i.clientConnPool.Get()

	if conn == nil {
		ic := &InterceptedConn{
			id:          id,
			interceptor: i,
			localConn:   localConn,
		}
		ic.v = ic
		return ic
	} else {
		v := conn.(*InterceptedConn)
		v.id = id
		v.v = v
		v.localConn = localConn
		return v
	}
}

func (i *Interceptor) decConnsCount() {
	i.connsLock.Lock()
	i.connsCount--
	i.connsLock.Unlock()
}

func (i *Interceptor) getConnsCount() int {
	i.connsLock.Lock()
	count := i.connsCount
	i.connsLock.Unlock()
	return count
}

func (i *Interceptor) releaseClientConn(ic *InterceptedConn) {
	ic.t = time.Now()
	ic.Conn = nil
	ic.localConn = nil
	i.clientConnPool.Put(ic.v)
}

// monitor is used to send periodic updates about the current
// interceptor (such as traffic stats) and to watch for connection
// failures. If we exceed a certain threshold of failures, we stop
// the interceptor and disable the service
func (i *Interceptor) monitor() {

	updatesTimer := time.NewTimer(15 * time.Second)
	defer updatesTimer.Stop()
L:
	for {
		select {
		case <-updatesTimer.C:
			i.mu.Lock()
			clientGone := i.clientGone
			i.mu.Unlock()
			if clientGone {
				break L
			}

			count := i.getConnsCount()
			statsMsg := fmt.Sprintf("Number of open connections: %d", count)
			log.Debug(statsMsg)
			i.sendAlert(statsMsg, false)
			updatesTimer.Reset(statsInterval)
		case err := <-i.errCh:
			log.Debugf("New error: %v", err)
			i.totalErrCount += 1
			if i.totalErrCount > maxErrCount {
				log.Errorf("Total errors: %d %v", i.totalErrCount, ErrTooManyFailures)
				i.sendAlert(ErrTooManyFailures.Error(), true)
				i.Stop()
				break L
			}
		}
	}
}

// Stop closes the SOCKS listener and stats service
// it also closes all pending connections
func (i *Interceptor) Stop() {

	i.mu.Lock()
	clientGone := i.clientGone
	i.mu.Unlock()

	if !clientGone {
		i.listener.Close()
		i.serveGroup.Wait()
		i.closeAll()
	}

	i.mu.Lock()
	i.clientGone = true
	i.mu.Unlock()
}
