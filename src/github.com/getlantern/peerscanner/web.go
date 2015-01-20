// main simply contains the primary web serving code that allows peers to
// register and unregister as give mode peers running within the Lantern
// network
package main

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdefaults"
)

const (
	PKFile   = "pk.pem"
	CertFile = "cert.pem"
)

func startHttp() {
	http.HandleFunc("/register", register)
	http.HandleFunc("/unregister", unregister)
	laddr := fmt.Sprintf(":%d", *port)

	tlsConfig := tlsdefaults.Server()
	_, _, err := keyman.StoredPKAndCert(PKFile, CertFile, "Lantern", "localhost")
	if err != nil {
		log.Fatalf("Unable to initialize private key and certificate: %v", err)
	}
	cert, err := tls.LoadX509KeyPair(CertFile, PKFile)
	if err != nil {
		log.Fatalf("Unable to load certificate and key from %s and %s: %s", CertFile, PKFile, err)
	}
	tlsConfig.Certificates = []tls.Certificate{cert}

	log.Debugf("About to listen at %v", laddr)
	l, err := tls.Listen("tcp", laddr, tlsConfig)
	if err != nil {
		log.Fatalf("Unable to listen for tls connections at %s: %s", laddr, err)
	}

	log.Debug("About to serve")
	err = http.Serve(l, nil)
	if err != nil {
		log.Fatalf("Unable to serve: %s", err)
	}
}

// register is the entry point for peers registering themselves with the service.
// If peers are successfully vetted, they'll be added to the DNS round robin.
func register(resp http.ResponseWriter, req *http.Request) {
	name, ip, port, err := getHostInfo(req)
	if err == nil && port != 443 {
		err = fmt.Errorf("Port %d not supported, only port 443 is supported", port)
	}
	if name == "" {
		err = fmt.Errorf("Please specify a name")
	}
	if err != nil {
		resp.WriteHeader(http.StatusBadRequest)
		fmt.Fprintln(resp, err.Error())
		return
	}

	h := getOrCreateHost(name, ip)
	online, connectionRefused := h.status()
	if online {
		resp.WriteHeader(200)
		fmt.Fprintln(resp, "Connectivity to proxy confirmed")
		return
	}

	// Note this may not work across platforms, but the intent
	// is to tell the client if the connection was flat out
	// refused as opposed to timed out in order to allow them
	// to configure their router if possible.
	if connectionRefused {
		// 417 response code.
		resp.WriteHeader(http.StatusExpectationFailed)
		fmt.Fprintln(resp, "No connectivity to proxy - connection refused")
	} else {
		// 408 response code.
		resp.WriteHeader(http.StatusRequestTimeout)
		fmt.Fprintln(resp, "No connectivity to proxy - test request timed out")
	}
}

// unregister is the HTTP endpoint for removing peers from DNS. Peers are
// unregistered based on their ip (not their name).
func unregister(resp http.ResponseWriter, req *http.Request) {
	_, ip, _, err := getHostInfo(req)
	if err != nil {
		resp.WriteHeader(http.StatusBadRequest)
		fmt.Fprintln(resp, err.Error())
		return
	}

	h := getHostByIp(ip)
	msg := "Host not registered"
	if h != nil {
		h.unregister()
		msg = "Host unregistered"
	}
	resp.WriteHeader(200)
	fmt.Fprintln(resp, msg)
}

func getHostInfo(req *http.Request) (name string, ip string, port int, err error) {
	name = req.FormValue("name")
	ip = clientIpFor(req)
	portString := req.FormValue("port")

	if portString != "" {
		port, err = strconv.Atoi(portString)
		if err != nil {
			err = fmt.Errorf("Received invalid port for %v - %v: %v", name, ip, portString)
		}
	}

	return
}

func clientIpFor(req *http.Request) string {
	// Client requested their info
	clientIp := req.Header.Get("X-Forwarded-For")
	if clientIp == "" {
		clientIp = strings.Split(req.RemoteAddr, ":")[0]
	}
	// clientIp may contain multiple ips, use the first
	ips := strings.Split(clientIp, ",")
	return strings.TrimSpace(ips[0])
}
