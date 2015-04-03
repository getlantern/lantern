// +build headless

package main

func runOnSystrayReady(f func()) {
	showui = false
	f()
}

func quitSystray() {
}

func configureSystemTray() error {
	return nil
}
