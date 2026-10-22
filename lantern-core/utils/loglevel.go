package utils

import (
	"log/slog"

	"github.com/getlantern/radiance/common/env"
	"github.com/getlantern/radiance/common/settings"
)

// MigrateStaleTraceLogLevel demotes a persisted "trace" log level to level.
// Builds that shipped with DefaultLogLevel = "trace" seeded the persisted
// settings with it, and radiance's logger prefers the persisted value over
// the configured one, so without this an upgraded install keeps trace forever
// regardless of the new default. Call it after the settings store is
// initialized in every process that writes it; radiance's settings-backed
// leveler picks the demotion up without rebuilding the logger.
//
// The demotion is unconditional on every launch rather than once-per-install:
// settings saves rewrite the whole in-memory snapshot, so on darwin/ios a
// process still holding a pre-demotion snapshot (app vs. tunnel extension
// share the store) can write trace back at any time, and only a repeated
// demotion recovers. The cost is that a trace level set through developer
// mode on a release build lasts until the next restart; a persistent trace
// needs a debug build or the RADIANCE_LOG_LEVEL env override.
func MigrateStaleTraceLogLevel(level string) {
	// Debug and staging builds still run at trace.
	if level == "trace" {
		return
	}
	// An explicit env override outranks both values and is re-persisted on
	// every launch; respect it.
	if env.GetString(env.LogLevel) != "" {
		return
	}
	if settings.GetString(settings.LogLevelKey) != "trace" {
		return
	}
	if err := settings.Set(settings.LogLevelKey, level); err != nil {
		slog.Warn("log level migration failed, will retry next launch", "error", err)
		return
	}
	slog.Info("migrated persisted log level", "from", "trace", "to", level)
}
