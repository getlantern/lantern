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
}

type SocketProvider interface {
	Protect(fileDescriptor int) error
	Notice(message string, fatal bool)
}

// RunClientProxy creates a new client at the given address.
func Start(protector SocketProvider, httpAddr, socksAddr, appName string, ready GoCallback) error {
	go func() {

		var err error

		if protector != nil {
			protected.Configure(protector)
		}
		defaultClient = newClient(httpAddr, appName)
		defaultClient.serveHTTP()

		i, err = interceptor.New(defaultClient.Client, socksAddr, httpAddr, protector.Notice)
		if err != nil {
			log.Errorf("Error starting SOCKS proxy: %v", err)
		}
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
