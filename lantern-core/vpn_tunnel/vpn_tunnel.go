package vpn_tunnel

import (
	"fmt"
	"path/filepath"

	radianceCommon "github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
	"github.com/sagernet/sing-box/experimental/libbox"

	"github.com/getlantern/lantern-outline/lantern-core/utils"
)

const (
	GroupTagAutoAll = "all"
	GroupTagUser    = servers.SGUser
	GroupTagLantern = servers.SGLantern
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
	defer func() {
		if r := recover(); r != nil {
			fmt.Errorf("Recovered from panic in StopVPN: %v", r)
		}
	}()
	return vpn.Disconnect()
}

// ConnectToServer will connect to a specific VPN server identified by the group and tag. If tag is
// empty, it will connect to the best server available in that group. ConnectToServer will start the
// VPN tunnel if it's not already running.
//
// Valid group types are: [GroupTagAutoAll, GroupTagUser, GroupTagLantern].
func ConnectToServer(group, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	if radianceCommon.IsIOS() || radianceCommon.IsMacOS() {
		err := initializeCommonForApplePlatforms(options.DataDir, filepath.Join(options.DataDir, "logs"), options.LogLevel)
		if err != nil {
			return err
		}
	}
	if group == GroupTagAutoAll || tag == "" {
		return vpn.QuickConnect(group, platIfce)
	}
	return vpn.ConnectToServer(group, tag, platIfce)
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
