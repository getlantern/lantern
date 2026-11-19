package lanterncore

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	"github.com/getlantern/radiance/common/settings"
)

// BuildType is the Makefile's BUILD_TYPE, linked in with -X. It is empty in
// local and stealth builds.
var BuildType string

const nightlyLogLevelMarker = ".nightly-log-level-migrated"

var nightlyLogLevelMigrationDelays = []time.Duration{
	2 * time.Second,
	5 * time.Second,
	10 * time.Second,
	20 * time.Second,
	40 * time.Second,
}

// DefaultLogLevel is the level for builds whose platform passes none. Trace
// in production kept always-on tunnels writing per-read log lines around the
// clock (battery + disk, FD #184449), so releases use info. Nightly testers
// need debug detail in their reports. Debug builds and staging opt into
// trace at the call sites.
func DefaultLogLevel() string {
	if BuildType == "nightly" {
		return "debug"
	}
	return "info"
}

type logLevelSettings interface {
	Settings(ctx context.Context) (settings.Settings, error)
	PatchSettings(ctx context.Context, updates settings.Settings) (settings.Settings, error)
}

// migrateNightlyLogLevel moves a nightly install's persisted level from info
// to debug once. Radiance only seeds log_level when it is absent, so an
// install that persisted info before nightly defaulted to debug would stay at
// info. The marker keeps a tester who later picks info deliberately at info.
// It goes through the IPC client so it reaches the backend's settings, which
// on desktop belong to the daemon. migrateLocal, when set, migrates this
// process's own settings too: the desktop UI runs its own common.Init, and
// its logger reads its own settings file.
func migrateNightlyLogLevel(ctx context.Context, client logLevelSettings, migrateLocal func() error, dataDir string, delays []time.Duration) {
	if BuildType != "nightly" || dataDir == "" {
		return
	}
	marker := filepath.Join(dataDir, nightlyLogLevelMarker)
	if _, err := os.Stat(marker); !errors.Is(err, os.ErrNotExist) {
		return
	}
	for i := 0; ; i++ {
		s, err := client.Settings(ctx)
		if err == nil {
			if level, _ := s[settings.LogLevelKey].(string); level == "info" {
				// Radiance can publish a patch it failed to save, so a failed
				// patch leaves the marker unset for the next launch to retry.
				if _, err := client.PatchSettings(ctx, settings.Settings{settings.LogLevelKey: "debug"}); err != nil {
					slog.Warn("Nightly log level migration failed; retrying next launch", "error", err)
					return
				}
				slog.Info("Raised nightly log level from info to debug")
			}
			break
		}
		if ctx.Err() != nil {
			return
		}
		if i == len(delays) {
			slog.Warn("Nightly log level migration failed; retrying next launch", "error", err)
			return
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(delays[i]):
		}
	}
	if migrateLocal != nil {
		if err := migrateLocal(); err != nil {
			slog.Warn("Nightly app log level migration failed; retrying next launch", "error", err)
			return
		}
	}
	if err := os.WriteFile(marker, nil, 0o600); err != nil {
		slog.Warn("Unable to record nightly log level migration", "error", err)
	}
}

func migrateLocalLogLevel() error {
	return settings.ReplaceString(settings.LogLevelKey, "info", "debug")
}
