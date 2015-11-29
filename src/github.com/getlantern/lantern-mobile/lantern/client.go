package client

import (
	"strings"
	"sync"
	"time"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"

	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/proxiedsites"
	"github.com/getlantern/flashlight/settings"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/fronted"

	"github.com/getlantern/golog"
)

// clientConfig holds global configuration settings for all clients.
var (
	log           = golog.LoggerFor("lantern-android.client")
	cf            = util.NewChainedAndFronted()
	configUpdates = make(chan *config.Config)
	cfgMutex      sync.Mutex

	logglyToken   = "2b68163b-89b6-4196-b878-c1aca4bbdf84"
	logglyTag     = "lantern-android"
	trackingCodes = map[string]string{
		"FireTweet": "UA-21408036-4",
		"Lantern":   "UA-21815217-14",
	}

	InstanceId = ""

	defaultClient *mobileClient
)

// mobileClient is an extension of flashlight client with a few custom declarations for mobile
type mobileClient struct {
	appName      string
	androidProps map[string]string
	*client.Client
	closed chan bool
}

func init() {
	settings.Load(version, revisionDate, "")
	InstanceId = settings.GetInstanceID()
}

// newClient creates a proxy client.
func newClient(addr, appName string, androidProps map[string]string, configDir string) *mobileClient {

	cfg, err := config.Init(version)
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
	mClient.applyClientConfig(cfg)
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

func (client *mobileClient) applyClientConfig(cfg *config.Config) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	certs, err := cfg.GetTrustedCACerts()
	if err != nil {
		log.Errorf("Unable to get trusted ca certs, not configure fronted: %s", err)
	} else {
		fronted.Configure(certs, cfg.Client.MasqueradeSets)
	}

	logging.ConfigureAndroid(logglyToken, logglyTag, client.androidProps)
	logging.Configure(client.Client.Addr, cfg.CloudConfigCA, InstanceId, version, revisionDate)

	proxiedsites.Configure(cfg.ProxiedSites)

	// Update client configuration and get the highest QOS dialer available.
	client.Configure(cfg.Client)

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
			client.applyClientConfig(cfg)
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
