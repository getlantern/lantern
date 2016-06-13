// +build headless

package app

func RunOnSystrayReady(f func()) {
	f()
}

func QuitSystray() {
}

func configureSystemTray(a *App) error {
	return nil
}
