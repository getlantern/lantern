package tunio

import (
	"bufio"
	"errors"
	"net"
	"net/http"
	"time"
)

var (
	timeout   = time.Second * 120
	keepAlive = time.Second * 120
)

type dialerFn func(proto, addr string) (net.Conn, error)

func NewLanternDialer(proxyAddr string, dial dialerFn) dialerFn {
	if dial == nil {
		d := net.Dialer{
			Timeout:   timeout,
			KeepAlive: keepAlive,
		}
		dial = d.Dial
	}
	return func(proto, addr string) (net.Conn, error) {
		conn, err := dial("tcp", proxyAddr)
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
			return conn, nil
		}

		return nil, errors.New("Could not connect to Lantern.")
	}
}
