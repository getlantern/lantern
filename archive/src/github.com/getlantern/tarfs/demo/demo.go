package main

import (
	"log"
	"net/http"

	"github.com/getlantern/tarfs"
)

const (
	addr = "localhost:8080"
)

func main() {
	var fs http.FileSystem
	var err error
	fs, err = tarfs.New(Resources, "localresources")
	if err != nil {
		log.Fatal(err.Error())
	}
	http.Handle("/", http.FileServer(fs))
	log.Printf("About to listen at %v", addr)
	log.Printf("Try browsing to http://%v", addr)
	err = http.ListenAndServe(addr, nil)
	if err != nil {
		log.Fatal(err.Error())
	}
}
