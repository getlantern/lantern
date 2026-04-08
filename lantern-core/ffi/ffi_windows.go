package main

import (
	"context"
	"fmt"
	"time"

	"github.com/getlantern/radiance/ipc"
)

// checkDaemonReachable verifies that the radiance daemon is reachable via IPC.
func checkDaemonReachable(client *ipc.Client) error {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()

	if _, err := client.VPNStatus(ctx); err != nil {
		return fmt.Errorf("lanternd not reachable: %w", err)
	}
	return nil
}
