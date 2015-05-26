package client

import (
	"net/http"
	"strings"
	"time"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/golog"
)

const (
	cloudConfigPollInterval = time.Second * 60
)

// clientConfig holds global configuration settings for all clients.
var (
	log           = golog.LoggerFor("lantern-android.client")
	clientConfig  *config
	trackingCodes = map[string]string{
		"FireTweet": "UA-21408036-4",
	}
)

// MobileClient is an extension of flashlight client with a few custom declarations for mobile
type MobileClient struct {
	client.Client
	closed  chan bool
	fronter *http.Client
	appName string
}

// init attempts to setup client configuration.
func init() {
	clientConfig = defaultConfig()
}

// NewClient creates a proxy client.
func NewClient(addr, appName string) *MobileClient {

	client := client.Client{
		Addr:         addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	err := globals.SetTrustedCAs(clientConfig.getTrustedCerts())
	if err != nil {
		log.Errorf("Unable to configure trusted CAs: %s", err)
	}

	hqfd := client.Configure(clientConfig.Client)

	mClient := &MobileClient{
		Client:  client,
		closed:  make(chan bool),
		fronter: hqfd.NewDirectDomainFronter(),
		appName: appName,
	}
	go mClient.updateConfig()
	return mClient
}

func (client *MobileClient) ServeHTTP() {

	go func() {
		onListening := func() {
			log.Debugf("Now listening for connections...")
			analytics.Configure(trackingCodes["FireTweet"], "", client.Client.Addr)
		}

		defer func() {
			close(client.closed)
		}()

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
func (client *MobileClient) updateConfig() error {
	var buf []byte
	var err error

	if buf, err = pullConfigFile(client.fronter); err != nil {
		log.Errorf("Could not update config: '%v'", err)
		return err
	}
	if err = clientConfig.updateFrom(buf); err == nil {
		// Configuration changed, lets reload.
		err := globals.SetTrustedCAs(clientConfig.getTrustedCerts())
		if err != nil {
			log.Debugf("Unable to configure trusted CAs: %s", err)
		}
		hqfc := client.Configure(clientConfig.Client)
		client.fronter = hqfc.NewDirectDomainFronter()
	}
	return err
}

// pollConfiguration periodically checks for updates in the cloud configuration
// file.
func (client *MobileClient) pollConfiguration() {

	pollTimer := time.NewTimer(cloudConfigPollInterval)
	defer pollTimer.Stop()

	for {
		select {
		case <-client.closed:
			log.Debug("Closing poll configuration channel")
			return
		case <-pollTimer.C:
			// Attempt to update configuration.
			client.updateConfig()

			// Sleeping 'till next pull.
			// update timer to poll every 60 seconds
			pollTimer.Reset(cloudConfigPollInterval)
		}
	}
}

// Stop is currently not implemented but should make the listener stop
// accepting new connections and then kill all active connections.
func (client *MobileClient) Stop() error {
	if err := client.Client.Stop(); err != nil {
		log.Errorf("Unable to stop proxy client: %q", err)
		return err
	}
	return nil
}
