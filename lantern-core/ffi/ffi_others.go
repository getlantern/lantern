//go:build !ios
// +build !ios

package main

import (
	"context"
)

// start initializes radiance and starts the VPN
func start(ctx context.Context) error {
	return server.Start(ctx)
}
