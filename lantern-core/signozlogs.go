package lanterncore

import (
	"context"
	"log/slog"
	"time"

	"github.com/getlantern/radiance/common/settings"
)

// Every build but nightly turns send_logs_to_signoz off. Only Developer mode
// can turn it on, and the shipped app shows that only in nightlies, but the
// setting outlives the install: a release or stealth build installed over a
// nightly would otherwise keep uploading logs. Stealth and local builds link
// no BuildType, so they are turned off too.
func sigNozLogUploadAllowed() bool {
	return BuildType == "nightly"
}

// DisableSigNozLogUploadBeforeStart turns send_logs_to_signoz off through
// patch outside nightly. The mobile and Apple extension backends call it
// between building the backend and starting it, so telemetry never starts
// with upload on. It reads this process's settings, which the backend has
// just loaded.
func DisableSigNozLogUploadBeforeStart(patch func(settings.Settings) error) error {
	if sigNozLogUploadAllowed() || !settings.GetBool(settings.SendLogsToSigNozKey) {
		return nil
	}
	if err := patch(settings.Settings{settings.SendLogsToSigNozKey: false}); err != nil {
		return err
	}
	slog.Info("Turned off SigNoz log upload outside nightly")
	return nil
}

// disableSigNozLogUploadOffNightly applies the same rule from the UI process
// over the IPC client, so it reaches the backend's settings, which on desktop
// belong to the daemon. It retries while the backend comes up. Radiance
// applies a patch live even when saving it fails, so a failed save still
// stops upload for this session. Nothing records that the check ran, so the
// next launch, and the next mobile backend start, patch a value still on
// disk again.
func disableSigNozLogUploadOffNightly(ctx context.Context, client logLevelSettings, delays []time.Duration) {
	if sigNozLogUploadAllowed() {
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
