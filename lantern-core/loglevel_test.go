package lanterncore

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/getlantern/radiance/common/settings"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fakeLogLevelSettings struct {
	level       any
	settingsErr []error
	patches     []settings.Settings
}

func (f *fakeLogLevelSettings) Settings(context.Context) (settings.Settings, error) {
	if len(f.settingsErr) > 0 {
		err := f.settingsErr[0]
		f.settingsErr = f.settingsErr[1:]
		return nil, err
	}
	s := settings.Settings{}
	if f.level != nil {
		s[settings.LogLevelKey] = f.level
	}
	return s, nil
}

func (f *fakeLogLevelSettings) PatchSettings(_ context.Context, updates settings.Settings) (settings.Settings, error) {
	f.patches = append(f.patches, updates)
	f.level = updates[settings.LogLevelKey]
	return updates, nil
}

func withBuildType(t *testing.T, buildType string) {
	t.Helper()
	prev := BuildType
	BuildType = buildType
	t.Cleanup(func() { BuildType = prev })
}

func TestDefaultLogLevel(t *testing.T) {
	for buildType, want := range map[string]string{
		"":           "info",
		"production": "info",
		"beta":       "info",
		"nightly":    "debug",
	} {
		withBuildType(t, buildType)
		assert.Equal(t, want, DefaultLogLevel(), "build type %q", buildType)
	}
}

func TestMigrateNightlyLogLevel(t *testing.T) {
	ctx := context.Background()

	t.Run("raises info to debug once on nightly", func(t *testing.T) {
		withBuildType(t, "nightly")
		dir := t.TempDir()
		client := &fakeLogLevelSettings{level: "info"}

		migrateNightlyLogLevel(ctx, client, dir, nil)
		assert.Equal(t, "debug", client.level)
		assert.FileExists(t, filepath.Join(dir, nightlyLogLevelMarker))

		// A tester who then picks info keeps it.
		client.level = "info"
		migrateNightlyLogLevel(ctx, client, dir, nil)
		assert.Equal(t, "info", client.level)
		assert.Len(t, client.patches, 1)
	})

	t.Run("leaves other levels alone but records the marker", func(t *testing.T) {
		withBuildType(t, "nightly")
		dir := t.TempDir()
		client := &fakeLogLevelSettings{level: "warn"}

		migrateNightlyLogLevel(ctx, client, dir, nil)
		assert.Equal(t, "warn", client.level)
		assert.Empty(t, client.patches)
		assert.FileExists(t, filepath.Join(dir, nightlyLogLevelMarker))
	})

	t.Run("never touches release builds", func(t *testing.T) {
		for _, buildType := range []string{"", "production", "beta"} {
			withBuildType(t, buildType)
			dir := t.TempDir()
			client := &fakeLogLevelSettings{level: "info"}

			migrateNightlyLogLevel(ctx, client, dir, nil)
			assert.Equal(t, "info", client.level)
			assert.Empty(t, client.patches)
			assert.NoFileExists(t, filepath.Join(dir, nightlyLogLevelMarker))
		}
	})

	t.Run("retries until the backend answers", func(t *testing.T) {
		withBuildType(t, "nightly")
		dir := t.TempDir()
		down := errors.New("backend not running")
		client := &fakeLogLevelSettings{level: "info", settingsErr: []error{down, down}}

		migrateNightlyLogLevel(ctx, client, dir, make([]time.Duration, 2))
		assert.Equal(t, "debug", client.level)
		assert.FileExists(t, filepath.Join(dir, nightlyLogLevelMarker))
	})

	t.Run("skips the marker when every attempt fails", func(t *testing.T) {
		withBuildType(t, "nightly")
		dir := t.TempDir()
		down := errors.New("backend not running")
		client := &fakeLogLevelSettings{level: "info", settingsErr: []error{down, down}}

		migrateNightlyLogLevel(ctx, client, dir, make([]time.Duration, 1))
		assert.Equal(t, "info", client.level)
		_, err := os.Stat(filepath.Join(dir, nightlyLogLevelMarker))
		require.ErrorIs(t, err, os.ErrNotExist)
	})
}
