package client

import (
	"github.com/getlantern/lantern-mobile/lantern/interceptor"
	"github.com/getlantern/lantern-mobile/lantern/protected"
)

var (
	i *interceptor.Interceptor
)

// GoCallback is the supertype of callbacks passed to Go
type GoCallback interface {
	AfterConfigure()
	AfterStart()
	GetDnsServer() string
}

type SocketProvider interface {
	Protect(fileDescriptor int) error
	Notice(message string, fatal bool)
}

// StartWithSocks
func StartWithSocks(protector SocketProvider, httpAddr, socksAddr, appName string,
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

		defaultClient = newClient(httpAddr, appName, androidProps)
		defaultClient.serveHTTP()

		i, err = interceptor.New(defaultClient.Client, socksAddr, httpAddr, protector.Notice)
		if err != nil {
			log.Errorf("Error starting SOCKS proxy: %v", err)
		}
		ready.AfterStart()
	}()
	return nil
}

// StartWithTunio
func StartWithTunio(protector SocketProvider, httpAddr, appName string,
	device string, model string, version string, ready GoCallback) error {

	go func() {
		androidProps := map[string]string{
			"androidDevice":     device,
			"androidModel":      model,
			"androidSdkVersion": version,
		}

		dnsServer := ready.GetDnsServer()

		if protector != nil {
			protected.Configure(protector, dnsServer)
		}

		defaultClient = newClient(httpAddr, appName, androidProps)
		defaultClient.serveHTTP()

		ready.AfterStart()
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
