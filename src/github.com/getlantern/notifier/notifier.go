package notify

import "fmt"

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
	n, err := newNotifier()
	if err != nil {
		fmt.Printf("Could not create notifier? %v", err)
		n = &emptyNotifier{}
	}
	return &notifications{notifier: n}
}

// Notify sends a notification to the user.
func (n *notifications) Notify(msg *Notification) error {
	if len(msg.Message) == 0 {
		return fmt.Errorf("No message supplied in %v", msg)
	}
	if len(msg.Title) == 0 {
		return fmt.Errorf("No title supplied in %v", msg)
	}
	go func() {
		n.notifier.Notify(msg)
	}()
	return nil
}
