package notify

import (
	"log"
	"runtime"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestOSXNotify(t *testing.T) {
	if runtime.GOOS != "darwin" {
		log.Println("Not on darwin")
		return
	}
	n, err := newOSXNotifier()
	assert.Nil(t, err, "got an error?")

	msg := &Notification{
		Title:    "Your Lantern time is up",
		Message:  "You have reached your data cap limit",
		ClickURL: "https://www.getlantern.org",
		IconURL:  "http://127.0.0.1:2000/img/lantern_logo.png",
	}
	err = n.Notify(msg)
	assert.Nil(t, err, "got an error notifying user")
}

func TestWindowsNotify(t *testing.T) {
	if runtime.GOOS != "windows" {
		log.Println("Not on windows")
		return
	}
	n, err := newWindowsNotifier()
	assert.Nil(t, err, "got an error?")

	msg := &Notification{
		Title:    "Your Lantern time is up",
		Message:  "You have reached your data cap limit",
		ClickURL: "https://www.getlantern.org",
	}
	err = n.Notify(msg)
	assert.Nil(t, err, "got an error notifying user")

}
