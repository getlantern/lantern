//go:build !linux

package main

import (
	lanterncore "github.com/getlantern/lantern/lantern-core"
)

// checkDaemonReachable is a no-op on Windows / macOS / mobile. The
// fast-probe-then-diagnose pattern this preflight came from (PR #8494,
// `requireLanternServiceAvailable` in ffi_linux.go) only pays off on
// platforms with a service-management diagnostic to fall back to —
// `systemctl is-active` on Linux. On other platforms there is no
// equivalent fallback, so the 300 ms `CheckDaemonReachable` timeout
// in lantern-core/core.go just caps the cold-start IPC roundtrip
// below what it can reliably hit (named-pipe dial + impersonation +
// H2c preface + cold goroutine scheduling regularly run >300 ms on
// the first request after lanternd has been idle).
//
// `ConnectVPN` itself surfaces "lanternd not reachable" with the same
// precision when the daemon really is dead. The preflight on these
// platforms was strictly an artificial guillotine in front of that
// real call. See getlantern/engineering#3382 and Freshdesk #173696 /
// #173932 for the user-visible regression this skip resolves.
//
// If we add Windows (`sc query LanternSvc`) or macOS (`launchctl
// list`) diagnostics later, restore the preflight and call them from
// here.
func checkDaemonReachable(c lanterncore.Core) error {
	return nil
}
