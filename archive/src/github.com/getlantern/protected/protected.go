// Package protected is used for creating "protected" connections
// that bypass Android's VpnService
package protected

import (
	"net"
	"os"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/getlantern/errors"
	"github.com/getlantern/golog"
	"github.com/getlantern/ops"
	"github.com/getlantern/withtimeout"
)

var (
	log = golog.LoggerFor("lantern-android.protected")
)

const (
	defaultDNSServer = "8.8.4.4"
	connectTimeOut   = 15 * time.Second
	readDeadline     = 15 * time.Second
	writeDeadline    = 15 * time.Second
	socketError      = -1
	dnsPort          = 53
)

type Protect func(fileDescriptor int) error

type ProtectedConn struct {
	net.Conn
	mutex    sync.Mutex
	isClosed bool
	socketFd int
	ip       [4]byte
	port     int
}

type Protector struct {
	protect   Protect
	dnsServer string
}

func New(protect Protect, dnsServer string) *Protector {
	if dnsServer == "" {
		dnsServer = defaultDNSServer
	}
	return &Protector{protect, dnsServer}
}

// Resolve resolves the given address using a DNS lookup on a UDP socket
// protected by the given Protect function.
func (p *Protector) Resolve(network string, addr string) (*net.TCPAddr, error) {
	op := ops.Begin("protected-resolve").Set("addr", addr)
	defer op.End()
	conn, err := p.resolve(op, network, addr)
	return conn, op.FailIf(err)
}

func (p *Protector) resolve(op ops.Op, network string, addr string) (*net.TCPAddr, error) {
	host, port, err := SplitHostPort(addr)
	if err != nil {
		return nil, err
	}

	// Check if we already have the IP address
	IPAddr := net.ParseIP(host)
	if IPAddr != nil {
		return &net.TCPAddr{IP: IPAddr, Port: port}, nil
	}

	// Create a datagram socket
	socketFd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_DGRAM, 0)
	if err != nil {
		return nil, errors.New("Error creating socket: %v", err)
	}
	defer syscall.Close(socketFd)

	// Here we protect the underlying socket from the
	// VPN connection by passing the file descriptor
	// back to Java for exclusion
	err = p.protect(socketFd)
	if err != nil {
		return nil, errors.New("Could not bind socket to system device: %v", err)
	}

	IPAddr = net.ParseIP(p.dnsServer)
	if IPAddr == nil {
		return nil, errors.New("invalid IP address")
	}

	var ip [4]byte
	copy(ip[:], IPAddr.To4())
	sockAddr := syscall.SockaddrInet4{Addr: ip, Port: dnsPort}

	err = syscall.Connect(socketFd, &sockAddr)
	if err != nil {
		return nil, err
	}

	fd := uintptr(socketFd)
	file := os.NewFile(fd, "")
	defer file.Close()

	// return a copy of the network connection
	// represented by file
	fileConn, err := net.FileConn(file)
	if err != nil {
		log.Errorf("Error returning a copy of the network connection: %v", err)
		return nil, err
	}

	setQueryTimeouts(fileConn)

	log.Debugf("performing dns lookup...!!")
	result, err := dnsLookup(host, fileConn)
	if err != nil {
		log.Errorf("Error doing DNS resolution: %v", err)
		return nil, err
	}
	ipAddr, err := result.PickRandomIP()
	if err != nil {
		log.Errorf("No IP address available: %v", err)
		return nil, err
	}
	return &net.TCPAddr{IP: ipAddr, Port: port}, nil
}

// Dial creates a new protected connection.
// - syscall API calls are used to create and bind to the
//   specified system device (this is primarily
//   used for Android VpnService routing functionality)
func (p *Protector) Dial(network, addr string, timeout time.Duration) (net.Conn, error) {
	op := ops.Begin("protected-dial").Set("addr", addr).Set("timeout", timeout.Seconds())
	defer op.End()
	conn, err := p.dial(op, network, addr, timeout)
	return conn, op.FailIf(err)
}

