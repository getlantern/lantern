package enproxy

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	DEFAULT_BYTES_BEFORE_FLUSH = 1024768
	DEFAULT_READ_BUFFER_SIZE   = 65536
)

var (
	r = regexp.MustCompile("/(.*)/(.*)/(.*)/")
)

// Proxy is the server side to an enproxy.Client.  Proxy implements the
// http.Handler interface for plugging into an HTTP server, and it also
// provides a convenience ListenAndServe() function for quickly starting up
// a dedicated HTTP server using this Proxy as its handler.
type Proxy struct {
	// Dial: function used to dial the destination server.  If nil, a default
	// TCP dialer is used.
	Dial dialFunc

	// Host: (Deprecated; use HostFn instead) FQDN of this particular proxy.
	// Either this or HostFn is required if this server was originally reached
	// by DNS round robin.
	Host string

	// HostFn: given a http.Request, return the FQDN of this particular proxy,
	// hopefully through the same front.  This is used to support multiple
	// domain fronts.  Either this or Host is required if this server was
	// originally reached by DNS round robin.
	HostFn func(*http.Request) string

	// FlushTimeout: how long to let reads idle before writing out a
	// response to the client.  Defaults to 35 milliseconds.
	FlushTimeout time.Duration

	// BytesBeforeFlush: how many bytes to read before flushing response to
	// client.  Periodically flushing the response keeps the response buffer
	// from getting too big when processing big downloads.
	BytesBeforeFlush int

	// IdleTimeout: how long to wait before closing an idle connection, defaults
	// to 70 seconds
	IdleTimeout time.Duration

	// ReadBufferSize: size of read buffer in bytes
	ReadBufferSize int

	// OnBytesReceived is an optional callback for learning about bytes received
	// from a client
	OnBytesReceived statCallback

	// OnBytesSent is an optional callback for learning about bytes sent to a
	// client
	OnBytesSent statCallback

	// Allow: Optional function that checks whether the given request to the
	// given destAddr is allowed.  If it is not allowed, this function should
	// return the HTTP error code and an error.
	Allow func(req *http.Request, destAddr string) (int, error)

	// connMap: map of outbound connections by their id
	connMap map[string]*lazyConn

	// connMapMutex: synchronizes access to connMap
	connMapMutex sync.RWMutex
}

// statCallback is a function for receiving stat information.
//
// clientIp: ip address of client
// destAddr: the destination address to which we're proxying
// req: the http.Request that's being served
// countryCode: the country-code of the client (only available when using CloudFlare)
// bytes: the number of bytes sent/received
type statCallback func(
	clientIp string,
	destAddr string,
	req *http.Request,
	bytes int64)

// Start() starts this proxy
func (p *Proxy) Start() {
	if p.Dial == nil {
		p.Dial = func(addr string) (net.Conn, error) {
			return net.Dial("tcp", addr)
		}
	}
	if p.FlushTimeout == 0 {
		p.FlushTimeout = defaultReadFlushTimeout
	}
	if p.IdleTimeout == 0 {
		p.IdleTimeout = defaultIdleTimeoutServer
	}
	if p.ReadBufferSize == 0 {
		p.ReadBufferSize = DEFAULT_READ_BUFFER_SIZE
	}
	if p.BytesBeforeFlush == 0 {
		p.BytesBeforeFlush = DEFAULT_BYTES_BEFORE_FLUSH
	}
	p.connMap = make(map[string]*lazyConn)
}

// ListenAndServe: convenience function for quickly starting up a dedicated HTTP
// server using this Proxy as its handler
func (p *Proxy) ListenAndServe(addr string) error {
	l, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("Unable to listen at %v: %v", addr, err)
	}
	return p.Serve(l)
}

// Serve: convenience function for quickly starting up a dedicated HTTP server
// using this Proxy as its handler
func (p *Proxy) Serve(l net.Listener) error {
	p.Start()
	httpServer := &http.Server{
		Handler:      p,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}
	return httpServer.Serve(l)
}

func (p *Proxy) parseRequestPath(path string) (string, string, string, error) {
	log.Debugf("Path is %v", path)
	strs := r.FindStringSubmatch(path)
	if len(strs) < 4 {
		return "", "", "", fmt.Errorf("Unexpected request path: %v", path)
	}
	return strs[1], strs[2], strs[3], nil
}

