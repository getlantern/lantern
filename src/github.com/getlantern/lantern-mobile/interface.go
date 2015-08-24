package client

import (
	"github.com/getlantern/lantern-mobile/interceptor"
	"github.com/getlantern/lantern-mobile/protected"
)

var i *interceptor.Interceptor

// Getfiretweetversion returns the current build version string
func GetFireTweetVersion() string {
	return defaultClient.getFireTweetVersion()
}

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
		defaultClient = newClient(listenAddr, appName, protector)
		defaultClient.serveHTTP()
		ready.AfterStart()
	}()
	return nil
}

func IsMasqueradeCheck(ip string) bool {
	return defaultClient.IsMasqueradeCheck(ip)
}

func Configure(protector SocketProvider, ready GoCallback) error {
	go func() {
		i = interceptor.New(protector, false,
			ready.WritePacket, IsMasqueradeCheck)
		ready.AfterConfigure()
	}()
	return nil
}

func TestConnect(protector SocketProvider, addr string) error {
	protected.Init(protector)
	return protected.TestConnect(addr)
}

func ProcessPacket(b []byte, protector SocketProvider, ready GoCallback) error {
	go func() {
		i.Process(b)
	}()
	return nil
}

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	defaultClient.stop()
	return nil
}
