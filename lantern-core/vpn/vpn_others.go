//go:build !ios
// +build !ios

package vpn

import (
	"context"
	"errors"

	"github.com/getlantern/radiance"
)

// VPNServer defines the methods required to manage the VPN server
type VPNServer interface {
	Start(ctx context.Context) error
	Stop() error
	IsVPNConnected() bool
}

// NewVPNServer initializes and returns a new instance of vpnServer
func NewVPNServer(opts *Opts) (VPNServer, error) {
	var err error
	server := newVPNServer(opts)
	s, err := radiance.NewRadiance()
	if err != nil {
		return nil, err
	}
	server.radiance = s
	return server, nil
}

// Start initializes the tunnel using the provided parameters and starts the VPN server.
func (s *vpnServer) Start(ctx context.Context) error {
	if s.IsVPNConnected() {
		return errors.New("VPN already running")
	}
	s.setConnected(true)
	return s.radiance.StartVPN()
}

// Stop stops the VPN server and closes the tunnel.
func (s *vpnServer) Stop() error {
	if err := s.stop(); err != nil {
		return err
	}

	if s.radiance == nil {
		return nil
	}
	return s.radiance.StopVPN()
}