func (p *Proxy) parseRequestProps(req *http.Request) (string, string, string, error) {
	// If it's a reasonably long path, it likely follows our new request URI format:
	// /X-Enproxy-Id/X-Enproxy-Dest-Addr/X-Enproxy-Op
	if len(req.URL.Path) > 5 {
		return p.parseRequestPath(req.URL.Path)
	}

	id := req.Header.Get(X_ENPROXY_ID)
	if id == "" {
		return "", "", "", fmt.Errorf("No id found in header %s", X_ENPROXY_ID)
	}

	addr := req.Header.Get(X_ENPROXY_DEST_ADDR)
	if addr == "" {
		return "", "", "", fmt.Errorf("No address found in header %s", X_ENPROXY_DEST_ADDR)
	}

	op := req.Header.Get(X_ENPROXY_OP)
	return id, addr, op, nil
}

// ServeHTTP: implements the http.Handler interface
func (p *Proxy) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	resp.Header().Set("Lantern-IP", req.Header.Get("X-Forwarded-For"))
	resp.Header().Set("Lantern-Country", req.Header.Get("Cf-Ipcountry"))

	if req.Method == "HEAD" {
		// Just respond OK to HEAD requests (used for health checks)
		resp.WriteHeader(200)
		return
	}

	id, addr, op, er := p.parseRequestProps(req)
	if er != nil {
		respond(http.StatusBadRequest, resp, er.Error())
		log.Errorf("Could not parse enproxy data: %v", er)
		return
	}
	log.Debugf("Parsed enproxy data id: %v, addr: %v, op: %v", id, addr, op)

	lc, isNew, err := p.getLazyConn(id, addr, req, resp)
	if err != nil {
		// Close the connection?
		return
	}
	connOut, err := lc.get()
	if err != nil {
		respond(http.StatusInternalServerError, resp, fmt.Sprintf("Unable to get outoing connection to destination server: %v", err))
		return
	}

	if op == OP_WRITE {
		p.handleWrite(resp, req, lc, connOut, isNew)
	} else if op == OP_READ {
		p.handleRead(resp, req, lc, connOut, true)
	} else {
		respond(http.StatusInternalServerError, resp, fmt.Sprintf("Operation not supported: %v", op))
	}
}

// handleWrite forwards the data from a POST to the outbound connection
func (p *Proxy) handleWrite(resp http.ResponseWriter, req *http.Request, lc *lazyConn, connOut net.Conn, first bool) {
	// Pipe request
	n, err := io.Copy(connOut, req.Body)
	if p.OnBytesReceived != nil && n > 0 {
		clientIp := clientIpFor(req)
		if clientIp != "" {
			p.OnBytesReceived(clientIp, lc.addr, req, n)
		}
	}
	if err != nil && err != io.EOF {
		respond(http.StatusInternalServerError, resp, fmt.Sprintf("Unable to write to connOut: %s", err))
		return
	}
	host := ""
	if p.HostFn != nil {
		host = p.HostFn(req)
	}
	// Falling back on deprecated mechanism for backwards compatibility
	if host == "" {
		host = p.Host
	}
	if host != "" {
		// Enable sticky routing (see the comment on HostFn above).
		resp.Header().Set(X_ENPROXY_PROXY_HOST, host)
	}
	if first {
		// On first write, immediately do some reading
		p.handleRead(resp, req, lc, connOut, false)
	} else {
		resp.WriteHeader(200)
	}
}

