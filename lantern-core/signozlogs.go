package lanterncore

import (
	"context"
	"log/slog"
	"time"

	"github.com/getlantern/radiance/common/settings"
)

// disableSigNozLogUploadOffNightly turns send_logs_to_signoz off in every
// build but nightly. Only Developer mode can turn it on, and the shipped app
// shows that only in nightlies, but the setting outlives the install: a
// release or stealth build installed over a nightly would otherwise keep
// uploading logs. Stealth and local builds link no BuildType, so they are
// turned off too. It goes through the IPC client so it reaches the backend's
// settings, which on desktop belong to the daemon, and retries while the
// backend comes up.
func disableSigNozLogUploadOffNightly(ctx context.Context, client logLevelSettings, delays []time.Duration) {
	if BuildType == "nightly" {
		return
	}
	for i := 0; ; i++ {
		err := disableSigNozLogUpload(ctx, client)
		if err == nil {
			return
		}
		if ctx.Err() != nil {
			return
		}
		if i == len(delays) {
			slog.Warn("Unable to turn off SigNoz log upload; retrying next launch", "error", err)
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(delays[i]):
		}
	}
}

func disableSigNozLogUpload(ctx context.Context, client logLevelSettings) error {
	s, err := client.Settings(ctx)
	if err != nil {
		return err
	}
	if on, _ := s[settings.SendLogsToSigNozKey].(bool); !on {
		return nil
	}
	if _, err := client.PatchSettings(ctx, settings.Settings{settings.SendLogsToSigNozKey: false}); err != nil {
		return err
	}
	slog.Info("Turned off SigNoz log upload outside nightly")
	return nil
}
