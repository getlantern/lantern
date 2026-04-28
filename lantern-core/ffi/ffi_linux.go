//go:build linux && !android

package main

import (
	"context"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	lanterncore "github.com/getlantern/lantern/lantern-core"
)

const daemonServiceName = "lanternd"

// checkDaemonReachable verifies that the radiance daemon is reachable via IPC.
// On Linux it provides additional diagnostics via systemd if the daemon is not responding.
func checkDaemonReachable(c lanterncore.Core) error {
	if err := c.CheckDaemonReachable(); err == nil {
		return nil
	}

	if diag := systemdDiag(daemonServiceName); diag != "" {
		return fmt.Errorf("%s not reachable: %s", daemonServiceName, diag)
	}
	return fmt.Errorf("%s not reachable", daemonServiceName)
}

func systemdDiag(unit string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 250*time.Millisecond)
	defer cancel()

	u := unit
	if filepath.Ext(u) == "" {
		u = unit + ".service"
	}

	out, err := exec.CommandContext(ctx, "systemctl", "is-active", u).CombinedOutput()
	if err != nil && len(out) == 0 {
		return ""
	}

	switch strings.TrimSpace(string(out)) {
	case "active":
		return "systemd says active, but IPC is not responding"
	case "inactive":
		return "systemd says inactive"
	case "failed":
		return "systemd says failed"
	case "activating":
		return "systemd says activating"
	case "deactivating":
		return "systemd says deactivating"
	default:
		return strings.TrimSpace(string(out))
	}
}
