package main

import (
	"time"

	"github.com/getlantern/notifier"
)

func main() {
	n := notify.NewNotifications()

	msg := &notify.Notification{
		Title:    "Super Important",
		Message:  "Free the Internet",
		ClickURL: "https://www.getlantern.org",
		//IconURL:  "https://www.getlantern.org",
	}

	n.Notify(msg)
	time.Sleep(3 * time.Second)
}
