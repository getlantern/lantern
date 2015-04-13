// package flashlight provides minimal configuration for spawning a flashlight
// client.

package flashlight

import (
	"github.com/getlantern/lantern-android/client"
)

// RunClientProxy creates a new client at the given address.
func RunClientProxy(listenAddr string) error {

	c := client.NewClient(listenAddr)
	c.ServeHTTP()

	return nil
}
