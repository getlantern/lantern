// +build windows

package open

import (
	"os/exec"
	"strings"

	"github.com/getlantern/runhide"
)

func cleaninput(input string) string {
	r := strings.NewReplacer("&", "^&")
	return r.Replace(input)
}

func open(input string) *exec.Cmd {
	return runhide.Command("cmd", "/C", "start", "", cleaninput(input))
}

func openWith(input string, appName string) *exec.Cmd {
	return runhide.Command("cmd", "/C", "start", "", appName, cleaninput(input))
}
