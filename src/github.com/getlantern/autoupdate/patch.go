package autoupdate

import (
	"log"

	"github.com/getlantern/go-update/check"
)

// Patch satisfies Patcher and can be used for other programs to apply patches
// to its source executable file.
type Patch struct {
	res *check.Result
	v   int
}

// Apply attempts to update the process' executable file.
func (p *Patch) Apply() error {
	var err error
	var errRecover error

	err, errRecover = p.res.Update()

	if err != nil {
		return err
	}

	if errRecover != nil {
		// This should never happen, if this ever happens it means bad news such as
		// a missing executable file.
		log.Printf("Failed to recover from patching attempt: %q\n", errRecover)
		return errRecover
	}

	return nil
}

// Version returns the internal release number of the update.
func (p *Patch) Version() int {
	return p.v
}
