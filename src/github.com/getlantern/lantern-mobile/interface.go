package client

import (
	"github.com/getlantern/lantern-mobile/interceptor"
	"github.com/getlantern/lantern-mobile/protected"
)

// Getfiretweetversion returns the current build version string
func GetFireTweetVersion() string {
	return defaultClient.getFireTweetVersion()
}

// GoCallback is the supertype of callbacks passed to Go
type GoCallback interface {
	Do()
	WritePacket(string, int, string)
}

type SocketProvider interface {
	Protect(fileDescriptor int) error
}

// RunClientProxy creates a new client at the given address.
func RunClientProxy(listenAddr, appName string, ready GoCallback) error {
	go func() {
		defaultClient = newClient(listenAddr, appName)
		defaultClient.serveHTTP()
		ready.Do()
	}()
	return nil
}

func TestConnect(protector SocketProvider, addr string) error {
	return protected.TestConnect(protector, addr)
}

func CapturePacket(b []byte, ready GoCallback) error {
	go func() {
		var destination, protocol string
		var port int
		p, err := interceptor.NewPacket(b)
		if err == nil {
			port = p.GetPort()
			destination = p.GetDestination()
			protocol = p.GetProtocol()
		}
		ready.WritePacket(destination, port, protocol)
	}()
	return nil
}

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	defaultClient.stop()
	return nil
}
