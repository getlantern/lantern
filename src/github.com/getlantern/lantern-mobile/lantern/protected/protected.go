// Package protected is used for creating "protected" connections
// that bypass Android's VpnService
package protected

import (
	"errors"
	"fmt"
	"net"
	"os"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/getlantern/golog"
)

const (
	defaultDnsServer = "8.8.4.4"
	connectTimeOut   = 15 * time.Second
	readDeadline     = 15 * time.Second
	writeDeadline    = 15 * time.Second
	socketError      = -1
	dnsPort          = 53
)

type SocketProtector interface {
	Protect(fileDescriptor int) error
}

type ProtectedConn struct {
	net.Conn
	mutex     sync.Mutex
	protector SocketProtector
	isClosed  bool
	socketFd  int
	addr      string
	host      string
	ip        [4]byte
	port      int
}

var (
	log              = golog.LoggerFor("lantern-android.protected")
	currentProtector SocketProtector
	currentDnsServer string
	vpnMode          = false
)

func Configure(protector SocketProtector, dnsServer string, mode bool) {
	currentProtector = protector
	if dnsServer != "" {
		currentDnsServer = dnsServer
	} else {
		dnsServer = defaultDnsServer
	}
	vpnMode = mode
}

func VpnMode() bool {
	return vpnMode
}

// Dial creates a new protected connection
// - syscall API calls are used to create and bind to the
//   specified system device (this is primarily
//   used for Android VpnService routing functionality)
func Dial(network, addr string, timeout time.Duration) (*ProtectedConn, error) {
	host, port, err := SplitHostPort(addr)
	if err != nil {
		return nil, err
	}

	conn := &ProtectedConn{
		addr:      addr,
		host:      host,
		port:      port,
		protector: currentProtector,
	}
	// do DNS query
	IPAddr, err := conn.resolveHostname()
	if err != nil {
		log.Errorf("Couldn't resolve host %s: %s", conn.addr, err)
		return nil, err
	}

	copy(conn.ip[:], IPAddr.To4())

	socketFd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_STREAM, 0)
	if err != nil {
		log.Errorf("Could not create socket: %s", err)
		return nil, err
	}
	conn.socketFd = socketFd

	defer conn.cleanup()

	// Actually protect the underlying socket here
	err = conn.protector.Protect(conn.socketFd)
	if err != nil {
		return nil, fmt.Errorf("Could not bind socket to system device: %s", err)
	}

	err = conn.connectSocket()
	if err != nil {
		log.Errorf("Could not connect to socket: %v", err)
		return nil, err
	}

	// finally, convert the socket fd to a net.Conn
	err = conn.convert()
	if err != nil {
		log.Errorf("Error converting protected connection: %s", err)
		return nil, err
	}

	conn.Conn.SetDeadline(time.Now().Add(timeout))
	return conn, nil
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

func (conn *ProtectedConn) Addr() (*net.TCPAddr, error) {
	return net.ResolveTCPAddr("tcp", conn.addr)
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

// cleanup is ran whenever we encounter a socket error
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

// resolveHostname creates a UDP socket and binds it to the device
func (conn *ProtectedConn) resolveHostname() (net.IP, error) {

	// Check if we already have the IP address
	IPAddr := net.ParseIP(conn.host)
	if IPAddr != nil {
		return IPAddr, nil
	}

	// Create a datagram socket
	socketFd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_DGRAM, 0)
	if err != nil {
		log.Errorf("Error creating socket: %s", err)
		return nil, err
	}
	defer syscall.Close(socketFd)

	// Here we protect the underlying socket from the
	// VPN connection by passing the file descriptor
	// back to Java for exclusion
	err = conn.protector.Protect(socketFd)
	if err != nil {
		return nil, fmt.Errorf("Could not bind socket to system device: %s", err)
	}

	IPAddr = net.ParseIP(currentDnsServer)
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
	result, err := dnsLookup(conn.host, fileConn)
	if err != nil {
		log.Errorf("Error doing DNS resolution: %s", err)
		return nil, err
	}
	ipAddr, err := result.PickRandomIP()
	if err != nil {
		log.Errorf("No IP address available: %s", err)
		return nil, err
	}
	return ipAddr, nil
}

// wrapper around net.SplitHostPort that also converts
// uses strconv to convert the port to an int
func SplitHostPort(addr string) (string, int, error) {
	host, sPort, err := net.SplitHostPort(addr)
	if err != nil {
		log.Errorf("Could not split network address: %s", err)
		return "", 0, err
	}
	port, err := strconv.Atoi(sPort)
	if err != nil {
		log.Errorf("No port number found %s", err)
		return "", 0, err
	}
	return host, port, nil
}
