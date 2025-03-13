//go:build !ios
// +build !ios

package vpn

import (
	"context"
	"errors"
	"fmt"

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
	server := newVPNServer(opts)
	s, err := radiance.NewRadiance()
	if err != nil {
		return nil, err
	}
	server.radiance = s
	return server, nil
}

// Start starts radiance and the VPN server
func (s *vpnServer) Start(ctx context.Context) error {
	if s.IsVPNConnected() {
		return errors.New("VPN already running")
	}
	s.setConnected(true)

	if s.radiance == nil {
		return nil
	}
	return s.radiance.StartVPN()
}

// Stop stops radiance and the VPN server.
func (s *vpnServer) Stop() error {
	if err := s.stop(); err != nil {
		return err
	}
	if s.radiance == nil {
		return nil
	}
	if err := s.radiance.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop radiance: %v", err)
		return err
	}
	return nil
}
