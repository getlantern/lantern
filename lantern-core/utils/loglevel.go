package utils

import (
	"log/slog"
	"os"
	"path/filepath"

	"github.com/getlantern/radiance/common/env"
	"github.com/getlantern/radiance/common/settings"
)

// logLevelMigrationMarker, in the dataDir, records that the one-time demotion
// below ran, so a trace level chosen deliberately afterwards (developer mode)
// survives restarts.
const logLevelMigrationMarker = ".log-level-v1"

// MigrateStaleTraceLogLevel demotes a persisted "trace" log level to level,
// once. Builds that shipped with DefaultLogLevel = "trace" seeded the
// persisted settings with it, and radiance's logger prefers the persisted
// value over the configured one, so without this an upgraded install keeps
// trace forever regardless of the new default. Call it after common.Init in
// the process that owns the settings store; radiance's settings-backed
// leveler picks the demotion up without rebuilding the logger.
func MigrateStaleTraceLogLevel(dataDir, level string) {
	// Debug and staging builds still run at trace, and without a dataDir
	// there is nowhere to record that the migration ran.
	if level == "trace" || dataDir == "" {
		return
	}
	// An explicit env override outranks both values and is re-persisted on
	// every launch; don't burn the marker on a run the user forced.
	if env.GetString(env.LogLevel) != "" {
		return
	}
	marker := filepath.Join(dataDir, logLevelMigrationMarker)
	if _, err := os.Stat(marker); err == nil {
		return
	}
	if settings.GetString(settings.LogLevelKey) == "trace" {
		if err := settings.Set(settings.LogLevelKey, level); err != nil {
			slog.Warn("log level migration failed, will retry next launch", "error", err)
			return
		}
		slog.Info("migrated persisted log level", "from", "trace", "to", level)
	}
	if err := os.WriteFile(marker, nil, 0o600); err != nil {
		slog.Warn("unable to write log level migration marker", "error", err)
	}
}
