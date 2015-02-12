package main

import (
	"log"
	"net/http"

	"github.com/getlantern/tarfs"
)

func main() {
	var fs http.FileSystem
	var err error
	fs, err = tarfs.New(Data, "localresources")
	if err != nil {
		log.Fatal(err.Error())
	}
	// if true {
	// 	fs = http.Dir("resources")
	// }
	http.Handle("/", http.FileServer(fs))
	err = http.ListenAndServe("localhost:8080", nil)
	if err != nil {
		log.Fatal(err.Error())
	}
}
