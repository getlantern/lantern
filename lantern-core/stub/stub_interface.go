package stub

import (
	"errors"

	"github.com/sagernet/sing-box/experimental/libbox"
)

func NewPlatformInterfaceStub() libbox.PlatformInterface {
	return &platformInterfaceStub{}
}

type platformInterfaceStub struct {
}

func (p *platformInterfaceStub) LocalDNSTransport() libbox.LocalDNSTransport { return nil }

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
func (p *platformInterfaceStub) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (*libbox.ConnectionOwner, error) {
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

func (p *platformInterfaceStub) CancelNotification(identifier string, typeID int32) error {
	return nil
}

func (p *platformInterfaceStub) StartNeighborMonitor(listener libbox.NeighborUpdateListener) error {
	return errors.ErrUnsupported
}

func (p *platformInterfaceStub) CloseNeighborMonitor(listener libbox.NeighborUpdateListener) error {
	return nil
}

func (p *platformInterfaceStub) RegisterMyInterface(name string) {}

func (p *platformInterfaceStub) UsePlatformShell() bool { return false }

func (p *platformInterfaceStub) CheckPlatformShell() error {
	return errors.ErrUnsupported
}

func (p *platformInterfaceStub) OpenShellSession(user *libbox.PlatformUser, command string, environ libbox.StringIterator, term string, rows int32, cols int32) (libbox.ShellSession, error) {
	return nil, errors.ErrUnsupported
}

func (p *platformInterfaceStub) LookupUser(username string) (*libbox.PlatformUser, error) {
	return nil, errors.ErrUnsupported
}

func (p *platformInterfaceStub) LookupSFTPServer() (string, error) {
	return "", errors.ErrUnsupported
}

func (p *platformInterfaceStub) ReadSystemSSHHostKey() (string, error) {
	return "", errors.ErrUnsupported
}

func (p *platformInterfaceStub) TailscaleHostname() string { return "" }

func (p *platformInterfaceStub) UsePlatformBridge() bool { return false }

func (p *platformInterfaceStub) CreateBridge(options *libbox.BridgeOptions) (libbox.BridgeSession, error) {
	return nil, errors.ErrUnsupported
}
