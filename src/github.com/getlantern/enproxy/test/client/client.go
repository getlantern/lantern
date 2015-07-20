package main

import (
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"os"

	"github.com/getlantern/enproxy"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: client <proxy addr to listen> <proxy server addr>")
	}
	enproxyConfig := &enproxy.Config{
		DialProxy: func(addr string) (net.Conn, error) {
			return net.Dial("tcp", os.Args[2])
		},
		NewRequest: func(host string, method string, body io.Reader) (req *http.Request, err error) {
			if host == "" {
				host = os.Args[2]
			}
			return http.NewRequest(method, "http://"+host+"/", body)
		},
	}
	httpServer := &http.Server{
		Addr: os.Args[1],
		Handler: &ClientHandler{
			ProxyAddr: os.Args[2],
			Config:    enproxyConfig,
			ReverseProxy: &httputil.ReverseProxy{
				Director: func(req *http.Request) {
					// do nothing
				},
				Transport: &http.Transport{
					Dial: func(network string, addr string) (net.Conn, error) {
						return enproxy.Dial(addr, enproxyConfig)
					},
				},
			},
		},
	}
	err := httpServer.ListenAndServe()
	if err != nil {
		log.Fatal(err)
	}
}

type ClientHandler struct {
	ProxyAddr    string
	Config       *enproxy.Config
	ReverseProxy *httputil.ReverseProxy
}

func (c *ClientHandler) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	if req.Method == "CONNECT" {
		c.Intercept(resp, req)
	} else {
		c.ReverseProxy.ServeHTTP(resp, req)
	}
}
