package client

import (
	"io"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/getlantern/flashlight/client"
)

const (
	cloudConfigPollInterval = time.Second * 60
	httpConnectMethod       = "CONNECT"
	httpXFlashlightQOS      = "X-Flashlight-QOS"
)

// clientConfig holds global configuration settings for all clients.
var clientConfig *config

// init attempts to setup client configuration.
func init() {
	var err error
	// Initial attempt to get configuration, without a proxy. If this request
	// fails we'll use the default configuration.
	if clientConfig, err = getConfig(); err != nil {
		// getConfig() guarantees to return a *Config struct, so we can log the
		// error without stopping the program.
		log.Printf("Error updating configuration over the network: %q.", err)
	}
}

// NewClient creates a proxy client.
func NewClient(addr string) {

	client := &client.Client{
		Addr:         addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	client.Configure(clientConfig.Client)

	go func() {
		var err error
		onListening := func() {
			log.Printf("Now listening for connections...")
		}

		if err = client.ListenAndServe(onListening); err != nil {
			// Error is not exported: https://golang.org/src/net/net.go#L284
			if !strings.Contains(err.Error(), "use of closed network connection") {
				panic(err.Error())
			}
		}
	}()
}

// pipeData pipes data between the client and proxy connections.  It's also
// responsible for responding to the initial CONNECT request with a 200 OK.
func pipeData(clientConn net.Conn, connOut net.Conn, req *http.Request) {
	// Start piping to proxy
	go io.Copy(connOut, clientConn)

	// Respond OK
	err := respondOK(clientConn, req)
	if err != nil {
		log.Printf("Unable to respond OK: %s", err)
		return
	}

	// Then start coyping from out to client
	io.Copy(clientConn, connOut)
}

func respondOK(writer io.Writer, req *http.Request) error {
	defer req.Body.Close()
	resp := &http.Response{
		StatusCode: http.StatusOK,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}
	return resp.Write(writer)
}
