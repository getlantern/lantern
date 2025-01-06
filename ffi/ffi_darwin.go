//go:build !ios
// +build !ios

package main

import (
	"context"

	"github.com/getlantern/lantern-outline/vpn"
)

func start(ctx context.Context, server vpn.VPNServer) error {
	return nil
}
