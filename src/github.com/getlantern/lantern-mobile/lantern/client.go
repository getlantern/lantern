package client

import (
	"strings"
	"sync"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/util"

	"github.com/getlantern/golog"
)

// clientConfig holds global configuration settings for all clients.
var (
	log           = golog.LoggerFor("lantern-android.client")
	cf            = util.NewChainedAndFronted()
	configUpdates = make(chan *config.Config)
	cfgMutex      sync.Mutex

	trackingCodes = map[string]string{
		"FireTweet": "UA-21408036-4",
		"Lantern":   "UA-21815217-14",
	}

	defaultClient *mobileClient
)

// mobileClient is an extension of flashlight client with a few custom declarations for mobile
type mobileClient struct {
	appName      string
	androidProps map[string]string
	*client.Client
	closed chan bool
}

// newClient creates a proxy client.
func newClient(addr, appName string, androidProps map[string]string, configDir string) *mobileClient {

	logging.ConfigureAndroid(client.LogglyToken, client.LogglyTag, androidProps)

	cfg, err := config.Init(client.Version)
	if err != nil {
		log.Fatalf("Unable to initialize configuration: %v", err)
	}

	mClient := &mobileClient{
		Client: &client.Client{
			Addr:         addr,
			ReadTimeout:  0, // don't timeout
			WriteTimeout: 0,
		},
		closed:       make(chan bool),
		appName:      appName,
		androidProps: androidProps,
	}
	mClient.ApplyClientConfig(cfg)
	mClient.serveHTTP()

	go func() {
		err := config.Run(func(updated *config.Config) {
			configUpdates <- updated
		})
		if err != nil {
			log.Fatalf("Error updating configuration file: %v", err)
		}
		log.Debugf("Processed config")
	}()

	return mClient
}

func (client *mobileClient) afterSetup() {
	log.Debugf("Now listening for connections...")

	analytics.Configure("", trackingCodes[client.appName], "", client.Client.Addr)

	geolookup.Start()

	config.StartPolling()

}

// serveHTTP will run the proxy
func (client *mobileClient) serveHTTP() {
	go func() {

		defer func() {
			close(client.closed)
		}()

		if err := client.ListenAndServe(client.afterSetup); err != nil {
			// Error is not exported: https://golang.org/src/net/net.go#L284
			if !strings.Contains(err.Error(), "use of closed network connection") {
				panic(err.Error())
			}
		}
	}()
	go client.pollConfiguration()
}

// pollConfiguration periodically checks for updates in the cloud configuration
// file.
func (client *mobileClient) pollConfiguration() {
	for {
		select {
		case <-client.closed:
			log.Debug("Closing poll configuration channel")
			return
		case cfg := <-configUpdates:
			client.ApplyClientConfig(cfg)
		}
	}
}

// Stop is currently not implemented but should make the listener stop
// accepting new connections and then kill all active connections.
func (client *mobileClient) stop() error {
	if err := client.Client.Stop(); err != nil {
		log.Errorf("Unable to stop proxy client: %q", err)
		return err
	}
	return nil
}
