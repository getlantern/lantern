// +build headless

package lantern

func RunOnSystrayReady(f func()) {
	f()
}

func quitSystray() {
}

func configureSystemTray() error {
	return nil
}
