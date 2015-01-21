package server

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"os"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/fronted"
	"github.com/getlantern/go-igdman/igdman"
	"github.com/getlantern/golog"
	"github.com/getlantern/nattywad"
	"github.com/getlantern/waddell"

	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/nattest"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
)

const (
	PortmapFailure = 50
)

var (
	log = golog.LoggerFor("flashlight.server")

	registerPeriod = 5 * time.Minute
)

type Server struct {
	// Addr: listen address in form of host:port
	Addr string

	// Host: FQDN that is guaranteed to hit this server
	Host string

	// ReadTimeout: (optional) timeout for read ops
	ReadTimeout time.Duration

	// WriteTimeout: (optional) timeout for write ops
	WriteTimeout time.Duration

	CertContext                *fronted.CertContext // context for certificate management
	AllowNonGlobalDestinations bool                 // if true, requests to LAN, Loopback, etc. will be allowed
	AllowedPorts               []int                // if specified, only connections to these ports will be allowed

	waddellClient  *waddell.Client
	nattywadServer *nattywad.Server
	cfg            *ServerConfig
	cfgMutex       sync.RWMutex
}

func (server *Server) Configure(newCfg *ServerConfig) {
	server.cfgMutex.Lock()
	defer server.cfgMutex.Unlock()

	oldCfg := server.cfg

	log.Debug("Server.Configure() called")
	if oldCfg != nil && reflect.DeepEqual(oldCfg, newCfg) {
		log.Debugf("Server configuration unchanged")
		return
	}

	if oldCfg == nil || newCfg.Portmap != oldCfg.Portmap {
		// Portmap changed
		if oldCfg != nil && oldCfg.Portmap > 0 {
			log.Debugf("Attempting to unmap old external port %d", oldCfg.Portmap)
			err := unmapPort(oldCfg.Portmap)
			if err != nil {
				log.Errorf("Unable to unmap old external port: %s", err)
			}
			log.Debugf("Unmapped old external port %d", oldCfg.Portmap)
		}

		if newCfg.Portmap > 0 {
			log.Debugf("Attempting to map new external port %d", newCfg.Portmap)
			err := mapPort(server.Addr, newCfg.Portmap)
			if err != nil {
				log.Errorf("Unable to map new external port: %s", err)
				os.Exit(PortmapFailure)
			}
			log.Debugf("Mapped new external port %d", newCfg.Portmap)
		}
	}

	nattywadIsEnabled := newCfg.WaddellAddr != ""
	nattywadWasEnabled := server.nattywadServer != nil
	waddellAddrChanged := oldCfg == nil && newCfg.WaddellAddr != "" || oldCfg != nil && oldCfg.WaddellAddr != newCfg.WaddellAddr

	if waddellAddrChanged {
		if nattywadWasEnabled {
			server.stopNattywad()
		}
		if nattywadIsEnabled {
			server.startNattywad(newCfg.WaddellAddr)
		}
	}

	server.cfg = newCfg
}

func (server *Server) ListenAndServe() error {
	if server.Host != "" {
		log.Debugf("Running as host %s", server.Host)
	}

	fs := &fronted.Server{
		Addr:                       server.Addr,
		Host:                       server.Host,
		ReadTimeout:                server.ReadTimeout,
		WriteTimeout:               server.WriteTimeout,
		CertContext:                server.CertContext,
		AllowNonGlobalDestinations: server.AllowNonGlobalDestinations,
		AllowedPorts:               server.AllowedPorts,
	}

	if server.cfg.Unencrypted {
		log.Debug("Running in unencrypted mode")
		fs.CertContext = nil
	}

	// Add callbacks to track bytes given
	fs.OnBytesReceived = func(ip string, destAddr string, req *http.Request, bytes int64) {
		onBytesGiven(destAddr, req, bytes)
		statserver.OnBytesReceived(ip, bytes)
	}
	fs.OnBytesSent = func(ip string, destAddr string, req *http.Request, bytes int64) {
		onBytesGiven(destAddr, req, bytes)
		statserver.OnBytesSent(ip, bytes)
	}

	l, err := fs.Listen()
	if err != nil {
		return fmt.Errorf("Unable to listen at %s: %s", server.Addr, err)
	}

	go server.register()

	return fs.Serve(l)
}

