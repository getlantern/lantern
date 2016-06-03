// +build darwin

package notify

import (
	"io/ioutil"
	"os/exec"

	"github.com/getlantern/notifier/osx"
)

func newNotifier() (Notifier, error) {
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

type osxNotifier struct {
	path string
}

// Notify sends a notification to the user.
func (n *osxNotifier) Notify(msg *Notification) error {
	cmd := exec.Command(n.path, "-message", msg.Message, "-title", msg.Title, "-open", msg.ClickURL, "-appIcon", msg.IconURL)
	result, err := cmd.CombinedOutput()
	if err != nil {
		log.Errorf("Could not run command %v", err)
		return err
	}
	log.Debugf("Received result: %v", string(result))
	return nil
}
