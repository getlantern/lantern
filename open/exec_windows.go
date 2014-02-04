// +build windows

package open

import (
	"os/exec"
)

func open(input string) *exec.Cmd {
	return exec.Command("start", "", input)
}

func openWith(input string, appName string) *exec.Cmd {
	return exec.Command("start", "", appName, input)
}
