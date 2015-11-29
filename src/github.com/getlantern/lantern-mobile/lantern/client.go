package client

import (
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
	geolookup.Start()

	go func() {
		err := config.Run(func(updated *config.Config) {
			configUpdates <- updated
		})
		if err != nil {
			log.Fatalf("Error updating configuration file: %v", err)
		}
	}()

	go mClient.pollConfiguration()

	go mClient.ListenAndServe(func() {
		config.StartPolling()
	})

	log.Debugf("Processed config")

	return mClient
}

func (client *mobileClient) afterSetup() {
	log.Debugf("Now listening for connections...")

	analytics.Configure("", trackingCodes[client.appName], "", client.Client.Addr)

	config.StartPolling()

}

// pollConfiguration periodically checks for updates in the cloud configuration
// file.
func (client *mobileClient) pollConfiguration() {
	for {
		cfg := <-configUpdates
		client.ApplyClientConfig(cfg)
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
