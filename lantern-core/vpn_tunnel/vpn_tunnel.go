package vpn_tunnel

import (
	"fmt"
	"log/slog"

	radianceCommon "github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
	"github.com/sagernet/sing-box/experimental/libbox"

	"github.com/getlantern/lantern-outline/lantern-core/utils"
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
	/// it should use InternalTagLantern so it will connect to best lantern server by default.
	// if you want to connect to user server, use ConnectToServer with InternalTagUser
	return vpn.QuickConnect("", platform)
}

// StopVPN will stop the VPN tunnel.
func StopVPN() error {
	return vpn.Disconnect()
}

// ConnectToServer will connect to a specific VPN server identified by the group and tag. If tag is
// empty, it will connect to the best server available in that group. ConnectToServer will start the
// VPN tunnel if it's not already running.
func ConnectToServer(group, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	switch group {
	case string(InternalTagAutoAll), "auto":
		group = "all"
	case "privateServer":
		group = string(InternalTagUser)
	case "lanternLocation":
		group = string(InternalTagLantern)
	}
	if radianceCommon.IsIOS() || radianceCommon.IsMacOS() {
		err := initializeCommonForApplePlatforms(options)
		if err != nil {
			return err
		}
	}
	if tag == "" {
		return vpn.QuickConnect(group, platIfce)
	}
	return vpn.ConnectToServer(group, tag, platIfce)
}

func IsVPNRunning() bool {
	slog.Debug("Checking if VPN is running...")
	status, err := vpn.GetStatus()
	slog.Debug("VPN status:", "status", status, "Error:", err)
	return status.TunnelOpen
}

func GetSelectedServer() string {
	slog.Debug("Getting selected VPN server...")
	status, err := vpn.GetStatus()
	slog.Debug("VPN status:", "status", status, "Error:", err)
	return status.SelectedServer
}

func initializeCommonForApplePlatforms(options *utils.Opts) error {
	// Since this will start as a new process, we need to ask for path and logger.
	// This ensures options are correctly set for the new process.
	slog.Debug("Initializing common for Apple platforms", "dataDir", options.DataDir, "logDir:",
		options.LogDir, "logLevel:", options.LogLevel)
	if err := radianceCommon.Init(options.DataDir, options.LogDir, options.LogLevel, options.Deviceid); err != nil {
		return fmt.Errorf("failed to initialize common: %w", err)
	}
	return nil
}
