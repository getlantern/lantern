package elevate

import (
	"fmt"
	"os/exec"

	"github.com/getlantern/byteexec"
	"github.com/getlantern/elevate/bin"
)

func buildCommand(prompt string, icon string, name string, args ...string) (*exec.Cmd, error) {
	argsLen := len(args)
	if icon != "" {
		argsLen += 1
	}
	if prompt != "" {
		argsLen += 1
	}
	allArgs := make([]string, 0, argsLen)
	if icon != "" {
		allArgs = append(allArgs, "--icon="+icon)
	}
	if prompt != "" {
		allArgs = append(allArgs, "--prompt="+prompt)
	}
	allArgs = append(allArgs, name)
	allArgs = append(allArgs, args...)
	cocoasudo, err := bin.Asset("cocoasudo")
	if err != nil {
		return nil, fmt.Errorf("Unable to load cocoasudo: %v", err)
	}
	be, err := byteexec.New(cocoasudo, "cocoasudo")
	if err != nil {
		return nil, fmt.Errorf("Unable to build byteexec for cocoasudo: %v", err)
	}

	return be.Command(allArgs...), nil
}
