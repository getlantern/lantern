//go:build !ios
// +build !ios

package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"

	"github.com/getlantern/radiance"
)

var (
	server     *radiance.Radiance
	serverOnce sync.Once
)

// start initializes radiance and starts the VPN
func start(ctx context.Context) error {
	var err error
	serverOnce.Do(func() {
		s, e := radiance.NewRadiance()
		if e != nil {
			err = fmt.Errorf("unable to create radiance: %v", e)
			return
		}
		server = s
	})
	if err != nil {
		return err
	}

	// if the effective user ID is zero, the process is running with root privileges
	if os.Geteuid() != 0 {
		return errors.New("operation not permitted, must run as admin on macOS")
	}

	if err := server.StartVPN(); err != nil {
		err = fmt.Errorf("unable to start radiance: %v", err)
		return err
	}
	return nil
}
