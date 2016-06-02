package notify

import (
	"fmt"
	"os/exec"
)

type osxNotifier struct {
	path string
}

// Notify sends a notification to the user.
func (n *osxNotifier) Notify(msg *Notification) error {
	cmd := exec.Command(n.path, "-message", msg.Message, "-title", msg.Title, "-open", msg.ClickURL, "-appIcon", msg.IconURL)
	result, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("Could not run command %v", err)
	}
	fmt.Printf("Received result: %v", string(result))
	return nil
}
