package client

import (
	"github.com/getlantern/lantern-mobile/lantern/interceptor"
	"github.com/getlantern/lantern-mobile/lantern/protected"

	"github.com/getlantern/appdir"
	"github.com/getlantern/flashlight/settings"
)

var (
	i            *interceptor.Interceptor
	version      = "development"
	revisionDate = "now"
)

// GoCallback is the supertype of callbacks passed to Go
type GoCallback interface {
	AfterConfigure()
	AfterStart(string)
	GetDnsServer() string
}

type SocketProvider interface {
	Protect(fileDescriptor int) error
	Notice(message string, fatal bool)
	SettingsDir() string
}

// RunClientProxy creates a new client at the given address.
func Start(protector SocketProvider, appName string,
	device string, model string, version string, ready GoCallback) error {

	go func() {
		var err error

		dnsServer := ready.GetDnsServer()

		if protector != nil {
			protected.Configure(protector, dnsServer)
		}

		androidProps := map[string]string{
			"androidDevice":     device,
			"androidModel":      model,
			"androidSdkVersion": version,
		}

		settingsDir := protector.SettingsDir()
		log.Debugf("settings directory is %s", settingsDir)
		appdir.AndroidDir = settingsDir

		settings := settings.Load(version, revisionDate, "")

		defaultClient = newClient(settings.HttpAddr, appName, androidProps, settingsDir)

		i, err = interceptor.New(defaultClient.Client, settings.SocksAddr, settings.HttpAddr, protector.Notice)
		if err != nil {
			log.Errorf("Error starting SOCKS proxy: %v", err)
		}
		latestVersion := "2.0"
		ready.AfterStart(latestVersion)
	}()
	return nil
}

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	defaultClient.stop()
	if i != nil {
		// here we stop the interceptor service
		// and close any existing connections
		i.Stop(true)
	}
	return nil
}
