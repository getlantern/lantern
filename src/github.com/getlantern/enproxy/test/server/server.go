package main

import (
	"log"
	"os"

	"github.com/getlantern/enproxy"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: server <proxy addr to listen>")
	}
	proxy := &enproxy.Proxy{}
	err := proxy.ListenAndServe(os.Args[1])
	if err != nil {
		log.Fatalf("Unable to listen and serve: %s", err)
	}
}
