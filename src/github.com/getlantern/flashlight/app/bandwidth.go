package app

import (
	"github.com/getlantern/bandwidth"
	"github.com/getlantern/notifier"

	"github.com/getlantern/flashlight/ui"
)

func serveBandwidth(uiaddr string) error {
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending current bandwidth quota to new client")
		return write(bandwidth.GetQuota())
	}

	service, err := ui.Register("bandwidth", helloFn)
	if err == nil {
		go func() {
			n := notify.NewNotifications()
			var notified bool
			for quota := range bandwidth.Updates {
				service.Out <- quota
				if quota.MiBAllowed <= quota.MiBUsed {
					if !notified {
						go notifyUser(n, uiaddr)
						notified = true
					}
				}
			}
		}()
	}

	return err
}

func notifyUser(n notify.Notifier, uiaddr string) {
	// TODO: We need to translate these strings somehow.
	msg := &notify.Notification{
		Title:    "You have used your free monthly data",
		Message:  "Upgrade to Pro to continue using Lantern",
		ClickURL: uiaddr,
		IconURL:  uiaddr + "/img/lantern_logo.png",
	}
	err := n.Notify(msg)
	log.Errorf("Could not notify? %v", err)
}
