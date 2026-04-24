package vpn_tunnel

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/getlantern/radiance/ipc"
	"github.com/getlantern/radiance/vpn"
)

type InternalTag string

const (
	InternalTagAutoAll InternalTag = "auto-all"
)

// StartVPN is the gomobile entry point for Mobile.StartVPN (Android
// MainActivity / iOS VPNManager). It is also reached from Jigar's
// onSmartLocation rewrite in server_selection.dart via startVPN(force: true)
// → lantern.startVPN() → Mobile.StartVPN, which expects "switch back to
// auto" to work on a live tunnel. Dispatch the same way ConnectToServer
// does: when the tunnel is already up, swap outbounds via /server/selected
// instead of hitting /vpn/connect (which would 500 with
// ErrTunnelAlreadyConnected and surface a snackbar error).
func StartVPN(client *ipc.Client) error {
	slog.Info("StartVPN called")
	ctx := context.Background()
	if status, err := client.VPNStatus(ctx); err == nil && status == vpn.Connected {
		slog.Debug("VPN is already connected, switching to auto")
		return client.SelectServer(ctx, vpn.AutoSelectTag)
	}
	if err := client.ConnectVPN(ctx, vpn.AutoSelectTag); err != nil {
		return fmt.Errorf("failed to start VPN: %w", err)
	}
	return nil
}

func StopVPN(client *ipc.Client) error {
	ctx := context.Background()
	return client.DisconnectVPN(ctx)
}

// ConnectToServer switches the live tunnel to a specific server or, when the
// caller passes an empty tag, back to auto-select. The Flutter UI sends an
// empty tag to mean "Smart/auto" (see onSmartLocation in
// lib/features/vpn/server_selection.dart, which routes through
// connectToServer with ServerLocationType.auto). This path is reached from
// the gomobile bindings via lantern-core/mobile/mobile.go's ConnectToServer,
// which bypasses lanterncore.Core — so normalize the same empty→AutoSelectTag
// mapping lanterncore does, otherwise radiance's VPNClient.SelectServer
// falls into the manual-outbound branch and strands Clash in manual mode
// with an empty selector.
func ConnectToServer(client *ipc.Client, tag string) error {
	ctx := context.Background()
	if tag == "" {
		tag = vpn.AutoSelectTag
	}
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