// handleRead streams the data from the outbound connection to the client as
// a response body.  If no data is read for more than FlushTimeout, then the
// response is finished and client needs to make a new GET request.
func (p *Proxy) handleRead(resp http.ResponseWriter, req *http.Request, lc *lazyConn, connOut net.Conn, waitForData bool) {
	if lc.hitEOF {
		// We hit EOF on the server while processing a previous request,
		// immediately return EOF to the client
		resp.Header().Set(X_ENPROXY_EOF, "true")
		// Echo back connection id (for debugging purposes)
		resp.Header().Set(X_ENPROXY_ID, lc.id)
		resp.WriteHeader(200)
		return
	}

	// Get clientIp for reporting stats
	clientIp := clientIpFor(req)

	b := make([]byte, p.ReadBufferSize)
	first := true
	haveRead := false
	bytesInBatch := 0
	lastReadTime := time.Now()
	for {
		readDeadline := time.Now().Add(p.FlushTimeout)
		if err := connOut.SetReadDeadline(readDeadline); err != nil {
			log.Debugf("Unable to set read deadline: %v", err)
		}

		// Read
		n, readErr := connOut.Read(b)
		if first {
			if readErr == io.EOF {
				// Reached EOF, tell client using a special header
				resp.Header().Set(X_ENPROXY_EOF, "true")
			}
			// Echo back connection id (for debugging purposes)
			resp.Header().Set(X_ENPROXY_ID, lc.id)
			// Always respond 200 OK
			resp.WriteHeader(200)
			first = false
		}

		// Write if necessary
		if n > 0 {
			if clientIp != "" && p.OnBytesSent != nil && n > 0 {
				p.OnBytesSent(clientIp, lc.addr, req, int64(n))
			}

			haveRead = true
			lastReadTime = time.Now()
			bytesInBatch = bytesInBatch + n
			_, writeErr := resp.Write(b[:n])
			if writeErr != nil {
				log.Errorf("Error writing to response: %s", writeErr)
				if err := connOut.Close(); err != nil {
					log.Debugf("Unable to close out connection: %v", err)
				}
				return
			}
		}

		// Inspect readErr to decide whether or not to continue reading
		if readErr != nil {
			switch e := readErr.(type) {
			case net.Error:
				if e.Timeout() {
					if n == 0 {
						// We didn't read anything, might be time to return to
						// client
						if !waitForData {
							// We're not supposed to wait for data, so just
							// return right away
							return
						}
						if haveRead {
							// We've read some data, so return right away so
							// that client doesn't have to wait
							return
						}
					}
				} else {
					return
				}
			default:
				if readErr == io.EOF {
					lc.hitEOF = true
				} else {
					log.Errorf("Unexpected error reading from upstream: %s", readErr)
					// TODO: probably want to close connOut right away
				}
				return
			}
		}

		if time.Now().Sub(lastReadTime) > 10*time.Second {
			// We've spent more than 10 seconds without reading, return so that
			// CloudFlare doesn't time us out
			// TODO: Fastly has much more configurable timeouts, might be able to bump this up
			return
		}

		if bytesInBatch > p.BytesBeforeFlush {
			// We've read a good chunk, flush the response to keep its buffer
			// from getting too big.
			resp.(http.Flusher).Flush()
			bytesInBatch = 0
		}
	}
}

// getLazyConn gets the lazyConn corresponding to the given id and addr, or
// creates a new one and saves it to connMap.
func (p *Proxy) getLazyConn(id string, addr string, req *http.Request, resp http.ResponseWriter) (l *lazyConn, isNew bool, err error) {
	p.connMapMutex.RLock()
	l = p.connMap[id]
	p.connMapMutex.RUnlock()
	if l != nil {
		return l, false, nil
	}
	return p.newOutgoingConn(id, addr, req, resp)
}

// newOutgoingConn creates a new outoing connection and stores it in the connection cache.
func (p *Proxy) newOutgoingConn(id string, addr string, req *http.Request, resp http.ResponseWriter) (l *lazyConn, isNew bool, err error) {
	if p.Allow != nil {
		log.Trace("Checking if connection is allowed")
		code, err := p.Allow(req, addr)
		if err != nil {
			respond(code, resp, err.Error())
			return nil, false, fmt.Errorf("Not allowed: %v", err)
		}
	}
	l = p.newLazyConn(id, addr)
	p.connMapMutex.Lock()
	p.connMap[id] = l
	p.connMapMutex.Unlock()
	return l, true, nil
}

func clientIpFor(req *http.Request) string {
	clientIp := req.Header.Get("X-Forwarded-For")
	if clientIp == "" {
		clientIp, _, err := net.SplitHostPort(req.RemoteAddr)
		if err != nil {
			log.Debugf("Unable to split RemoteAddr %v: %v", err)
			return ""
		}
		return clientIp
	}
	// clientIp may contain multiple ips, use the first
	ips := strings.Split(clientIp, ",")
	return strings.TrimSpace(ips[0])
}

func respond(status int, resp http.ResponseWriter, msg string) {
	log.Errorf(msg)
	resp.WriteHeader(status)
	if _, err := resp.Write([]byte(msg)); err != nil {
		log.Debugf("Unable to write response: %v", err)
	}
}
