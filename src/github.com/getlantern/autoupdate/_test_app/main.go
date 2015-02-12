// Package main prints the version of the currently running program and the
// version of its executable file.
package main

import (
	"fmt"
	"time"

	"github.com/getlantern/autoupdate"
)

const (
	// This internal version must be bumped everytime a new release is uploaded
	// to equinox and must match the contents of the --version value.
	internalVersion = 1
	sleepTime       = time.Second * 1
)

// We need to make it global in order to access its Version() method within
// main(), but that's not really required for the autoupdater to work.
var au *autoupdate.AutoUpdate

func init() {
	// Setting the proxy we're going to use for auto-updates.
	autoupdate.SetProxy("127.0.0.1:9999")

	// Update settings (such as equinox's tokens and the public key used to
	// verify signatures) are defined per app in config.go. We're doing that
	// instead of passing a Config struct to keep the autoupdate API independent
	// from go-update.
	au = autoupdate.New("_test_app")
	// Set internal version.
	au.SetVersion(internalVersion)
	// Watch for updates.
	au.Watch()
}

func main() {

	go func() {
		select {
		case newVersion := <-au.UpdatedTo:
			fmt.Printf("Executable file has been updated to version %d.\n", newVersion)
		}
	}()

	for {
		fmt.Printf("Running program version: %d, binary file version: %d\n", internalVersion, au.Version())
		time.Sleep(sleepTime)
	}
}
