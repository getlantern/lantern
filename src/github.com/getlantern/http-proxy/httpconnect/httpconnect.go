package httpconnect

import (
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/http-proxy/utils"
	"github.com/getlantern/idletiming"
)

var log = golog.LoggerFor("httpconnect")

type HTTPConnectHandler struct {
	next         http.Handler
	idleTimeout  time.Duration
	allowedPorts []int
}

type optSetter func(f *HTTPConnectHandler) error

func IdleTimeoutSetter(i time.Duration) optSetter {
	return func(f *HTTPConnectHandler) error {
		f.idleTimeout = i
		return nil
	}
}

func AllowedPorts(ports []int) optSetter {
	return func(f *HTTPConnectHandler) error {
		f.allowedPorts = ports
		return nil
	}
}

func AllowedPortsFromCSV(csv string) optSetter {
	return func(f *HTTPConnectHandler) error {
		fields := strings.Split(csv, ",")
		ports := make([]int, len(fields))
		for i, f := range fields {
			p, err := strconv.Atoi(f)
			if err != nil {
				return err
			}
			ports[i] = p
		}
		f.allowedPorts = ports
		return nil
	}
}

func New(next http.Handler, setters ...optSetter) (*HTTPConnectHandler, error) {
	if next == nil {
		return nil, errors.New("Next handler is not defined (nil)")
	}
	f := &HTTPConnectHandler{next: next}
	for _, s := range setters {
		if err := s(f); err != nil {
			return nil, err
		}
	}

	return f, nil
}

func (f *HTTPConnectHandler) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	if req.Method != "CONNECT" {
		f.next.ServeHTTP(w, req)
		return
	}

	if log.IsTraceEnabled() {
		reqStr, _ := httputil.DumpRequest(req, true)
		log.Tracef("HTTPConnectHandler Middleware received request:\n%s", reqStr)
	}

	if f.portAllowed(w, req) {
		f.intercept(w, req)
	}
}

func (f *HTTPConnectHandler) portAllowed(w http.ResponseWriter, req *http.Request) bool {
	if len(f.allowedPorts) == 0 {
		return true
	}
	log.Tracef("Checking CONNECT tunnel to %s against allowed ports %v", req.Host, f.allowedPorts)
	_, portString, err := net.SplitHostPort(req.Host)
	if err != nil {
		// CONNECT request should always include port in req.Host.
		// Ref https://tools.ietf.org/html/rfc2817#section-5.2.
		f.ServeError(w, req, http.StatusBadRequest, "No port field in Request-URI / Host header")
		return false
	}
	port, err := strconv.Atoi(portString)
	if err != nil {
		f.ServeError(w, req, http.StatusBadRequest, "Invalid port")
		return false
	}

	for _, p := range f.allowedPorts {
		if port == p {
			return true
		}
	}
	f.ServeError(w, req, http.StatusForbidden, "Port not allowed")
	return false
}

func (f *HTTPConnectHandler) intercept(w http.ResponseWriter, req *http.Request) (err error) {
	utils.RespondOK(w, req)

	clientConn, _, err := w.(http.Hijacker).Hijack()
	if err != nil {
		utils.RespondBadGateway(w, req, fmt.Sprintf("Unable to hijack connection: %s", err))
		return
	}
	connOutRaw, err := net.Dial("tcp", req.Host)
	if err != nil {
		return
	}
	connOut := idletiming.Conn(connOutRaw, f.idleTimeout, func() {
		if connOutRaw != nil {
			connOutRaw.Close()
		}
	})

	// Pipe data through CONNECT tunnel
	closeConns := func() {
		if clientConn != nil {
			if err := clientConn.Close(); err != nil {
				log.Debugf("Error closing the out connection: %s", err)
			}
		}
		if connOut != nil {
			if err := connOut.Close(); err != nil {
				log.Debugf("Error closing the client connection: %s", err)
			}
		}
	}
	var closeOnce sync.Once
	go func() {
		if _, err := io.Copy(connOut, clientConn); err != nil {
			log.Debug(err)
		}
		closeOnce.Do(closeConns)

	}()
	if _, err := io.Copy(clientConn, connOut); err != nil {
		log.Debug(err)
	}
	closeOnce.Do(closeConns)

	return
}

func (f *HTTPConnectHandler) ServeError(w http.ResponseWriter, req *http.Request, statusCode int, reason string) {
	log.Debugf("Respond error to CONNECT request to %s: %d %s", req.Host, statusCode, reason)
	w.WriteHeader(statusCode)
	w.Write([]byte(reason))
}
