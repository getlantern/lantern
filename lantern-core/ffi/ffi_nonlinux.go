//go:build !linux

package main

import (
	"fmt"

	lanterncore "github.com/getlantern/lantern/lantern-core"
)

// checkDaemonReachable verifies that the radiance daemon is reachable via IPC.
func checkDaemonReachable(c lanterncore.Core) error {
	if err := c.CheckDaemonReachable(); err != nil {
		return fmt.Errorf("lanternd not reachable: %w", err)
	}
	return nil
}
