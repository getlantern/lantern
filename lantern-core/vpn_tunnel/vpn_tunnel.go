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
// It passes the empty string so it will connect to best server available.
func StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error {
	// As soon user connects to VPN, we start listening for auto location changes.
	slog.Info("StartVPN called")
	if err := initCommon(opts); err != nil {
		return fmt.Errorf("failed to initialize common: %w", err)
	}
	// it should use InternalTagLantern so it will connect to best lantern server by default.
	// if you want to connect to user server, use ConnectToServer with InternalTagUser
	err := vpn.QuickConnect("", platform)
	if err != nil {
		return fmt.Errorf("failed to start VPN: %w", err)
	}
	return nil
}

// StopVPN will stop the VPN tunnel.
func StopVPN() error {
	return vpn.Disconnect()
}

// ConnectToServer will connect to a specific VPN server identified by the group and tag. If tag is
// empty, it will connect to the best server available in that group. ConnectToServer will start the
// VPN tunnel if it's not already running.
func ConnectToServer(group, tag string, platIfce libbox.PlatformInterface, opts *utils.Opts) error {
	slog.Debug("ConnectToServer called", "group", group, "tag", tag)
	if err := initCommon(opts); err != nil {
		return fmt.Errorf("failed to initialize common: %w", err)
	}
	switch group {
	case string(InternalTagAutoAll), "auto":
		group = "all"
	case "privateServer":
		group = string(InternalTagUser)
	case "lanternLocation":
		group = string(InternalTagLantern)
	}
	slog.Debug("Connecting to VPN server", "group", group, "tag", tag)
	if tag == "" {
		return vpn.QuickConnect(group, platIfce)
	}
	slog.Debug("Connecting to specific VPN server", "group", group, "tag", tag)
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

func initCommon(opts *utils.Opts) error {
	// Since this will start as a new process, we need to ask for path and logger.
	// This ensures options are correctly set for the new process.
	if radianceCommon.IsIOS() || radianceCommon.IsMacOS() {
		slog.Debug("Initializing common for Apple platforms", "dataDir", opts.DataDir, "logDir:",
			opts.LogDir, "logLevel:", opts.LogLevel)
		if err := radianceCommon.Init(opts.DataDir, opts.LogDir, opts.LogLevel); err != nil {
			return fmt.Errorf("failed to initialize common: %w", err)
		}
	} else if radianceCommon.IsWindows() {
		if err := radianceCommon.Init("", "", "debug"); err != nil {
			return fmt.Errorf("failed to initialize common: %w", err)
		}
	}

	return nil
}

// GetAutoLocation returns the current auto location as a JSON string.
func GetAutoLocation() (*vpn.AutoSelections, error) {
	slog.Debug("Getting auto location...")
	location, err := vpn.AutoServerSelections()
	slog.Debug("Auto location:", "location", location, "Error:", err)
	if err != nil {
		return nil, fmt.Errorf("failed to get auto location: %w", err)
	}
	return &location, nil
}
