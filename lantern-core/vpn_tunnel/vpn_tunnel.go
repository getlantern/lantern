package vpn_tunnel

import (
	"context"
	"fmt"
	"log/slog"
	"sync"

	"github.com/getlantern/radiance/ipc"
	"github.com/getlantern/radiance/vpn"
)

type InternalTag string

const (
	InternalTagAutoAll InternalTag = "auto-all"
)

var connectMu sync.Mutex

type vpnClient interface {
	VPNStatus(context.Context) (vpn.VPNStatus, error)
	ConnectVPN(context.Context, string) error
	SelectServer(context.Context, string) error
}

// StartVPN starts the tunnel with automatic server selection.
func StartVPN(ctx context.Context, client *ipc.Client) error {
	slog.Info("StartVPN called")
	return ConnectToServer(ctx, client, vpn.AutoSelectTag)
}

func StopVPN(ctx context.Context, client *ipc.Client) error {
	return client.DisconnectVPN(ctx)
}

// ConnectToServer starts the tunnel or changes the selected server.
func ConnectToServer(ctx context.Context, client *ipc.Client, tag string) error {
	return connectToServer(ctx, client, tag)
}

func connectToServer(ctx context.Context, client vpnClient, tag string) error {
	connectMu.Lock()
	defer connectMu.Unlock()

	slog.Debug("Connecting to VPN server", "tag", tag)

	// Switch outbounds on the live tunnel when already connected;
	// otherwise start the tunnel with the chosen tag.
	status, err := client.VPNStatus(ctx)
	if err != nil {
		return fmt.Errorf("get VPN status failed: %w", err)
	}
	if status == vpn.Connected {
		slog.Debug("VPN is already connected, switching server", "tag", tag)
		return client.SelectServer(ctx, tag)
	}
	slog.Debug("VPN is not connected, starting VPN with selected server", "tag", tag)
	return client.ConnectVPN(ctx, tag)
}
