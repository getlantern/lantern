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
func RunClientProxy(listenAddr, appName string, protector SocketProvider, ready GoCallback) error {
	go func() {
		if protector != nil {
			protected.Configure(protector)
		}
		defaultClient = newClient(listenAddr, appName)
		defaultClient.serveHTTP()
		defaultClient.createHTTPClient()
		ready.AfterStart()
	}()
	return nil
}

func Start(protector SocketProvider, httpAddr string,
	socksAddr string, ready GoCallback) error {
	go func() {
		var err error
		protected.Configure(protector)

		i, err = interceptor.New(defaultClient.Client, socksAddr, httpAddr, protector.Notice)
		if err != nil {
			log.Errorf("Error starting SOCKS proxy: %v", err)
		}
		ready.AfterConfigure()
	}()
	return nil
}

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	defaultClient.stop()
	if i != nil {
		// here we stop the interceptor service
		// and close any existing connections
		i.Stop()
	}
	return nil
}
