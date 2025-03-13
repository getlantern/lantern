//go:build ios
// +build ios

package vpn

import (
	"context"
	"errors"
	"fmt"
	"log"

	"github.com/getlantern/lantern-outline/lantern-core/dialer"
)

// IOSBridge defines the interface for interaction with the iOS network bridge via Swift
type IOSBridge interface {
	ProcessOutboundPacket(pkt []byte) bool
	ExcludeRoute(route string) bool
}

// IOSVPNServer extends VPNServer with iOS-specific functionality.
type VPNServer interface {
	Start(ctx context.Context, bridge IOSBridge) error
	Stop() error
	IsVPNConnected() bool
	ProcessInboundPacket(rawPacket []byte, n int) error
}

// NewVPNServer initializes and returns a new instance of vpnServer
func NewVPNServer(opts *Opts) (VPNServer, error) {
	return newVPNServer(opts), nil
}

// startTun2Socks configures and starts the Tun2Socks tunnel using the provided parameters.
func (srv *vpnServer) startTun2Socks(ctx context.Context, bridge IOSBridge) error {
	cfg, err := srv.loadConfig(ctx, true)
	if err != nil {
		return err
	}
	addr := fmt.Sprintf("%s:%d", cfg.Addr, cfg.Port)
	ssconf := cfg.GetConnectCfgShadowsocks()
	dialer, err := dialer.NewStreamDialer(addr, ssconf.Cipher, ssconf.Secret)
	if err != nil {
		return err
	}
	// Exclude proxy server address from the VPN routing table
	if ok := bridge.ExcludeRoute(addr); !ok {
		return fmt.Errorf("unable to exclude route: %s", cfg.Addr)
	}
	tunWriter := &osWriter{bridge.ProcessOutboundPacket}
	if err := srv.tunnel.Start(dialer, tunWriter); err != nil {
		log.Printf("Error starting tunnel: %v", err)
		return err
	}
	defer srv.broadcastStatus()
	srv.setConnected(true)
	return nil
}

// Start initializes the Tun2Socks tunnel with the provided IOSBridge adapter.
func (s *vpnServer) Start(ctx context.Context, bridge IOSBridge) error {
	if s.IsVPNConnected() {
		return errors.New("VPN already running")
	}
	go s.startTun2Socks(ctx, bridge)
	return nil
}

// ProcessInboundPacket handles a packet received from the TUN device.
func (s *vpnServer) ProcessInboundPacket(rawPacket []byte, n int) error {
	if s.tunnel == nil {
		return nil
	}
	_, err := s.tunnel.Write(rawPacket)
	return err
}

// Stop stops the VPN server and closes the tunnel.
func (s *vpnServer) Stop() error {
	if err := s.stop(); err != nil {
		return err
	}

	if s.tunnel != nil {
		if err := s.tunnel.Close(); err != nil {
			return err
		}
	}
	return nil
}
