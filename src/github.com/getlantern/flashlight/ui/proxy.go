package ui

import (
	"net/http"

	"github.com/getlantern/flashlight/pro"
)

func initProServer(addr string) {
	go func() {
		err := http.ListenAndServe(addr, pro.ProxyHandler)
		log.Fatal(err)
	}()
}
