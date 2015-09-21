// This dummy socks server is using for testing.
// go run main.go
package main

import (
	"github.com/getlantern/lantern-mobile/lantern"
	"github.com/getlantern/lantern-mobile/lantern/interceptor"
	"log"
	"time"
)

var inter *interceptor.Interceptor

const (
	listenAddr = "0.0.0.0:8788"
)

func startProxy() {
	var err error
	inter, err = interceptor.New(client.NewDefaultClient().Client, listenAddr, "", "")
	if err != nil {
		log.Printf("Error starting SOCKS proxy: %q", err)
	}
}

func main() {
	log.Printf("Starting proxy...")
	startProxy()
	log.Printf("Go and play for 10 minutes.")
	time.Sleep(time.Minute * 10)
	inter.Stop()
}
