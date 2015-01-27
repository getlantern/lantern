package client

import (
	"log"
	"net/http"
	"net/http/httputil"
	"time"
)

func (client *Client) initReverseProxy() {
	rp := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			// do nothing
		},
		Transport: &http.Transport{
			// We disable keepalives because some servers pretend to support
			// keep-alives but close their connections immediately, which
			// causes an error inside ReverseProxy.  This is not an issue
			// for HTTPS because  the browser is responsible for handling
			// the problem, which browsers like Chrome and Firefox already
			// know to do.
			//
			// See https://code.google.com/p/go/issues/detail?id=4677
			DisableKeepAlives: true,
			// TODO: would be good to make this sensitive to QOS, which
			// right now is only respected for HTTPS connections. The
			// challenge is that ReverseProxy reuses connections for
			// different requests, so we might have to configure different
			// ReverseProxies for different QOS's or something like that.
			Dial: client.getBalancer().Dial,
		},
		// Set a FlushInterval to prevent overly aggressive buffering of
		// responses, which helps keep memory usage down
		FlushInterval: 250 * time.Millisecond,
	}

	if client.rpInitialized {
		log.Printf("Draining reverse proxy channel.")
		<-client.rpCh
	} else {
		log.Printf("Creating reverse proxy channel.")
		client.rpCh = make(chan *httputil.ReverseProxy, 1)
	}

	log.Printf("Publishing reverse proxy.")
	client.rpCh <- rp
}

func (client *Client) getReverseProxy() *httputil.ReverseProxy {
	rp := <-client.rpCh
	client.rpCh <- rp
	return rp
}
