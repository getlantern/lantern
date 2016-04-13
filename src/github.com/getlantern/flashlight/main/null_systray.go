// +build headless

package main

import (
	"github.com/getlantern/flashlight/app"
)

func runOnSystrayReady(f func()) {
	showui = false
	f()
}

func quitSystray() {
}

func configureSystemTray(a *app.App) error {
	return nil
}
