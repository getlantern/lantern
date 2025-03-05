//go:build darwin && !ios
// +build darwin,!ios

package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/getlantern/lantern-outline/vpn"
)

var (
	server vpn.VPNServer
)

// start initializes radiance and starts the VPN
func start(ctx context.Context) error {
	if server == nil {
		s, err := vpn.NewVPNServer(&vpn.Opts{})
		if err != nil {
			err = fmt.Errorf("unable to create radiance: %v", err)
			log.Error(err)
			return err
		}
		server = s
	}
	// if the effective user ID is zero, the process is running with root privileges
	if os.Geteuid() != 0 {
		return errors.New("operation not permitted, must run as admin on macOS")
	}
	return server.Start(ctx)
}