func (server *Server) register() {
	for {
		server.cfgMutex.RLock()
		baseUrl := server.cfg.RegisterAt
		server.cfgMutex.RUnlock()
		if baseUrl != "" {
			if globals.InstanceId == "" {
				log.Error("Unable to register server because no InstanceId is configured")
			} else {
				log.Debugf("Registering server at %v", baseUrl)
				registerUrl := baseUrl + "/register"
				vals := url.Values{
					"name": []string{globals.InstanceId},
					"port": []string{"443"},
				}
				resp, err := http.PostForm(registerUrl, vals)
				if err != nil {
					log.Errorf("Unable to register at %v: %v", registerUrl, err)
				} else if resp.StatusCode != 200 {
					bodyString, _ := ioutil.ReadAll(resp.Body)
					log.Errorf("Unexpected response status registering at %v: %d    %v", registerUrl, resp.StatusCode, string(bodyString))
				} else {
					log.Debugf("Successfully registered server at %v", registerUrl)
				}
				resp.Body.Close()
				time.Sleep(registerPeriod)
			}
		}
	}
}

func (server *Server) startNattywad(waddellAddr string) {
	log.Debugf("Connecting to waddell at: %s", waddellAddr)
	var err error
	server.waddellClient, err = waddell.NewClient(&waddell.ClientConfig{
		Dial: func() (net.Conn, error) {
			return net.Dial("tcp", waddellAddr)
		},
		ServerCert:        globals.WaddellCert,
		ReconnectAttempts: 10,
		OnId: func(id waddell.PeerId) {
			log.Debugf("Connected to Waddell!! Id is: %s", id)
		},
	})
	if err != nil {
		log.Errorf("Unable to connect to waddell: %s", err)
		server.waddellClient = nil
		return
	}
	server.nattywadServer = &nattywad.Server{
		Client: server.waddellClient,
		OnSuccess: func(local *net.UDPAddr, remote *net.UDPAddr) bool {
			err := nattest.Serve(local)
			if err != nil {
				log.Error(err.Error())
				return false
			}
			return true
		},
	}
	server.nattywadServer.Start()
}

func (server *Server) stopNattywad() {
	log.Debug("Stopping nattywad server")
	server.nattywadServer.Stop()
	server.nattywadServer = nil
	log.Debug("Stopping waddell client")
	server.waddellClient.Close()
	server.waddellClient = nil
}

func mapPort(addr string, port int) error {
	internalIP, internalPortString, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("Unable to split host and port for %v: %v", addr, err)
	}

	internalPort, err := strconv.Atoi(internalPortString)
	if err != nil {
		return fmt.Errorf("Unable to parse local port: ")
	}

	if internalIP == "" {
		internalIP, err = determineInternalIP()
		if err != nil {
			return fmt.Errorf("Unable to determine internal IP: %s", err)
		}
	}

	igd, err := igdman.NewIGD()
	if err != nil {
		return fmt.Errorf("Unable to get IGD: %s", err)
	}

	igd.RemovePortMapping(igdman.TCP, port)
	err = igd.AddPortMapping(igdman.TCP, internalIP, internalPort, port, 0)
	if err != nil {
		return fmt.Errorf("Unable to map port with igdman %d: %s", port, err)
	}

	return nil
}

func unmapPort(port int) error {
	igd, err := igdman.NewIGD()
	if err != nil {
		return fmt.Errorf("Unable to get IGD: %s", err)
	}

	igd.RemovePortMapping(igdman.TCP, port)
	if err != nil {
		return fmt.Errorf("Unable to unmap port with igdman %d: %s", port, err)
	}

	return nil
}

// determineInternalIP determines the internal IP to use for mapping ports. It
// does this by dialing a website on the public Internet and then finding out
// the LocalAddr for the corresponding connection. This gives us an interface
// that we know has Internet access, which makes it suitable for port mapping.
func determineInternalIP() (string, error) {
	conn, err := net.DialTimeout("tcp", "s3.amazonaws.com:443", 20*time.Second)
	if err != nil {
		return "", fmt.Errorf("Unable to determine local IP: %s", err)
	}
	defer conn.Close()
	host, _, err := net.SplitHostPort(conn.LocalAddr().String())
	return host, err
}

func onBytesGiven(destAddr string, req *http.Request, bytes int64) {
	host, port, _ := net.SplitHostPort(destAddr)
	if port == "" {
		port = "0"
	}

	given := statreporter.CountryDim().
		And("flserver", globals.InstanceId).
		And("destport", port)
	given.Increment("bytesGiven").Add(bytes)
	given.Increment("bytesGivenByFlashlight").Add(bytes)

	clientCountry := req.Header.Get("Cf-Ipcountry")
	if clientCountry != "" {
		givenTo := statreporter.Country(clientCountry)
		givenTo.Increment("bytesGivenTo").Add(bytes)
		givenTo.Increment("bytesGivenToByFlashlight").Add(bytes)
		givenTo.Member("distinctDestHosts", host)

		clientIp := req.Header.Get("X-Forwarded-For")
		if clientIp != "" {
			// clientIp may contain multiple ips, use the first
			ips := strings.Split(clientIp, ",")
			clientIp := strings.TrimSpace(ips[0])
			givenTo.Member("distinctClients", clientIp)
		}

	}
}
