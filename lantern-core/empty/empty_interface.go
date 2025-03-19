package empty

import (
	"context"
	"net/netip"

	"github.com/cretz/bine/process"
	"github.com/sagernet/sing-box/adapter"
	sp "github.com/sagernet/sing-box/common/process"
	"github.com/sagernet/sing-box/experimental/libbox/platform"
	"github.com/sagernet/sing-box/option"
	tun "github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common/logger"
)

// Jigar
// Start of EmptyPlatform implementation
// This should be moved to the client side.
// This is just a simple workaround for now. I can start adding APIs later.

type EmptyPlatform struct{}

func (e EmptyPlatform) Initialize(networkManager adapter.NetworkManager) error { return nil }
func (e EmptyPlatform) UsePlatformAutoDetectInterfaceControl() bool            { return false }
func (e EmptyPlatform) AutoDetectInterfaceControl(fd int32) error              { return nil }
func (e EmptyPlatform) OpenTun(options *tun.Options, platformOptions option.TunPlatformOptions) (tun.Tun, error) {
	return nil, nil
}
func (e EmptyPlatform) CreateDefaultInterfaceMonitor(logger logger.Logger) tun.DefaultInterfaceMonitor {
	return nil
}
func (e EmptyPlatform) Interfaces() ([]adapter.NetworkInterface, error)            { return nil, nil }
func (e EmptyPlatform) UnderNetworkExtension() bool                                { return false }
func (e EmptyPlatform) IncludeAllNetworks() bool                                   { return false }
func (e EmptyPlatform) ClearDNSCache()                                             {}
func (e EmptyPlatform) ReadWIFIState() adapter.WIFIState                           { return adapter.WIFIState{} }
func (e EmptyPlatform) Search(query string) ([]process.Process, error)             { return nil, nil }
func (e EmptyPlatform) SendNotification(notification *platform.Notification) error { return nil }
func (e EmptyPlatform) FindProcessInfo(ctx context.Context, network string, source netip.AddrPort, destination netip.AddrPort) (*sp.Info, error) {
	return nil, nil
}

type Info struct {
	ProcessPath string
	PackageName string
	User        string
	UserId      int32
}
