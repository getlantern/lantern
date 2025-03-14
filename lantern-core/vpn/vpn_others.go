//go:build !ios
// +build !ios

package vpn

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"

	"github.com/getlantern/radiance"
)

// VPNServer defines the methods required to manage the VPN server
type VPNServer interface {
	Start(ctx context.Context) error
	Stop() error
	IsVPNConnected() bool
}

// NewVPNServer initializes radiances and returns a new instance of vpnServer
func NewVPNServer(opts *Opts) (VPNServer, error) {
	r, err := radiance.NewRadiance()
	if err != nil {
		return nil, err
	}
	opts.Radiance = r
	return newVPNServer(opts), nil
}

// Start starts radiance and the VPN server
func (s *vpnServer) Start(ctx context.Context) error {
	if s.IsVPNConnected() {
		return errors.New("VPN already running")
	}

	if err := s.radiance.StartVPN(); err != nil {
		return err
	}
	// configure logging
	logFile := filepath.Join(s.baseDir, "lantern.log")
	if err := s.configureLogging(ctx, logFile, s.logPort); err != nil {
		log.Errorf("Error configuring logging: %v", err)
	}

	s.setConnected(true)
	return nil
}

// Stop stops radiance and the VPN server.
func (s *vpnServer) Stop() error {
	if err := s.stop(); err != nil {
		return err
	}
	if err := s.radiance.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop radiance: %v", err)
		return err
	}
	return nil
}
