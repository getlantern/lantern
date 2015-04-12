package client

import (
	"log"
	"strings"

	"github.com/getlantern/flashlight/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/globals"
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

	err := globals.SetTrustedCAs(clientConfig.getTrustedCerts())
	if err != nil {
		log.Fatalf("Unable to configure trusted CAs: %s", err)
	}

	hqfd := client.Configure(clientConfig.Client)

	hqfdc := hqfd.DirectHttpClient()

	// store GA session event
	analytics.Configure(nil, false, hqfdc)

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
