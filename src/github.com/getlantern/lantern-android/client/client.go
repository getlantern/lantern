package client

import (
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/getlantern/flashlight/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/fronted"
)

const (
	cloudConfigPollInterval = time.Second * 60
)

// clientConfig holds global configuration settings for all clients.
var clientConfig *config

// MClient is a forward declaration of flashlight client extended here with a few customizations for mobile
type MClient struct {
	client.Client
	hqfd   fronted.Dialer
	closed chan bool
}

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
func NewClient(addr string) *MClient {

	client := client.Client{
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

	return &MClient{
		Client: client,
		hqfd:   hqfd,
		closed: make(chan bool),
	}
}

func (client *MClient) ServeHTTP() {

	defer func() {
		close(client.closed)
	}()

	go func() {
		onListening := func() {
			log.Printf("Now listening for connections...")
		}
		if err := client.ListenAndServe(onListening); err != nil {
			// Error is not exported: https://golang.org/src/net/net.go#L284
			if !strings.Contains(err.Error(), "use of closed network connection") {
				panic(err.Error())
			}
		}
	}()
	go client.pollConfiguration()
}

// updateConfig attempts to pull a configuration file from the network using
// the client proxy itself.
func (client *MClient) updateConfig() error {
	var err error
	var buf []byte
	var cli *http.Client

	if cli, err = util.HTTPClient(cloudConfigCA, client.Addr); err != nil {
		return err
	}

	if buf, err = pullConfigFile(cli); err != nil {
		return err
	}

	return clientConfig.updateFrom(buf)
}

// pollConfiguration periodically checks for updates in the cloud configuration
// file.
func (client *MClient) pollConfiguration() {
	pollTimer := time.NewTimer(cloudConfigPollInterval)
	defer pollTimer.Stop()

	for {
		select {
		case <-client.closed:
			return
		case <-pollTimer.C:
			// Attempt to update configuration.
			var err error
			if err = client.updateConfig(); err == nil {
				// Configuration changed, lets reload.
				client.Configure(clientConfig.Client)
			}
			// Sleeping 'till next pull.
			pollTimer.Reset(cloudConfigPollInterval)
		}
	}
}

// Stop is currently not implemented but should make the listener stop
// accepting new connections and then kill all active connections.
func (client *MClient) Stop() error {
	log.Printf("Stopping proxy server...")
	return client.hqfd.Close()
}
