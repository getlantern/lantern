//go:build android || ios || darwin

package lanterncore

import (
	"context"
	"runtime"

	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/ipc"

	"github.com/getlantern/lantern/lantern-core/utils"
)

func createClient(ctx context.Context, opts *utils.Opts) (*ipc.Client, error) {
	if runtime.GOOS == "android" {
		return ipc.NewRemoteClient(), nil
	}
	backendOpts := backend.Options{
		DataDir:                 opts.DataDir,
		LogDir:                  opts.LogDir,
		DeviceID:                opts.Deviceid,
		LogLevel:                opts.LogLevel,
		Locale:                  opts.Locale,
		TelemetryConsent:        opts.TelemetryConsent,
		EnvOverrides:            opts.RadianceEnvOverrides(),
		UserMessageCapabilities: utils.UserMessageCapabilities(),
	}
	return ipc.NewClient(ctx, backendOpts)
}
