// +build !android

package main

import (
	"github.com/getlantern/flashlight"
	"github.com/getlantern/flashlight/autoupdate"
	"github.com/getlantern/flashlight/config"
)

func initUpdate() {
	// Passing public key and version to the autoupdate service.
	autoupdate.PublicKey = []byte(packagePublicKey)
	autoupdate.Version = flashlight.PackageVersion
}

func configureUpdate(cfg *config.Config) {
	autoupdate.Configure(cfg)
}
