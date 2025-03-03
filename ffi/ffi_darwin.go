//go:build !ios
// +build !ios

package main

import (
	"context"

	"github.com/getlantern/radiance"
)

func start(ctx context.Context, server *radiance.Radiance) error {
	return server.StartVPN()
}
