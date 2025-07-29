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

// StartVPN will start the VPN tunnel using the provided platform interface.
// it pass empty string so it will connect to best server available.
func StartVPN(platform libbox.PlatformInterface, options *utils.Opts) error {
	if radianceCommon.IsIOS() || radianceCommon.IsMacOS() {
		err := initializeCommonForApplePlatforms(options.DataDir, filepath.Join(options.DataDir, "logs"), options.LogLevel)
		if err != nil {
			return err
		}
	}
	return vpn.QuickConnect("", platform)
}

// StopVPN will stop the VPN tunnel.
func StopVPN() error {
	return vpn.Disconnect()
}

// ConnectToServer will connect to a specific VPN server group and tag.
// this will select server and start the VPN tunnel.
// Valid location types are: [auto],[privateServer],[lanternLocation]
func ConnectToServer(group, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	var internalTag string
	switch group {
	case "auto":
		internalTag = "auto-all"
	case "privateServer":
		internalTag = servers.SGUser
	case "lanternLocation":
		internalTag = servers.SGLantern
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
	status, err := vpn.GetStatus()
	if err != nil {
		return false
	}
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
