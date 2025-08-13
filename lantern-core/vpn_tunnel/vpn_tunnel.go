package vpn_tunnel

import (
	"fmt"
	"log/slog"

	"github.com/getlantern/lantern-outline/lantern-core/utils"
	radianceCommon "github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
	"github.com/sagernet/sing-box/experimental/libbox"
)

type InternalTag string

const (
	InternalTagAutoAll InternalTag = "auto-all"
	InternalTagUser    InternalTag = InternalTag(servers.SGUser)
	InternalTagLantern InternalTag = InternalTag(servers.SGLantern)
)

// StartVPN will start the VPN tunnel using the provided platform interface.
// it pass empty string so it will connect to best server available.
func StartVPN(platform libbox.PlatformInterface, options *utils.Opts) error {
	if radianceCommon.IsIOS() || radianceCommon.IsMacOS() {
		err := initializeCommonForApplePlatforms(options)
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
			slog.Error("recovered from panic in StopVPN:", "r", r)
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
		err := initializeCommonForApplePlatforms(options)
		if err != nil {
			return err
		}
	}
	return vpn.ConnectToServer(internalTag, tag, platIfce)
}

func IsVPNRunning() bool {
	slog.Debug("Checking if VPN is running...")
	status, err := vpn.GetStatus()
	slog.Debug("VPN status:", "status", status, "Error:", err)
	// if err != nil {
	// 	fmt.Errorf("failed to get VPN status: %w", err)
	// 	return false
	// }
	slog.Debug("VPN status is tunnel:", "tunnelOpen", status.TunnelOpen)
	return status.TunnelOpen
}

func initializeCommonForApplePlatforms(options *utils.Opts) error {
	// Since this will start as a new process, we need to ask for path and logger.
	// This ensures options are correctly set for the new process.
	slog.Debug("Initializing common for Apple platforms", "dataDir", options.DataDir, "logDir:",
		options.LogDir, "logLevel:", options.LogLevel)
	if err := radianceCommon.Init(options.DataDir, options.LogDir, options.LogLevel); err != nil {
		return fmt.Errorf("failed to initialize common: %w", err)
	}
	return nil
}
