package fronted

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/getlantern/enproxy"
	"github.com/getlantern/idletiming"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdefaults"
)

var (
	dialTimeout     = 10 * time.Second
	httpIdleTimeout = 70 * time.Second

	// Points in time, mostly used for generating certificates
	tenYearsFromToday = time.Now().AddDate(10, 0, 0)
)

type Server struct {
	// Addr: listen address in form of host:port
	Addr string

	// ReadTimeout: (optional) timeout for read ops
	ReadTimeout time.Duration

	// WriteTimeout: (optional) timeout for write ops
	WriteTimeout time.Duration

	// CertContext for server's certificates. If nil, the server will use
	// unencrypted connections instead of TLS.
	CertContext *CertContext

	// TLSConfig: tls configuration to use on inbound connections. If nil, will
	// use some sensible defaults.
	TLSConfig *tls.Config

	// Host: FQDN that is guaranteed to hit this server
	Host string

	// HostFn: Function mapping a http.Request to the FQDN of this particular
	// server, hopefully using the same front as the original request
	HostFn func(*http.Request) string

	// AllowNonGlobalDestinations: if false, requests to LAN, Loopback, etc.
	// will be disallowed.
	AllowNonGlobalDestinations bool

	// AllowedPorts: if specified, only connections to ports listed in this
	// slice will be allowed.
	AllowedPorts []int

	// OnBytesSent: optional callback for learning about bytes sent by this
	// server to upstream destinations.
	OnBytesSent func(ip string, destAddr string, req *http.Request, bytes int64)

	// OnBytesSent: optional callback for learning about bytes received by this
	// server from upstream destinations.
	OnBytesReceived func(ip string, destAddr string, req *http.Request, bytes int64)
}

// CertContext encapsulates the certificates used by a Server
type CertContext struct {
	PKFile         string
	ServerCertFile string
	PK             *keyman.PrivateKey
	ServerCert     *keyman.Certificate
}

func (server *Server) Listen() (net.Listener, error) {
	listener, err := server.listen()
	if err != nil {
		return nil, err
	}

	// We use an idle timing listener to time out idle HTTP connections, since
	// the CDNs seem to like keeping lots of connections open indefinitely.
	return idletiming.Listener(listener, httpIdleTimeout, func(conn net.Conn) {
		err := conn.Close()
		if err != nil {
			log.Debugf("Unable to close connection: %v", err)
		}
	}), nil
}

func (server *Server) listen() (net.Listener, error) {
	if server.CertContext != nil {
		return server.listenTLS()
	} else {
		return server.listenUnencrypted()
	}
}

func (server *Server) listenTLS() (net.Listener, error) {
	host, _, err := net.SplitHostPort(server.Addr)
	if err != nil {
		return nil, fmt.Errorf("Unable to split host and port for %v: %v", server.Addr, err)
	}
	err = server.CertContext.InitServerCert(host)
	if err != nil {
		return nil, fmt.Errorf("Unable to init server cert: %s", err)
	}

	tlsConfig := server.TLSConfig
	if server.TLSConfig == nil {
		tlsConfig = tlsdefaults.Server()
	}
	cert, err := tls.LoadX509KeyPair(server.CertContext.ServerCertFile, server.CertContext.PKFile)
	if err != nil {
		return nil, fmt.Errorf("Unable to load certificate and key from %s and %s: %s", server.CertContext.ServerCertFile, server.CertContext.PKFile, err)
	}
	tlsConfig.Certificates = []tls.Certificate{cert}

	listener, err := tls.Listen("tcp", server.Addr, tlsConfig)
	if err != nil {
		return nil, fmt.Errorf("Unable to listen for tls connections at %s: %s", server.Addr, err)
	}

	return listener, err
}

func (server *Server) listenUnencrypted() (net.Listener, error) {
	listener, err := net.Listen("tcp", server.Addr)
	if err != nil {
		return nil, fmt.Errorf("Unable to listen for unencrypted connections at %s: %s", server.Addr, err)
	}

	return listener, err
}

func (server *Server) Serve(l net.Listener) error {
	// Set up an enproxy Proxy
	proxy := &enproxy.Proxy{
		Dial:            server.dialDestination,
		Host:            server.Host,
		HostFn:          server.HostFn,
		OnBytesReceived: server.OnBytesReceived,
		OnBytesSent:     server.OnBytesSent,
	}

	proxy.Start()

	httpServer := &http.Server{
		Handler:      proxy,
		ReadTimeout:  server.ReadTimeout,
		WriteTimeout: server.WriteTimeout,
	}

	log.Debugf("About to start server (https) proxy at %s", server.Addr)

	return httpServer.Serve(l)
}

// dialDestination dials the destination server and wraps the resulting net.Conn
// in a countingConn if an InstanceId was configured.
func (server *Server) dialDestination(addr string) (net.Conn, error) {
	if !server.AllowNonGlobalDestinations {
		err := server.checkForNonGlobalDestination(addr)
		if err != nil {
			log.Error(err.Error())
			return nil, err
		}
	}

	if server.AllowedPorts != nil {
		err := server.checkForDisallowedPort(addr)
		if err != nil {
			log.Error(err.Error())
			return nil, err
		}
	}

	return net.DialTimeout("tcp", addr, dialTimeout)
}

func (server *Server) checkForNonGlobalDestination(addr string) error {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("Unable to split host and port for %v: %v", addr, err)
	}

	ipAddr, err := net.ResolveIPAddr("ip", host)
	if err != nil || len(ipAddr.IP) == 0 {
		return fmt.Errorf("Unable to resolve destination IP addr %v: %v", host, err)
	}

	if !ipAddr.IP.IsGlobalUnicast() {
		return fmt.Errorf("Not accepting connections to non-global address: %s", addr)
	}

	return nil
}

func (server *Server) checkForDisallowedPort(addr string) error {
	_, portString, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("Unable to split host and port for %v: %v", addr, err)
	}

	port, err := strconv.Atoi(portString)
	if err != nil {
		return fmt.Errorf("Unable to convert port %v to integer: %v", portString, err)
	}

	portAllowed := false
	for _, allowed := range server.AllowedPorts {
		if port == allowed {
			portAllowed = true
			break
		}
	}

	if !portAllowed {
		return fmt.Errorf("Not accepting connections to port %v", port)
	}

	return nil
}

// InitServerCert initializes a PK + cert for use by a server proxy, signed by
// the CA certificate.  We always generate a new certificate just in case.
func (ctx *CertContext) InitServerCert(host string) (err error) {
	if ctx.PK, err = keyman.LoadPKFromFile(ctx.PKFile); err != nil {
		if os.IsNotExist(err) {
			log.Debugf("Creating new PK at: %s", ctx.PKFile)
			if ctx.PK, err = keyman.GeneratePK(2048); err != nil {
				return
			}
			if err = ctx.PK.WriteToFile(ctx.PKFile); err != nil {
				return fmt.Errorf("Unable to save private key: %s", err)
			}
		} else {
			return fmt.Errorf("Unable to read private key, even though it exists: %s", err)
		}
	}

	log.Debugf("Creating new server cert at: %s", ctx.ServerCertFile)
	ctx.ServerCert, err = ctx.PK.TLSCertificateFor("Lantern", host, tenYearsFromToday, true, nil)
	if err != nil {
		return
	}
	err = ctx.ServerCert.WriteToFile(ctx.ServerCertFile)
	if err != nil {
		return
	}
	return nil
}
