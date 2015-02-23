package pac

import (
	"github.com/getlantern/byteexec"
	"github.com/getlantern/elevate"
)

import (
	"fmt"
	"syscall"
)

func ensureElevatedOnDarwin(be *byteexec.Exec, prompt string, iconFullPath string) (err error) {
	var s syscall.Stat_t
	// we just checked its existence, not bother checking specific error again
	if err = syscall.Stat(be.Filename, &s); err != nil {
		return fmt.Errorf("Error stating helper tool %s: %s", err)
	}
	if s.Mode&syscall.S_ISUID > 0 && s.Uid == 0 && s.Gid == 0 {
		log.Tracef("%v is already owned by root:wheel and has setuid bit on", be.Filename)
		return
	}
	cmd := elevate.WithPrompt(prompt).WithIcon(iconFullPath).Command(be.Filename, "setuid")
	return run(cmd)
}
