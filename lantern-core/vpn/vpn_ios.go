//go:build ios
// +build ios

package vpn

import (
	"context"
	"errors"
	"fmt"

	"github.com/getlantern/kindling"
	localconfig "github.com/getlantern/lantern-outline/config"
	"github.com/getlantern/lantern-outline/lantern-core/dialer"
	"github.com/getlantern/radiance/common/reporting"
	"github.com/getlantern/radiance/config"
	"github.com/getlantern/radiance/user"
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
	k := kindling.NewKindling(
		kindling.WithPanicListener(reporting.PanicListener),
		kindling.WithDomainFronting("https://raw.githubusercontent.com/getlantern/lantern-binaries/refs/heads/main/fronted.yaml.gz", ""),
		kindling.WithProxyless("api.iantem.io"),
	)
	user := user.New(k.NewHTTPClient())
	// create a new instance of config handler that uses kindling HTTP client
	opts.ConfigHandler = config.NewConfigHandler(configPollInterval, k.NewHTTPClient(), user)
	return newVPNServer(opts), nil
}

// loadConfig is used to load the configuration file. If useLocalConfig is true then we use the embedded config
func (srv *vpnServer) loadConfig(ctx context.Context, useLocalConfig bool) (*config.Config, error) {
	if useLocalConfig {
		return localconfig.LoadConfig()
	}
	cfgs, _, err := srv.configHandler.GetConfig(ctx)
	if err != nil {
		return nil, err
	} else if len(cfgs) == 0 {
		return nil, errors.New("no config available")
	}
	return cfgs[0], nil
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
		log.Errorf("Error starting tunnel: %v", err)
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
