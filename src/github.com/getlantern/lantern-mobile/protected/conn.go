package protected

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/resolver"
)

const (
	defaultDnsServer = "8.8.4.4"
	connectTimeOut   = 15 * time.Second

	_SOCKET_ERROR = -1
	_DNS_PORT     = 53
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
	port      int
}

var (
	log = golog.LoggerFor("lantern-android.protected")
)

// Creates a new protected connection with destination addr
func New(protector SocketProtector, addr string) (*ProtectedConn, error) {
	host, port, err := splitHostPort(addr)
	if err != nil {
		return nil, err
	}

	conn := &ProtectedConn{
		addr:      addr,
		host:      host,
		port:      port,
		protector: protector,
	}

	return conn, nil
}

// Dial connects to the address given by the protected connection
// - syscall API calls are used to create and bind to the
//   specified system device (this is primarily
//   used for Android VpnService routing functionality)
func (conn *ProtectedConn) Dial() (net.Conn, error) {
	// do DNS query
	IPAddr, err := conn.lookupIP()
	if err != nil {
		log.Errorf("Couldn't resolve host %s: %s", conn.addr, err)
		return nil, err
	}

	var ip [4]byte
	copy(ip[:], IPAddr.To4())

	socketFd, err := syscall.Socket(syscall.AF_INET, syscall.SOCK_STREAM, 0)
	if err != nil {
		log.Errorf("Could not create socket: %s", err)
		return nil, err
	}
	conn.socketFd = socketFd

	defer func() {
		conn.mutex.Lock()
		if err != nil && conn.socketFd != _SOCKET_ERROR {
			syscall.Close(conn.socketFd)
			conn.socketFd = _SOCKET_ERROR
		}
		conn.mutex.Unlock()
	}()
	err = conn.protect()
	if err != nil {
		log.Errorf("Error protecting socket: %s", err)
		return nil, err
	}

	// Actually connect to the socket here
	sockAddr := syscall.SockaddrInet4{Addr: ip, Port: conn.port}
	if connectTimeOut != 0 {
		errChannel := make(chan error, 2)
		time.AfterFunc(connectTimeOut, func() {
			errChannel <- errors.New("connect timeout")
		})
		go func() {
			errChannel <- syscall.Connect(conn.socketFd, &sockAddr)
		}()
		err = <-errChannel
	} else {
		err = syscall.Connect(conn.socketFd, &sockAddr)
		if err != nil {
			log.Errorf("Could not connect to socket: %s", err)
			return nil, err
		}
	}

	err = conn.convert()
	if err != nil {
		log.Errorf("Error converting protected connection: %s", err)
		return nil, err
	}
	return conn.Conn, nil
}

func sendTestRequest(client *http.Client, addr string) {
	req, err := http.NewRequest("GET", "http://"+addr+"/", nil)
	if err != nil {
		log.Errorf("Error constructing new HTTP request: %s", err)
		return
	}
	req.Header.Add("Connection", "keep-alive")
	if resp, err := client.Do(req); err != nil {
		log.Errorf("Could not make request to %s: %s", addr, err)
		return
	} else {
		result, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			log.Errorf("Error reading response body: %s", err)
			return
		}
		resp.Body.Close()
		log.Debugf("Successfully processed request to %s", addr)
		log.Debugf("RESULT: %s", result)
	}
}

func TestConnect(protector SocketProtector, addr string) error {
	conn, err := New(protector, addr)
	if err != nil {
		log.Errorf("Could not test protected connection: %s", err)
		return err
	}

	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(netw, addr string) (net.Conn, error) {
				return conn.Dial()
			},
			ResponseHeaderTimeout: time.Second * 2,
		},
	}
	sendTestRequest(client, addr)
	return nil
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
	conn.socketFd = _SOCKET_ERROR
	if err != nil {
		conn.mutex.Unlock()
		return err
	}
	conn.Conn = fileConn
	conn.mutex.Unlock()
	return nil
}

func (conn *ProtectedConn) interruptibleTCPClose() error {
	// Assumes conn.mutex is held
	if conn.socketFd == _SOCKET_ERROR {
		return nil
	}
	err := syscall.Close(conn.socketFd)
	conn.socketFd = _SOCKET_ERROR
	return err
}

func (conn *ProtectedConn) Close() (err error) {
	conn.mutex.Lock()
	defer conn.mutex.Unlock()

	if !conn.isClosed {
		conn.isClosed = true
		if conn.Conn == nil {
			err = conn.interruptibleTCPClose()
		} else {
			err = conn.Conn.Close()
		}
	}
	return err
}

func (conn *ProtectedConn) protect() error {
	return conn.protector.Protect(conn.socketFd)
}

func (conn *ProtectedConn) lookupIP() (net.IP, error) {

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

	err = conn.protector.Protect(socketFd)
	if err != nil {
		return nil, fmt.Errorf("Could not bind socket to system device: %s", err)
	}

	// config.DnsServerGetter.GetDnsServer must return an IP address
	IPAddr = net.ParseIP(defaultDnsServer)
	if IPAddr == nil {
		return nil, errors.New("invalid IP address")
	}

	var ip [4]byte
	copy(ip[:], IPAddr.To4())
	sockAddr := syscall.SockaddrInet4{Addr: ip, Port: _DNS_PORT}
	// Note: no timeout or interrupt for this connect, as it's a datagram socket
	err = syscall.Connect(socketFd, &sockAddr)
	if err != nil {
		return nil, err
	}

	// Convert the syscall socket to a net.Conn, for use in the dns package
	file := os.NewFile(uintptr(socketFd), "")
	defer file.Close()
	fileConn, err := net.FileConn(file)
	if err != nil {
		return nil, err
	}

	result, err := resolver.ResolveIP(conn.host, fileConn)
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

func splitHostPort(addr string) (string, int, error) {
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
