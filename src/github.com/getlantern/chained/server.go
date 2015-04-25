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

	if req.Method != CONNECT {
		resp.WriteHeader(405)
		fmt.Fprintf(resp, "Method %s not allowed", req.Method)
		return
	}

	address := req.Host
	connOut, err := s.Dial("tcp", address)
	if err != nil {
		resp.WriteHeader(502)
		fmt.Fprintf(resp, "Unable to dial %s : %s", address, err)
		return
	}
	defer connOut.Close()
	resp.WriteHeader(200)
	fmt.Fprint(resp, "CONNECT OK")
	fl.Flush()

	connIn, _, err := hj.Hijack()
	if err != nil {
		log.Errorf("Unable to hijack connection: %s", err)
		return
	}
	defer connIn.Close()

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		io.Copy(connOut, connIn)
		wg.Done()
	}()
	go func() {
		go io.Copy(connIn, connOut)
		wg.Done()
	}()
	wg.Wait()
}
