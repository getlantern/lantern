// package flashlight provides minimal configuration for spawning a flashlight
// client.

package flashlight

import (
	"github.com/getlantern/lantern-android/client"
)

var defaultClient *client.MobileClient

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	defaultClient.Stop()
	return nil
}

// RunClientProxy creates a new client at the given address.
func RunClientProxy(listenAddr, appName string) error {
	defaultClient = client.NewClient(listenAddr, appName)
	defaultClient.ServeHTTP()
	return nil
}
