// package elevate provides support for executing commands with elevated
// privileges.
package elevate

import (
	"os/exec"
)

type CommandBuilder struct {
	prompt string
	icon   string
}

func WithPrompt(prompt string) *CommandBuilder {
	return &CommandBuilder{
		prompt: prompt,
	}
}

func WithIcon(icon string) *CommandBuilder {
	return &CommandBuilder{
		icon: icon,
	}
}

func (b *CommandBuilder) WithPrompt(prompt string) *CommandBuilder {
	return &CommandBuilder{
		prompt: prompt,
		icon:   b.icon,
	}
}

func (b *CommandBuilder) WithIcon(icon string) *CommandBuilder {
	return &CommandBuilder{
		prompt: b.prompt,
		icon:   icon,
	}
}

func (b *CommandBuilder) Command(name string, args ...string) *exec.Cmd {
	cmd, err := buildCommand(b.prompt, b.icon, name, args...)
	if err != nil {
		panic(err)
	}
	return cmd
}

// Command is like exec.Command, except that it runs the given command with
// elevated privileges.
func Command(name string, args ...string) *exec.Cmd {
	b := &CommandBuilder{}
	return b.Command(name, args...)
}
