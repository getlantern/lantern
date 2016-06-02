package notify

import (
	"fmt"
	"os/exec"

	"strings"

	"github.com/skratchdot/open-golang/open"
)

type windowsNotifier struct {
	path string
}

// Notify sends a notification to the user.
func (n *windowsNotifier) Notify(msg *Notification) error {
	cmd := exec.Command(n.path, "/m", msg.Message, "/p", msg.Title)
	result, err := cmd.CombinedOutput()
	if err != nil {
		// This will happen all the time with notifu, as it uses exit statuses to
		// communicate what type of user interaction occurred. These are as follows:
		/*
		   0	Registry was succesfully edited. Only returned when /e is used with no other argument.
		   1	There was an error in one the argument or some required argument was missing.
		   2	The balloon timed out waiting. The user didn't click the close button or the balloon itself.
		   3	The user clicked the balloon.
		   4	The user closed the balloon using the X in the top right corner.
		   5	IUserNotification class object or interface is not supported on this version of Windows.
		   6	The user clicked with the right mouse button on the icon, in the system notification area (Vista and later)
		   7	The user clicked with the left mouse button on the icon, in the system notification area (Vista and later)
		   8	A new instance of Notifu dismissed a running instace
		   255	There was some unexpected error.
		*/
		if strings.Contains(err.Error(), "status 3") {
			// The user clicked the notification. Open the click URL.
			if len(msg.ClickURL) > 0 {
				open.Run(msg.ClickURL)
			}
		}
		return fmt.Errorf("Notifu returned %v", err)
	}
	fmt.Printf("Received result: '%v'", string(result))
	return nil
}