func (p *Protector) dial(op ops.Op, network, addr string, timeout time.Duration) (net.Conn, error) {
	start := time.Now()

	remainingTimeout := func() time.Duration {
		return timeout - time.Now().Sub(start)
	}

	host, port, err := SplitHostPort(addr)
	if err != nil {
		return nil, err
	}

	_ip, timedOut, err := withtimeout.Do(remainingTimeout(), func() (interface{}, error) {
		// do DNS query
		ip := net.ParseIP(host)
		if ip != nil {
			return ip, nil
		}
		// Try to resolve it
		addr, err := p.Resolve(network, addr)
		if err != nil {
			return nil, err
		}
		return addr.IP, nil
	})

	if timedOut {
		return nil, errors.New("Timed out looking up address %v within %v", addr, timeout)
	} else if err != nil {
		return nil, errors.New("Unable to look up address %v: %v", addr, err)
	}

	ip := _ip.(net.IP)

	conn := &ProtectedConn{
		port: port,
	}
	copy(conn.ip[:], ip.To4())

	socketFd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_STREAM, 0)
	if err != nil {
		return nil, errors.New("Could not create socket: %v", err)
	}
	conn.socketFd = socketFd
	defer conn.cleanup()

	_, timedOut, err = withtimeout.Do(remainingTimeout(), func() (interface{}, error) {
		// Actually protect the underlying socket here
		return nil, p.protect(conn.socketFd)
	})
	if timedOut {
		return nil, errors.New("Timed out protecting socket to %v within %v", addr, timeout)
	} else if err != nil {
		return nil, errors.New("Unable to protect socket to %v: %v", addr, err)
	}

	_, timedOut, err = withtimeout.Do(remainingTimeout(), func() (interface{}, error) {
		// Actually protect the underlying socket here
		return nil, conn.connectSocket()
	})
	if timedOut {
		return nil, errors.New("Timed out connecting socket to %v within %v", addr, timeout)
	} else if err != nil {
		return nil, errors.New("Unable to connect socket to %v: %v", addr, err)
	}

	// finally, convert the socket fd to a net.Conn
	err = conn.convert()
	if err != nil {
		return nil, errors.New("Error converting protected connection: %v", err)
	}
	return conn.Conn, nil
}

// connectSocket makes the connection to the given IP address port
// for the given socket fd
func (conn *ProtectedConn) connectSocket() error {
	sockAddr := syscall.SockaddrInet4{Addr: conn.ip, Port: conn.port}
	errCh := make(chan error, 2)
	time.AfterFunc(connectTimeOut, func() {
		errCh <- errors.New("connect timeout")
	})
	go func() {
		errCh <- syscall.Connect(conn.socketFd, &sockAddr)
	}()
	err := <-errCh
	return err
}

// converts the protected connection specified by
// socket fd to a net.Conn
func (conn *ProtectedConn) convert() error {
	conn.mutex.Lock()
	file := os.NewFile(uintptr(conn.socketFd), "")
	// dup the fd and return a copy
	fileConn, err := net.FileConn(file)
	// closes the original fd
	file.Close()
	conn.socketFd = socketError
	if err != nil {
		conn.mutex.Unlock()
		return err
	}
	conn.Conn = fileConn
	conn.mutex.Unlock()
	return nil
}

// cleanup is run whenever we encounter a socket error
// we use a mutex since this connection is active in a variety
// of goroutines and to prevent any possible race conditions
func (conn *ProtectedConn) cleanup() {
	conn.mutex.Lock()
	defer conn.mutex.Unlock()

	if conn.socketFd != socketError {
		syscall.Close(conn.socketFd)
		conn.socketFd = socketError
	}
}

// Close is used to destroy a protected connection
func (conn *ProtectedConn) Close() (err error) {
	conn.mutex.Lock()
	defer conn.mutex.Unlock()

	if !conn.isClosed {
		conn.isClosed = true
		if conn.Conn == nil {
			if conn.socketFd == socketError {
				err = nil
			} else {
				err = syscall.Close(conn.socketFd)
				// update socket fd to socketError
				// to make it explicit this connection
				// has been closed
				conn.socketFd = socketError
			}
		} else {
			err = conn.Conn.Close()
		}
	}
	return err
}

// configure DNS query expiration
func setQueryTimeouts(c net.Conn) {
	now := time.Now()
	c.SetReadDeadline(now.Add(readDeadline))
	c.SetWriteDeadline(now.Add(writeDeadline))
}

// SplitHostAndPort is a wrapper around net.SplitHostPort that also uses strconv
// to convert the port to an int
func SplitHostPort(addr string) (string, int, error) {
	host, sPort, err := net.SplitHostPort(addr)
	if err != nil {
		log.Errorf("Could not split network address: %v", err)
		return "", 0, err
	}
	port, err := strconv.Atoi(sPort)
	if err != nil {
		log.Errorf("No port number found %v", err)
		return "", 0, err
	}
	return host, port, nil
}
