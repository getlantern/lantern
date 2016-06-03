// +build !darwin,!windows

package notify

type emptyNotifier struct {
}

func newNotifier() (Notifier, error) {
	return &emptyNotifier{}, nil
}

type osxNotifier struct {
	path string
}

// Notify sends a notification to the user.
func (n *osxNotifier) Notify(msg *Notification) error {
	return nil
}
