// +build !windows,!darwin

package open

import (
	"os/exec"
	"path"
	"runtime"
)

func open(input string) *exec.Cmd {
	_, file, _, _ := runtime.Caller(0)
	app := path.Join(path.Dir(file), "..", "vendor", "xdg-open")
	return exec.Command(app, input)
}

func openWith(input string, appName string) *exec.Cmd {
	return exec.Command(appName, input)
}
