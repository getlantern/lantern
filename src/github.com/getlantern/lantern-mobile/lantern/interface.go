package client

import (
	"net"

	"github.com/getlantern/appdir"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/lantern"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/settings"
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/lantern/interceptor"
	"github.com/getlantern/lantern-mobile/lantern/protected"
)

var (
	log         = golog.LoggerFor("lantern-android.client")
	i           *interceptor.Interceptor
	appSettings *settings.Settings

	trackingCodes = map[string]string{
		"FireTweet": "UA-21408036-4",
		"Lantern":   "UA-21815217-14",
	}
)

type Provider interface {
	Model() string
	Device() string
	Version() string
	AppName() string
	VpnMode() bool
	GetDnsServer() string
	SettingsDir() string
	AfterStart(string, string, string)
	Protect(fileDescriptor int) error
	Notice(message string, fatal bool)
}

func Configure(provider Provider) error {

	log.Debugf("Configuring Lantern version: %s", lantern.GetVersion())

	if provider.VpnMode() {
		dnsServer := provider.GetDnsServer()
		protected.Configure(provider, dnsServer, true)
	}

	settingsDir := provider.SettingsDir()
	log.Debugf("settings directory is %s", settingsDir)

	appdir.AndroidDir = settingsDir
	settings.SetAndroidPath(settingsDir)
	appSettings = settings.Load(lantern.GetVersion(), lantern.GetRevisionDate(), "")

	return nil
}

// Start creates a new client at the given address.
func Start(provider Provider) error {

	go func() {

		androidProps := map[string]string{
			"androidDevice":     provider.Device(),
			"androidModel":      provider.Model(),
			"androidSdkVersion": provider.Version(),
		}

		logging.ConfigureAndroid(androidProps)

		cfgFn := func(cfg *config.Config) {

		}

		l, err := lantern.Start(false, true, false,
			true, cfgFn)

		if err != nil {
			log.Fatalf("Could not start Lantern")
		}

		if provider.VpnMode() {
			i, err = interceptor.Do(l.Client, appSettings.SocksAddr, appSettings.HttpAddr, provider.Notice)
			if err != nil {
				log.Errorf("Error starting SOCKS proxy: %v", err)
			}
			lantern.AddExitFunc(func() {
				if i != nil {
					i.Stop()
				}
			})
		}

		proxyHost, proxyPort, _ := net.SplitHostPort(appSettings.HttpAddr)

		provider.AfterStart(lantern.GetVersion(), proxyHost,
			proxyPort)
	}()
	return nil
}

func Restart(provider Provider) {
	log.Debugf("Restarting Lantern..")
	Stop()
	Configure(provider)
	Start(provider)
}

func Stop() {
	go lantern.Exit(nil)
}
