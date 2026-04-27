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
// auto" to work on a live tunnel. Delegate to ConnectToServer so the
// VPNStatus → /server/selected dispatch handles that case.
func StartVPN(ctx context.Context, client *ipc.Client) error {
	slog.Info("StartVPN called")
	return ConnectToServer(ctx, client, vpn.AutoSelectTag)
}

func StopVPN(ctx context.Context, client *ipc.Client) error {
	return client.DisconnectVPN(ctx)
}

// ConnectToServer switches the live tunnel to a specific server or, when the
// caller passes an empty tag or vpn.AutoSelectTag, back to auto-select.
// Radiance normalizes the empty-tag case server-side (fac9089) for both
// ConnectVPN and SelectServer.
//
// The caller is responsible for putting a deadline on ctx — the connect
// path involves real network work (DNS, TLS, sing-box bring-up) and we
// don't want a hung lanternd to stall the UI forever. LanternCore.ConnectVPN
// uses 60 s.
func ConnectToServer(ctx context.Context, client *ipc.Client, tag string) error {
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
