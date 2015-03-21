// Package main prints the version of the currently running program and the
// version of its executable file.
package main

import (
	"fmt"
	"time"

	"github.com/getlantern/autoupdate"
)

const (
	internalVersion = "v0.0.9"
	sleepTime       = time.Second * 1
)

// We need to make it global in order to access its Version() method within
// main(), but that's not really required for the autoupdater to work.
var au *autoupdate.AutoUpdate

func init() {
	// Setting up a new autoupdate client.
	au = autoupdate.New(&autoupdate.Config{
		SignerPublicKey: []byte(
			"-----BEGIN PUBLIC KEY-----\n" +
				"MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzSoibtACnqcp2uTGjCMJ\n" +
				"tTOLDIMQ4oGPhGHT4Q/epum+H3hcbBNs9jRnMRWgX4z++xxuNJnhmoJw0eUXB7B4\n" +
				"vj5DYpPajq6gPY8JuraF4ngfP5oxKj2BqpEUR9bx+3SjOSInrirM0JZO+aAW38BQ\n" +
				"NJB+sS7JvbPjcwdjwKc5IKzc9kxxJNoZoFE9GMnYzaOrAlpCuAKWH8SCXYtCTxsX\n" +
				"fKexdDxsI5Vzm5lQHJLMeqhLTQTUm9oQofwNAOGOkn6dD4ObMlmFTOsf1G03/Dl9\n" +
				"sVgjaWaZ9bGjvJ9B85UxNeWwduy+uMrqFytxG6bbq0PbDEVu6ZQCPyiyCA7l945J\n" +
				"OQIDAQAB\n" +
				"-----END PUBLIC KEY-----\n",
		),
		CurrentVersion: internalVersion,
		HTTPClient:     nil, // Set this to something else to use a proxy.
	})

	// Watch for updates, this spawns a goroutine by its own.
	au.Watch()
}

func main() {

	go func() {
		select {
		case newVersion := <-au.UpdatedTo:
			fmt.Printf("Executable file has been updated to version %s.\n", newVersion)
		}
	}()

	for {
		fmt.Printf("Running program version: %s, binary file version: %s\n", internalVersion, au.Version())
		time.Sleep(sleepTime)
	}
}
