// +build !headless

package app

import (
	"fmt"

	"github.com/getlantern/i18n"
	"github.com/getlantern/systray"

	"github.com/getlantern/flashlight/icons"
	"github.com/getlantern/flashlight/ui"
)

var tray struct {
	enable bool
	show   *systray.MenuItem
	quit   *systray.MenuItem
}

func RunOnSystrayReady(f func()) {
	systray.Run(f)
}

func QuitSystray() {
	log.Debug("quitSystray")
	systray.Quit()
}

func configureSystemTray(a *App) error {
	tray.enable = a.ShowUI
	if !tray.enable {
		return nil
	}
	icon, err := icons.Asset("icons/16on.ico")
	if err != nil {
		return fmt.Errorf("Unable to load icon for system tray: %v", err)
	}
	systray.SetIcon(icon)
	systray.SetTooltip("Lantern")
	tray.show = systray.AddMenuItem(i18n.T("TRAY_SHOW_LANTERN"), i18n.T("SHOW"))
	tray.quit = systray.AddMenuItem(i18n.T("TRAY_QUIT"), i18n.T("QUIT"))
	go func() {
		for {
			select {
			case <-tray.show.ClickedCh:
				ui.Show()
			case <-tray.quit.ClickedCh:
				a.Exit(nil)
				return
			}
		}
	}()

	return nil
}

func refreshSystray(language string) {
	if !tray.enable {
		return
	}
	if err := i18n.SetLocale(language); err != nil {
		log.Debugf("i18n.SetLocale failed: %q", err)
	}
	tray.show.SetTitle(i18n.T("TRAY_SHOW_LANTERN"))
	tray.show.SetTooltip(i18n.T("SHOW"))
	tray.quit.SetTitle(i18n.T("TRAY_QUIT"))
	tray.quit.SetTooltip(i18n.T("QUIT"))
}
