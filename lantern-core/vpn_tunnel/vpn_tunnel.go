package vpn_tunnel

import (
	"fmt"
	"path/filepath"

	"github.com/getlantern/lantern-outline/lantern-core/utils"
	radianceCommon "github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
	"github.com/sagernet/sing-box/experimental/libbox"
)

type InternalTag string

const (
	InternalTagAutoAll InternalTag = "auto-all"
	InternalTagUser    InternalTag = InternalTag(string(servers.SGUser))
	InternalTagLantern InternalTag = InternalTag(string(servers.SGLantern))
)

// StartVPN will start the VPN tunnel using the provided platform interface.
// it pass empty string so it will connect to best server available.
func StartVPN(platform libbox.PlatformInterface, options *utils.Opts) error {
	if radianceCommon.IsIOS() || radianceCommon.IsMacOS() {
		err := initializeCommonForApplePlatforms(options.DataDir, filepath.Join(options.DataDir, "logs"), options.LogLevel)
		if err != nil {
			return err
		}
	}
	/// it should use InternalTagLantern so it will connect to best lantern server by default.
	// if you want to connect to user server, use ConnectToServer with InternalTagUser
	return vpn.QuickConnect(string(InternalTagLantern), platform)
}

// StopVPN will stop the VPN tunnel.
func StopVPN() error {
	defer func() {
		if r := recover(); r != nil {
			fmt.Errorf("Recovered from panic in StopVPN: %v", r)
		}
	}()
	return vpn.Disconnect()
}

// ConnectToServer will connect to a specific VPN server group and tag.
// this will select server and start the VPN tunnel.
// Valid location types are: [auto],[privateServer],[lanternLocation]
func ConnectToServer(group, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	var internalTag string
	switch group {
	case "auto":
		internalTag = string(InternalTagAutoAll)
	case "privateServer":
		internalTag = string(InternalTagUser)
	case "lanternLocation":
		internalTag = string(InternalTagLantern)
	}
	if radianceCommon.IsIOS() || radianceCommon.IsMacOS() {
		err := initializeCommonForApplePlatforms(options.DataDir, filepath.Join(options.DataDir, "logs"), options.LogLevel)
		if err != nil {
			return err
		}
	}
	return vpn.ConnectToServer(internalTag, tag, platIfce)
}

func IsVPNRunning() bool {
	fmt.Println("Checking if VPN is running...")
	status, err := vpn.GetStatus()
	fmt.Println("VPN status:", status, "Error:", err)
	// if err != nil {
	// 	fmt.Errorf("failed to get VPN status: %w", err)
	// 	return false
	// }
	fmt.Println("VPN status is tunnel:", status.TunnelOpen)
	return status.TunnelOpen
}

func initializeCommonForApplePlatforms(dataDir, logDir, logLevel string) error {
	// Since this will start as a new process, we need to ask for path and logger.
	// This ensures options are correctly set for the new process.
	fmt.Println("Initializing common for Apple platforms with dataDir:", dataDir, "logDir:", logDir, "logLevel:", logLevel)
	if err := radianceCommon.Init(dataDir, logDir, logLevel); err != nil {
		return fmt.Errorf("failed to initialize common: %w", err)
	}
	return nil
}
