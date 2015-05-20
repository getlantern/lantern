package client

import (
	"net/http"
	"runtime"
	"strings"
	"time"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/util"
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

	return &MobileClient{
		Client:  client,
		closed:  make(chan bool),
		fronter: hqfd.NewDirectDomainFronter(),
		appName: appName,
	}
}

func (client *MobileClient) ServeHTTP() {

	go func() {
		onListening := func() {
			log.Debugf("Now listening for connections...")
			go client.recordAnalytics()
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

func (client *MobileClient) recordAnalytics() {

	sessionPayload := &analytics.Payload{
		HitType:  analytics.EventType,
		Hostname: "localhost",
		Event: &analytics.Event{
			Category: "Session",
			Action:   "Start",
			Label:    runtime.GOOS,
		},
		UserAgent: "FireTweet",
	}

	if client.appName != "" {
		if appTrackingId, ok := trackingCodes[client.appName]; ok {
			sessionPayload.TrackingId = appTrackingId
		}
	}

	// Report analytics, proxying through the local client. Note this
	// is a little unorthodox by Lantern standards because it doesn't
	// pin the certificate of the cloud.yaml root CA, instead relying
	// on the go defaults.
	httpClient, err := util.HTTPClient("", client.Client.Addr)
	if err != nil {
		log.Errorf("Could not create HTTP client %v", err)
	} else {
		analytics.SessionEvent(httpClient, sessionPayload)
	}
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
	return clientConfig.updateFrom(buf)
}

// pollConfiguration periodically checks for updates in the cloud configuration
// file.
func (client *MobileClient) pollConfiguration() {

	// initially poll the config immediately
	pollTimer := time.NewTimer(1)
	defer pollTimer.Stop()

	for {
		select {
		case <-client.closed:
			log.Print("Closing poll configuration channel")
			return
		case <-pollTimer.C:
			// Attempt to update configuration.
			var err error
			if err = client.updateConfig(); err == nil {
				// Configuration changed, lets reload.
				err := globals.SetTrustedCAs(clientConfig.getTrustedCerts())
				if err != nil {
					log.Debugf("Unable to configure trusted CAs: %s", err)
				}
				hqfc := client.Configure(clientConfig.Client)
				client.fronter = hqfc.NewDirectDomainFronter()
			}
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
