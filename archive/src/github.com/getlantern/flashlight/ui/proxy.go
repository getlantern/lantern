// +build pro-experimental

package ui

import (
	"net/http"
	"net/http/httputil"
)

var proxyHandler = httputil.ReverseProxy{
	Director: func(r *http.Request) {
		r.Header.Set("Access-Control-Request-Headers", "X-Lantern-Device-Id, X-Lantern-Pro-Token, X-Lantern-User-Id")
		r.URL.Scheme = "https"
		r.URL.Host = "quiet-island-5559.herokuapp.com"
		r.Host = r.URL.Host
	},
}

func initProServer(addr string) {
	go func() {
		err := http.ListenAndServe(addr, &proxyHandler)
		log.Fatal(err)
	}()
}
