// package main provides a simple proxy program that uses detour, useful for
// performance testing.
package main

import (
	"log"

	"net"
	"net/http"
	"net/http/httputil"

	"github.com/getlantern/detour"
)

func main() {
	go func() {
		log.Println("Starting standard proxy at localhost:8081")
		http.ListenAndServe("localhost:8081", &httputil.ReverseProxy{
			Director: func(req *http.Request) {},
		})
	}()
	log.Println("Starting detour proxy at localhost:8080")
	http.ListenAndServe("localhost:8080", &httputil.ReverseProxy{
		Director: func(req *http.Request) {},
		Transport: &http.Transport{
			// This just detours to net.Dial, meaning that it doesn't accomplish any
			// unblocking, it's just here for performance testing.
			Dial: detour.Dialer(net.Dial),
		},
	})
}
