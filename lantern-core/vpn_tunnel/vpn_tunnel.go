package vpn_tunnel

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/getlantern/radiance/ipc"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
)

type InternalTag string

const (
	InternalTagAutoAll InternalTag = "auto-all"
)

func StartVPN(client *ipc.Client) error {
	slog.Info("StartVPN called")
	ctx := context.Background()
	if err := client.ConnectVPN(ctx, vpn.AutoSelectTag); err != nil {
		return fmt.Errorf("failed to start VPN: %w", err)
	}
	return nil
}

func StopVPN(client *ipc.Client) error {
	ctx := context.Background()
	return client.DisconnectVPN(ctx)
}

func ConnectToServer(client *ipc.Client, _, tag string) error {
	ctx := context.Background()
	slog.Debug("Connecting to VPN server", "tag", tag)
	return client.SelectServer(ctx, tag)
}

func IsVPNRunning(client *ipc.Client) bool {
	slog.Debug("Checking if VPN is running...")
	ctx := context.Background()
	status, err := client.VPNStatus(ctx)
	slog.Debug("VPN status:", "status", status, "Error:", err)
	return status == vpn.Connected
}

func GetSelectedServer(client *ipc.Client) string {
	slog.Debug("Getting selected VPN server...")
	ctx := context.Background()
	server, exists, err := client.SelectedServer(ctx)
	if err != nil || !exists {
		slog.Debug("Error getting selected server:", "error", err)
		return ""
	}
	return server.Tag
}

func GetAutoLocation(client *ipc.Client) (*servers.Server, error) {
	slog.Debug("Getting auto location...")
	ctx := context.Background()
	server, err := client.AutoSelected(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get auto location: %w", err)
	}
	return server, nil
}
