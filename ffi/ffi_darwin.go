//go:build darwin
// +build darwin

package main

import (
	"context"
	"errors"
	"os"

	"github.com/getlantern/radiance"
)

func start(ctx context.Context, server *radiance.Radiance) error {
	defer func() {
		if r := recover(); r != nil {
			log.Errorf("Recovered from panic: %v", r)
		}
	}()
	if server.ConnectionStatus() {
		return errors.New("radiance is already connected")
	}
	// if the effective user ID is zero, the process is running with root privileges
	if os.Geteuid() != 0 {
		return errors.New("operation not permitted, must run as admin on macOS")
	}
	return server.StartVPN()
}
