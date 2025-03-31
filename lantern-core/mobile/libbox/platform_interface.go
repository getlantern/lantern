package libbox

import (
	singbox "github.com/sagernet/sing-box/experimental/libbox"
)

type InterfaceUpdateListener interface {
	UpdateDefaultInterface(interfaceName string, interfaceIndex int32, isExpensive bool, isConstrained bool)
}

type PlatformInterface interface {
	LocalDNSTransport() singbox.LocalDNSTransport
	UsePlatformAutoDetectInterfaceControl() bool
	AutoDetectInterfaceControl(fd int32) error
	OpenTun(options TunOptions) (int32, error)
	WriteLog(message string)
	UseProcFS() bool
	FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (int32, error)
	PackageNameByUid(uid int32) (string, error)
	UIDByPackageName(packageName string) (int32, error)
	StartDefaultInterfaceMonitor(listener singbox.InterfaceUpdateListener) error
	CloseDefaultInterfaceMonitor(listener singbox.InterfaceUpdateListener) error
	GetInterfaces() (NetworkInterfaceIterator, error)
	UnderNetworkExtension() bool
	IncludeAllNetworks() bool
	ReadWIFIState() *WIFIState
	SystemCertificates() StringIterator
	ClearDNSCache()
	SendNotification(notification *Notification) error
}

type TunInterface interface {
	FileDescriptor() int32
	Close() error
}

type NetworkInterface struct {
	Index     int32
	MTU       int32
	Name      string
	Addresses StringIterator
	Flags     int32

	Type      int32
	DNSServer StringIterator
	Metered   bool
}

type WIFIState struct {
	SSID  string
	BSSID string
}

func NewWIFIState(wifiSSID string, wifiBSSID string) *WIFIState {
	return &WIFIState{wifiSSID, wifiBSSID}
}

type NetworkInterfaceIterator interface {
	Next() *NetworkInterface
	HasNext() bool
}

type Notification struct {
	Identifier string
	TypeName   string
	TypeID     int32
	Title      string
	Subtitle   string
	Body       string
	OpenURL    string
}
