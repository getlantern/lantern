package utils

import (
	"os"
	"path/filepath"
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

	dataDir := t.TempDir()
	if err := settings.InitSettings(dataDir); err != nil {
		t.Fatalf("InitSettings: %v", err)
	}
	set := func(level string) {
		t.Helper()
		if err := settings.Set(settings.LogLevelKey, level); err != nil {
			t.Fatalf("settings.Set: %v", err)
		}
	}
	marker := filepath.Join(dataDir, logLevelMigrationMarker)

	// A trace-level (debug) build neither migrates nor burns the marker.
	set("trace")
	MigrateStaleTraceLogLevel(dataDir, "trace")
	if got := settings.GetString(settings.LogLevelKey); got != "trace" {
		t.Fatalf("debug build migrated level to %q", got)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("debug build wrote the migration marker")
	}

	// An env override skips the migration without burning the marker.
	t.Setenv(env.LogLevel.String(), "debug")
	MigrateStaleTraceLogLevel(dataDir, "info")
	if got := settings.GetString(settings.LogLevelKey); got != "trace" {
		t.Fatalf("env-overridden run migrated level to %q", got)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("env-overridden run wrote the migration marker")
	}
	t.Setenv(env.LogLevel.String(), "")

	// The release build demotes the stale trace once.
	MigrateStaleTraceLogLevel(dataDir, "info")
	if got := settings.GetString(settings.LogLevelKey); got != "info" {
		t.Fatalf("stale trace not migrated, level = %q", got)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("migration marker not written: %v", err)
	}

	// A deliberate trace set after the migration sticks.
	set("trace")
	MigrateStaleTraceLogLevel(dataDir, "info")
	if got := settings.GetString(settings.LogLevelKey); got != "trace" {
		t.Fatalf("deliberate trace was demoted to %q", got)
	}

	// Non-trace persisted levels are left alone (fresh marker-less dir).
	set("warn")
	otherDir := t.TempDir()
	MigrateStaleTraceLogLevel(otherDir, "info")
	if got := settings.GetString(settings.LogLevelKey); got != "warn" {
		t.Fatalf("non-trace level rewritten to %q", got)
	}
}
