package tunio

import (
	"bufio"
	"errors"
	"log"
	"net"
	"net/http"
	"time"
)

var (
	timeout   = time.Second * 120
	keepAlive = time.Second * 120
)

func NewLanternDialer(proxyAddr string) func(proto, addr string) (net.Conn, error) {
	return func(proto, addr string) (net.Conn, error) {
		d := net.Dialer{
			Timeout:   timeout,
			KeepAlive: keepAlive,
		}

		conn, err := d.Dial("tcp", proxyAddr)
		if err != nil {
			return nil, err
		}

		req, err := http.NewRequest("CONNECT", addr, nil)
		if err != nil {
			return nil, err
		}

		req.Host = addr
		if err := req.Write(conn); err != nil {
			return nil, err
		}

		r := bufio.NewReader(conn)
		resp, err := http.ReadResponse(r, req)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode >= 200 && resp.StatusCode <= 299 {
			log.Printf("Dialing %q through Lantern...", addr)
			return conn, nil
		}

		log.Printf("Status code %v.", resp.StatusCode)

		return nil, errors.New("Could not connect to Lantern.")
	}
}
