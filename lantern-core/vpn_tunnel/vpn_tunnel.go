package vpn_tunnel

import (
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
	"github.com/sagernet/sing-box/experimental/libbox"
)

// StartVPN will start the VPN tunnel using the provided platform interface.
// it pass empty string so it will connect to best server available.
func StartVPN(platform libbox.PlatformInterface) error {
	return vpn.QuickConnect("", platform)
}

// StopVPN will stop the VPN tunnel.
func StopVPN() error {
	return vpn.Disconnect()
}

// ConnectToServer will connect to a specific VPN server group and tag.
// this will select server and start the VPN tunnel.
// Valid location types are: [auto],[privateServer],[lanternLocation]
func ConnectToServer(group, tag string, platIfce libbox.PlatformInterface) error {
	var internalTag string
	switch group {
	case "auto":
		internalTag = "auto-all"
	case "privateServer":
		internalTag = servers.SGUser
	case "lanternLocation":
		internalTag = servers.SGLantern
	}
	return vpn.ConnectToServer(internalTag, tag, platIfce)
}

func IsVPNRunning() bool {
	status, err := vpn.GetStatus()
	if err != nil {
		return false
	}
	return status.TunnelOpen
}


