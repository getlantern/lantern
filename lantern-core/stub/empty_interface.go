package empty

import "github.com/sagernet/sing-box/experimental/libbox"

// Jigar
// Start of EmptyPlatform implementation
// This should be moved to the client side.
// This is just a simple workaround for now. I can start adding APIs later.

func NewPlatformInterfaceStub() libbox.PlatformInterface {
	return &platformInterfaceStub{}
}

type platformInterfaceStub struct {
}

// AutoDetectInterfaceControl implements libbox.PlatformInterface.
func (p *platformInterfaceStub) AutoDetectInterfaceControl(fd int32) error {
	return nil
}

// ClearDNSCache implements libbox.PlatformInterface.
func (p *platformInterfaceStub) ClearDNSCache() {
}

// CloseDefaultInterfaceMonitor implements libbox.PlatformInterface.
func (p *platformInterfaceStub) CloseDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	return nil
}

// FindConnectionOwner implements libbox.PlatformInterface.
func (p *platformInterfaceStub) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (int32, error) {
	panic("unimplemented")
}

// GetInterfaces implements libbox.PlatformInterface.
func (p *platformInterfaceStub) GetInterfaces() (libbox.NetworkInterfaceIterator, error) {
	panic("unimplemented")
}

// IncludeAllNetworks implements libbox.PlatformInterface.
func (p *platformInterfaceStub) IncludeAllNetworks() bool {
	return false
}

// OpenTun implements libbox.PlatformInterface.
func (p *platformInterfaceStub) OpenTun(options libbox.TunOptions) (int32, error) {
	panic("unimplemented")
}

// PackageNameByUid implements libbox.PlatformInterface.
func (p *platformInterfaceStub) PackageNameByUid(uid int32) (string, error) {
	panic("unimplemented")
}

// ReadWIFIState implements libbox.PlatformInterface.
func (p *platformInterfaceStub) ReadWIFIState() *libbox.WIFIState {
	return nil
}

// SendNotification implements libbox.PlatformInterface.
func (p *platformInterfaceStub) SendNotification(notification *libbox.Notification) error {
	return nil
}

// StartDefaultInterfaceMonitor implements libbox.PlatformInterface.
func (p *platformInterfaceStub) StartDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	return nil
}

// UIDByPackageName implements libbox.PlatformInterface.
func (p *platformInterfaceStub) UIDByPackageName(packageName string) (int32, error) {
	return 0, nil
}

// UnderNetworkExtension implements libbox.PlatformInterface.
func (p *platformInterfaceStub) UnderNetworkExtension() bool {
	return false
}

// UsePlatformAutoDetectInterfaceControl implements libbox.PlatformInterface.
func (p *platformInterfaceStub) UsePlatformAutoDetectInterfaceControl() bool {
	return false
}

// UseProcFS implements libbox.PlatformInterface.
func (p *platformInterfaceStub) UseProcFS() bool {
	return false
}

// WriteLog implements libbox.PlatformInterface.
func (p *platformInterfaceStub) WriteLog(message string) {
}
