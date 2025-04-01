package mobile

import (
	"github.com/getlantern/lantern-outline/lantern-core/mobile/libbox"
	singbox "github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/option"
	tun "github.com/sagernet/sing-tun"
)

// singBoxPlatformWrapper adapts our existing PlatformInterface for Sing-box
type singBoxPlatformWrapper struct {
	platform libbox.PlatformInterface
	device   tun.Tun
}

func (w *singBoxPlatformWrapper) LocalDNSTransport() singbox.LocalDNSTransport {
	original := w.platform.LocalDNSTransport()
	return singbox.LocalDNSTransport(original)
}

func (w *singBoxPlatformWrapper) UsePlatformAutoDetectInterfaceControl() bool {
	return w.platform.UsePlatformAutoDetectInterfaceControl()
}

func (w *singBoxPlatformWrapper) AutoDetectInterfaceControl(fd int32) error {
	return w.platform.AutoDetectInterfaceControl(fd)
}

func (w *singBoxPlatformWrapper) OpenTun(platformOptions singbox.TunOptions) (int32, error) {
	options := &libbox.TunOptions{}
	device, err := libbox.OpenTun(options, w.platform, option.TunPlatformOptions{})
	if err != nil {
		return 0, err
	}
	w.device = device
	return 0, nil
}

func (w *singBoxPlatformWrapper) WriteLog(message string) {
	w.platform.WriteLog(message)
}

func (w *singBoxPlatformWrapper) UseProcFS() bool {
	return w.platform.UseProcFS()
}

func (w *singBoxPlatformWrapper) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (int32, error) {
	return w.platform.FindConnectionOwner(ipProtocol, sourceAddress, sourcePort, destinationAddress, destinationPort)
}

func (w *singBoxPlatformWrapper) PackageNameByUid(uid int32) (string, error) {
	return w.platform.PackageNameByUid(uid)
}

func (w *singBoxPlatformWrapper) UIDByPackageName(packageName string) (int32, error) {
	return w.platform.UIDByPackageName(packageName)
}

func (w *singBoxPlatformWrapper) StartDefaultInterfaceMonitor(listener singbox.InterfaceUpdateListener) error {
	return w.platform.StartDefaultInterfaceMonitor(libbox.InterfaceUpdateListener(listener))
}

func (w *singBoxPlatformWrapper) CloseDefaultInterfaceMonitor(listener singbox.InterfaceUpdateListener) error {
	return w.platform.CloseDefaultInterfaceMonitor(libbox.InterfaceUpdateListener(listener))
}

func (w *singBoxPlatformWrapper) GetInterfaces() (singbox.NetworkInterfaceIterator, error) {
	iterator, err := w.platform.GetInterfaces()
	if err != nil {
		return nil, err
	}
	return &SingBoxNetworkInterfaceIterator{iterator}, nil
}

func (w *singBoxPlatformWrapper) UnderNetworkExtension() bool {
	return w.platform.UnderNetworkExtension()
}

func (w *singBoxPlatformWrapper) IncludeAllNetworks() bool {
	return w.platform.IncludeAllNetworks()
}

func (w *singBoxPlatformWrapper) ReadWIFIState() *singbox.WIFIState {
	original := w.platform.ReadWIFIState()
	return &singbox.WIFIState{
		SSID:  original.SSID,
		BSSID: original.BSSID,
	}
}

func (w *singBoxPlatformWrapper) SystemCertificates() singbox.StringIterator {
	return w.platform.SystemCertificates()
}

func (w *singBoxPlatformWrapper) ClearDNSCache() {
	w.platform.ClearDNSCache()
}

func (w *singBoxPlatformWrapper) SendNotification(original *singbox.Notification) error {
	notification := &libbox.Notification{
		Identifier: original.Identifier,
		TypeName:   original.TypeName,
		TypeID:     original.TypeID,
		Title:      original.Title,
		Subtitle:   original.Subtitle,
		Body:       original.Body,
		OpenURL:    original.OpenURL,
	}
	return w.platform.SendNotification(notification)
}

// Wrapper for libbox.NetworkInterfaceIterator
type SingBoxNetworkInterfaceIterator struct {
	iterator libbox.NetworkInterfaceIterator
}

func (s *SingBoxNetworkInterfaceIterator) Next() *singbox.NetworkInterface {
	orig := s.iterator.Next()
	if orig == nil {
		return nil
	}

	return &singbox.NetworkInterface{
		Index:     orig.Index,
		MTU:       orig.MTU,
		Name:      orig.Name,
		Addresses: orig.Addresses,
		Flags:     orig.Flags,
		Type:      orig.Type,
		DNSServer: orig.DNSServer,
		Metered:   orig.Metered,
	}
}

func (s *SingBoxNetworkInterfaceIterator) HasNext() bool {
	return s.iterator.HasNext()
}
