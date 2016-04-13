// +build headless

import (
	"github.com/getlantern/flashlight/app"
)

package main

func runOnSystrayReady(f func()) {
	showui = false
	f()
}

func quitSystray() {
}

func configureSystemTray(a *app.App) error {
	return nil
}
