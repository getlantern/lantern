package chained

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"sync"
)

// Server provides the upstream side of a chained proxy setup. It can be run as
// a standalone HTTP server using Serve() or plugged into an existing HTTP
// server as an http.Handler.
type Server struct {
	// Dial: function for dialing destination
	Dial func(network, address string) (net.Conn, error)
}

// Serve provides a convenience function for starting an HTTP server using this
// Server as the Handler.
func (s *Server) Serve(l net.Listener) error {
	server := http.Server{
		Handler: s,
	}
	return server.Serve(l)
}

// ServeHTTP implements the method from http.Handler.
func (s *Server) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	hj, ok := resp.(http.Hijacker)
	if !ok {
		panic("Response doesn't allow hijacking!")
	}

	fl, ok := resp.(http.Flusher)
	if !ok {
		panic("Response doesn't allow flushing!")
	}

	if req.Method != httpConnectMethod {
		resp.WriteHeader(http.StatusMethodNotAllowed)
		fmt.Fprintf(resp, "Method %s not allowed", req.Method)
		return
	}

	address := req.Host
	connOut, err := s.Dial("tcp", address)
	if err != nil {
		resp.WriteHeader(http.StatusBadGateway)
		fmt.Fprintf(resp, "Unable to dial %s : %s", address, err)
		return
	}

	closeConnection := func(conn net.Conn) {
		if err := conn.Close(); err != nil {
			log.Errorf("Unable to close connection: %v", err)
		}
	}

	defer closeConnection(connOut)
	resp.WriteHeader(http.StatusOK)
	fmt.Fprint(resp, "CONNECT OK")
	fl.Flush()

	connIn, _, err := hj.Hijack()
	if err != nil {
		log.Errorf("Unable to hijack connection: %s", err)
		return
	}
	defer closeConnection(connIn)

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		if _, err := io.Copy(connOut, connIn); err != nil {
			log.Errorf("Unable to pipe in->out: %v", err)
		}
		wg.Done()
	}()
	go func() {
		if _, err := io.Copy(connIn, connOut); err != nil {
			log.Errorf("Unable to pipe out->in: %v", err)
		}
		wg.Done()
	}()
	wg.Wait()
}
