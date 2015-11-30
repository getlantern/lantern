// +build prod

package client

import (
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/lantern"
	"github.com/getlantern/lantern-mobile/lantern/interceptor"
	"github.com/getlantern/lantern-mobile/lantern/protected"

	"github.com/getlantern/appdir"
	"github.com/getlantern/flashlight/settings"
)

var (
	i                 *interceptor.Interceptor
	bootstrapSettings *settings.Settings
	settingsDir       string
)

func init() {
	lantern.Version = defaultPackageVersion
	lantern.RevisionDate = defaultRevisionDate
	client.LogglyTag = "android-tag"
	client.LogglyToken = "2b68163b-89b6-4196-b878-c1aca4bbdf84"
}

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

func Configure(protector SocketProvider, appName string, ready GoCallback) error {

	dnsServer := ready.GetDnsServer()

	if protector != nil {
		protected.Configure(protector, dnsServer)
	}

	settingsDir = protector.SettingsDir()
	log.Debugf("settings directory is %s", settingsDir)

	appdir.AndroidDir = settingsDir

	settings.SetAndroidPath(settingsDir)

	bootstrapSettings = settings.Load(client.Version, client.RevisionDate, "")

	return nil
}

// RunClientProxy creates a new client at the given address.
func Start(protector SocketProvider, appName string,
	device string, model string, version string, ready GoCallback) error {

	go func() {
		var err error

		androidProps := map[string]string{
			"androidDevice":     device,
			"androidModel":      model,
			"androidSdkVersion": version,
		}

		defaultClient, err = newClient(bootstrapSettings.HttpAddr, appName, androidProps, settingsDir)
		if err != nil {
			log.Fatalf("Could not start Lantern")
		}

		i, err = interceptor.New(defaultClient.Client, bootstrapSettings.SocksAddr, bootstrapSettings.HttpAddr, protector.Notice)
		if err != nil {
			log.Errorf("Error starting SOCKS proxy: %v", err)
		}

		lantern.AddExitFunc(func() {
			if i != nil {
				i.Stop(true)
			}
		})
		ready.AfterStart(client.Version)

	}()
	return nil
}

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	go lantern.Exit(nil)
	return nil
}
