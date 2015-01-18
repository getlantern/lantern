// main simply contains the primary web serving code that allows peers to
// register and unregister as give mode peers running within the Lantern
// network
package main

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

func startHttp() {
	http.HandleFunc("/register", register)
	http.HandleFunc("/unregister", unregister)
	http.ListenAndServe(fmt.Sprintf(":%d", *port), nil)
}

// register is the entry point for peers registering themselves with the service.
// If peers are successfully vetted, they'll be added to the DNS round robin.
func register(resp http.ResponseWriter, req *http.Request) {
	name, ip, port, err := getHostInfo(req)
	if err == nil && port != 443 {
		err = fmt.Errorf("Port %d not supported, only port 443 is supported", port)
	}
	if err != nil {
		resp.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(resp, err.Error())
		return
	}

	h := getOrCreateHost(name, ip)
	online, connectionRefused := h.status()
	if online {
		resp.WriteHeader(200)
		return
	}

	// Note this may not work across platforms, but the intent
	// is to tell the client if the connection was flat out
	// refused as opposed to timed out in order to allow them
	// to configure their router if possible.
	if connectionRefused {
		// 417 response code.
		resp.WriteHeader(http.StatusExpectationFailed)
	} else {
		// 408 response code.
		resp.WriteHeader(http.StatusRequestTimeout)
	}
}

// unregister is the HTTP endpoint for removing peers from DNS.
func unregister(resp http.ResponseWriter, req *http.Request) {
	name, ip, _, err := getHostInfo(req)
	if err != nil {
		resp.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(resp, err.Error())
		return
	}

	h := getHost(name, ip)
	msg := "Host not registered"
	if h != nil {
		h.unregister()
		msg = "Host unregistered"
	}
	resp.WriteHeader(200)
	fmt.Fprint(resp, msg)
}

func getHostInfo(req *http.Request) (name string, ip string, port int, err error) {
	name = req.FormValue("name")
	ip = clientIpFor(req)
	portString := req.FormValue("port")

	if portString != "" {
		port, err = strconv.Atoi(portString)
		if err != nil {
			err = fmt.Errorf("Received invalid port for %v - %v: %d", name, ip, portString)
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
