//go:build android || ios || darwin

package lanterncore

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/ipc"

	"github.com/getlantern/lantern/lantern-core/utils"
)

func createClient(ctx context.Context, opts *utils.Opts) (*ipc.Client, error) {
	var envOverrides map[string]string
	if opts.EnvOverrides != "" {
		if err := json.Unmarshal([]byte(opts.EnvOverrides), &envOverrides); err != nil {
			slog.Warn("failed to parse EnvOverrides JSON", slog.Any("error", err))
		}
	}
	backendOpts := backend.Options{
		DataDir:           opts.DataDir,
		LogDir:            opts.LogDir,
		DeviceID:          opts.Deviceid,
		LogLevel:          opts.LogLevel,
		Locale:            opts.Locale,
		TelemetryConsent:  opts.TelemetryConsent,
		PlatformInterface: opts.Platform,
		EnvOverrides:      envOverrides,
	}
	return ipc.NewClient(ctx, backendOpts)
}
