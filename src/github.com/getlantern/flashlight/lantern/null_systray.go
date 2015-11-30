// +build headless

package lantern

func runOnSystrayReady(f func()) {
	f()
}

func quitSystray() {
}

func configureSystemTray() error {
	return nil
}
