// badserver is an HTTP server that misbehaves in some common ways
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	// This handler closes the connection no matter
	http.HandleFunc("/close", func(resp http.ResponseWriter, req *http.Request) {
		fmt.Fprint(resp, "Your response")
		resp.(http.Flusher).Flush()
		hi, _ := resp.(http.Hijacker)
		conn, _, _ := hi.Hijack()
		conn.Close()
	})

	log.Fatal(http.ListenAndServe(":12080", nil))
}
