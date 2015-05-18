package client

import (
	"log"
	"net/http"
	"runtime"
	"strings"
	"time"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/util"
)

const (
	cloudConfigPollInterval = time.Second * 60
)

// clientConfig holds global configuration settings for all clients.
var (
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
		log.Fatalf("Unable to configure trusted CAs: %s", err)
	}

	hqfd := client.Configure(clientConfig.Client)

	// store GA session event
	sessionPayload := &analytics.Payload{
		HitType: analytics.EventType,
		Event: &analytics.Event{
			Category: "Session",
			Action:   "Start",
			Label:    runtime.GOOS,
		},
	}

	// attach our app-specific analytics tracking code
	// to session info
	if appName != "" {
		if trackingId, ok := trackingCodes[appName]; ok {
			sessionPayload.TrackingId = trackingId
		}
	}

	httpClient, er := util.HTTPClient(cfg.CloudConfigCA, cfg.Addr)
	if er != nil {
		log.Errorf("Could not create HTTP client %v", er)
	} else {
		analytics.SessionEvent(httpClient, sessionPayload)
	}

	return &MobileClient{
		Client:  client,
		closed:  make(chan bool),
		fronter: hqfd.NewDirectDomainFronter(),
	}
}

func (client *MobileClient) ServeHTTP() {

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
func (client *MobileClient) updateConfig() error {
	var buf []byte
	var err error
	if buf, err = pullConfigFile(client.fronter); err != nil {
		return err
	}
	return clientConfig.updateFrom(buf)
}

// pollConfiguration periodically checks for updates in the cloud configuration
// file.
func (client *MobileClient) pollConfiguration() {
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
				err := globals.SetTrustedCAs(clientConfig.getTrustedCerts())
				if err != nil {
					log.Printf("Unable to configure trusted CAs: %s", err)
				}
				hqfc := client.Configure(clientConfig.Client)
				client.fronter = hqfc.NewDirectDomainFronter()
			}
			// Sleeping 'till next pull.
			pollTimer.Reset(cloudConfigPollInterval)
		}
	}
}

// Stop is currently not implemented but should make the listener stop
// accepting new connections and then kill all active connections.
func (client *MobileClient) Stop() error {
	if err := client.Client.Stop(); err != nil {
		log.Fatalf("Unable to stop proxy client: %q", err)
		return err
	}
	return nil
}
