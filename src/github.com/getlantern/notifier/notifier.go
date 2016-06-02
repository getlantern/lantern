package notify

import (
	"fmt"
	"io/ioutil"
	"runtime"

	"github.com/getlantern/notifier/osx"
	"github.com/getlantern/notifier/win"
)

// notifications is an internal representation of the Notifier interface.
type notifications struct {
	notifier Notifier
}

// Notifier is an interface for sending notifications to the user.
type Notifier interface {
	// Notify sends a notification to the user.
	Notify(*Notification) error
}

// Notification contains data for notifying the user about something. This
// is directly modeled after Chrome notifications, as detailed at:
// https://developer.chrome.com/apps/notifications
type Notification struct {
	ID                 string
	Type               string
	Title              string
	Message            string
	IconURL            string
	RequireInteraction bool
	IsClickable        bool
	ClickURL           string
}

type emptyNotifier struct {
}

// Notify sends a notification to the user.
func (n *emptyNotifier) Notify(msg *Notification) error {
	return nil
}

// NewNotifications creates a new Notifier that can notify the user about stuff.
func NewNotifications() Notifier {
	n, err := platformSpecificNotifier()
	if err != nil {
		n = &emptyNotifier{}
	}
	return &notifications{notifier: n}
}

func platformSpecificNotifier() (Notifier, error) {
	if runtime.GOOS == "windows" {
		return newWindowsNotifier()
	} else if runtime.GOOS == "darwin" {
		return newOSXNotifier()
	}
	return nil, fmt.Errorf("Platform not supported %v", runtime.GOOS)
}

// Notify sends a notification to the user.
func (n *notifications) Notify(msg *Notification) error {
	if msg.Message == "" {
		return fmt.Errorf("No message supplied in %v", msg)
	}
	go func() {
		n.notifier.Notify(msg)
	}()
	return nil
}

func newOSXNotifier() (Notifier, error) {
	if dir, err := ioutil.TempDir("", "terminal-notifier"); err != nil {
		return nil, err
	} else {
		if err := osx.RestoreAssets(dir, "terminal-notifier.app"); err != nil {
			return nil, err
		}
		fullPath := dir + "/terminal-notifier.app/Contents/MacOS/terminal-notifier"
		return &osxNotifier{path: fullPath}, nil
	}
}

func newWindowsNotifier() (Notifier, error) {
	if dir, err := ioutil.TempDir("", "notifu-notifier"); err != nil {
		return nil, err
	} else {
		if err := win.RestoreAssets(dir, "notifu.exe"); err != nil {
			return nil, err
		}
		fullPath := dir + "/notifu.exe"
		return &windowsNotifier{path: fullPath}, nil
	}
}
