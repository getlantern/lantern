package client

import (
	"github.com/getlantern/lantern-mobile/lantern/interceptor"
	"github.com/getlantern/lantern-mobile/lantern/protected"
)

// GoCallback is the supertype of callbacks passed to Go
type GoCallback interface {
	AfterConfigure()
	AfterStart()
	WritePacket([]byte)
}

type SocketProvider interface {
	Protect(fileDescriptor int) error
}

// RunClientProxy creates a new client at the given address.
func RunClientProxy(listenAddr, appName string, protector SocketProvider, ready GoCallback) error {
	go func() {
		protected.Configure(protector)
		defaultClient = newClient(listenAddr, appName)
		defaultClient.serveHTTP()
		ready.AfterStart()
	}()
	return nil
}

func Configure(protector SocketProvider, httpAddr string,
	socksAddr string, udpgwServer string,
	ready GoCallback) error {
	go func() {
		protected.Configure(protector)
		_, err := interceptor.New(defaultClient.Client, socksAddr, httpAddr, udpgwServer)
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
	return nil
}
