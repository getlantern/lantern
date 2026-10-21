package utils

import (
	"testing"

	"github.com/getlantern/radiance/common/env"
	"github.com/getlantern/radiance/common/settings"
)

// Single sequential test: the settings store is a package-level singleton, so
// the scenarios share it and order matters.
func TestMigrateStaleTraceLogLevel(t *testing.T) {
	// Under `go test` radiance's env package serves RADIANCE_LOG_LEVEL=disable
	// as a dotenv fallback, which reads as an explicit override; an empty OS
	// env var takes precedence and neutralizes it.
	t.Setenv(env.LogLevel.String(), "")

	if err := settings.InitSettings(t.TempDir()); err != nil {
		t.Fatalf("InitSettings: %v", err)
	}
	set := func(level string) {
		t.Helper()
		if err := settings.Set(settings.LogLevelKey, level); err != nil {
			t.Fatalf("settings.Set: %v", err)
		}
	}

	// A trace-level (debug) build does not demote.
	set("trace")
	MigrateStaleTraceLogLevel("trace")
	if got := settings.GetString(settings.LogLevelKey); got != "trace" {
		t.Fatalf("debug build migrated level to %q", got)
	}

	// An env override skips the demotion.
	t.Setenv(env.LogLevel.String(), "debug")
	MigrateStaleTraceLogLevel("info")
	if got := settings.GetString(settings.LogLevelKey); got != "trace" {
		t.Fatalf("env-overridden run migrated level to %q", got)
	}
	t.Setenv(env.LogLevel.String(), "")

	// The release build demotes a persisted trace.
	MigrateStaleTraceLogLevel("info")
	if got := settings.GetString(settings.LogLevelKey); got != "info" {
		t.Fatalf("stale trace not migrated, level = %q", got)
	}

	// Trace written back later (a stale process snapshot, or developer mode
	// before a restart) is demoted again on the next call — the demotion is
	// deliberately per-launch, not once.
	set("trace")
	MigrateStaleTraceLogLevel("info")
	if got := settings.GetString(settings.LogLevelKey); got != "info" {
		t.Fatalf("re-persisted trace not demoted, level = %q", got)
	}

	// Non-trace persisted levels are left alone.
	set("warn")
	MigrateStaleTraceLogLevel("info")
	if got := settings.GetString(settings.LogLevelKey); got != "warn" {
		t.Fatalf("non-trace level rewritten to %q", got)
	}
}
