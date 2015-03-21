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

	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
	"github.com/getlantern/fronted"
	"github.com/getlantern/go-igdman/igdman"
	"github.com/getlantern/golog"
	"github.com/getlantern/yaml"
)

const (
	PortmapFailure = 50
)

var (
	log               = golog.LoggerFor("flashlight.server")
	registerPeriod    = 5 * time.Minute
	frontingProviders = map[string]func(*http.Request) bool{
		// WARNING: If you add a provider here, keep in mind that Go's http
		// library normalizes all header names so the first letter of every
		// dash-separated "word" is uppercase while all others are lowercase.
		// Also, try and check more than one header to lean on the safe side.
		"cloudflare": func(req *http.Request) bool {
			return hasHeader(req, "Cf-Connecting-Ip") || hasHeader(req, "Cf-Ipcountry") || hasHeader(req, "Cf-Ray") || hasHeader(req, "Cf-Visitor")
		},
		"cloudfront": func(req *http.Request) bool {
			return hasHeader(req, "X-Amz-Cf-Id") || headerMatches(req, "User-Agent", "Amazon Cloudfront")
		},
	}
)

func headerMatches(req *http.Request, name string, value string) bool {
	for _, entry := range req.Header[name] {
		if entry == value {
			return true
		}
	}
	return false
}

func hasHeader(req *http.Request, name string) bool {
	return req.Header[name] != nil
}

type Server struct {
	// Addr: listen address in form of host:port
	Addr string

	// HostFn: Function mapping a http.Request to a FQDN that is guaranteed to
	// hit this server through the same front as the request.
	HostFn func(*http.Request) string

	// ReadTimeout: (optional) timeout for read ops
	ReadTimeout time.Duration

	// WriteTimeout: (optional) timeout for write ops
	WriteTimeout time.Duration

	CertContext                *fronted.CertContext // context for certificate management
	AllowNonGlobalDestinations bool                 // if true, requests to LAN, Loopback, etc. will be allowed
	AllowedPorts               []int                // if specified, only connections to these ports will be allowed

	cfg      *ServerConfig
	cfgMutex sync.RWMutex
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
	if newCfg.FrontFQDNs != nil {
		server.HostFn = hostFn(newCfg.FrontFQDNs)
	}
	server.cfg = newCfg
}

func (server *Server) ListenAndServe(updateConfig func(func(*ServerConfig) error)) error {

	fs := &fronted.Server{
		Addr:                       server.Addr,
		HostFn:                     server.HostFn,
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

	go server.register(updateConfig)

	return fs.Serve(l)
}

func (server *Server) register(updateConfig func(func(*ServerConfig) error)) {
	supportedFronts := make([]string, 0, len(frontingProviders))
	for name := range frontingProviders {
		supportedFronts = append(supportedFronts, name)
	}
	for {
		server.cfgMutex.RLock()
		baseUrl := server.cfg.RegisterAt
		var port string
		if server.cfg.Unencrypted {
			port = "80"
		} else {
			port = "443"
		}
		server.cfgMutex.RUnlock()
		if baseUrl != "" {
			if globals.InstanceId == "" {
				log.Error("Unable to register server because no InstanceId is configured")
			} else {
				log.Debugf("Registering server at %v", baseUrl)
				registerUrl := baseUrl + "/register"
				vals := url.Values{
					"name":   []string{globals.InstanceId},
					"port":   []string{port},
					"fronts": supportedFronts,
				}
				resp, err := http.PostForm(registerUrl, vals)
				if err != nil {
					log.Errorf("Unable to register at %v: %v", registerUrl, err)
				} else if resp.StatusCode != 200 {
					body, _ := ioutil.ReadAll(resp.Body)
					log.Errorf("Unexpected response status registering at %v: %d    %v", registerUrl, resp.StatusCode, string(body))
				} else {
					log.Debugf("Successfully registered server at %v", registerUrl)
					body, _ := ioutil.ReadAll(resp.Body)
					for _, line := range strings.Split(string(body), "\n") {
						if strings.HasPrefix(line, "frontfqdns: ") {
							yamlStr := line[len("frontfqdns: "):]
							newFqdns, err := ParseFrontFQDNs(yamlStr)
							if err == nil {
								updateConfig(func(cfg *ServerConfig) error {
									cfg.FrontFQDNs = newFqdns
									return nil
								})
							} else {
								log.Errorf("Unable to parse frontfqdns from peerscanner '%v': %v", yamlStr, err)
							}
						}
					}
				}
				if err == nil {
					resp.Body.Close()
				}
				time.Sleep(registerPeriod)
			}
		}
	}
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

func hostFn(fqdns map[string]string) func(*http.Request) string {
	// We prefer to use the fronting provider through which we have been
	// reached, because we expect that to be unblocked, but if something goes
	// wrong (e.g. in old give mode peers) we'll use just any configured host.
	return func(req *http.Request) string {
		for provider, fn := range frontingProviders {
			if fn(req) {
				fqdn, found := fqdns[provider]
				if found {
					return fqdn
				}
			}
		}
		// We don't know about this provider or we don't have a fqdn for it...
		// The best we can do is provide *some* FQDN through which we hope we
		// can be reached.
		log.Debugf("Falling back to just any FQDN")
		for _, fqdn := range fqdns {
			return fqdn
		}
		// We don't know of any fqdns.  This will be treated like a null
		// hostFn.
		return ""
	}
}

func ParseFrontFQDNs(frontFQDNs string) (map[string]string, error) {
	fqdns := map[string]string{}
	if err := yaml.Unmarshal([]byte(frontFQDNs), fqdns); err != nil {
		return nil, err
	}
	return fqdns, nil
}
