package lanterncore

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/getlantern/radiance/common/settings"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fakeSettingsClient struct {
	values      settings.Settings
	settingsErr []error
	patchErr    []error
	patches     []settings.Settings
}

func (f *fakeSettingsClient) Settings(context.Context) (settings.Settings, error) {
	if len(f.settingsErr) > 0 {
		err := f.settingsErr[0]
		f.settingsErr = f.settingsErr[1:]
		return nil, err
	}
	s := settings.Settings{}
	for k, v := range f.values {
		s[k] = v
	}
	return s, nil
}

func (f *fakeSettingsClient) PatchSettings(_ context.Context, updates settings.Settings) (settings.Settings, error) {
	f.patches = append(f.patches, updates)
	if len(f.patchErr) > 0 {
		err := f.patchErr[0]
		f.patchErr = f.patchErr[1:]
		if err != nil {
			return nil, err
		}
	}
	if f.values == nil {
		f.values = settings.Settings{}
	}
	for k, v := range updates {
		f.values[k] = v
	}
	return updates, nil
}

func TestDisableSigNozLogUploadOffNightly(t *testing.T) {
	ctx := context.Background()
	on := func() settings.Settings { return settings.Settings{settings.SendLogsToSigNozKey: true} }

	t.Run("turns it off in every build but nightly", func(t *testing.T) {
		for _, buildType := range []string{"", "production", "beta", "abi-candidate"} {
			withBuildType(t, buildType)
			client := &fakeSettingsClient{values: on()}

			disableSigNozLogUploadOffNightly(ctx, client, nil)
			assert.Equal(t, false, client.values[settings.SendLogsToSigNozKey], "build type %q", buildType)
			assert.Equal(t, []settings.Settings{{settings.SendLogsToSigNozKey: false}}, client.patches, "build type %q", buildType)
		}
	})

	t.Run("leaves nightly alone", func(t *testing.T) {
		withBuildType(t, "nightly")
		client := &fakeSettingsClient{values: on(), settingsErr: []error{errors.New("must not be read")}}

		disableSigNozLogUploadOffNightly(ctx, client, nil)
		assert.Equal(t, true, client.values[settings.SendLogsToSigNozKey])
		assert.Empty(t, client.patches)
		assert.Len(t, client.settingsErr, 1, "nightly never reads settings")
	})

	t.Run("does not patch when it is already off or unset", func(t *testing.T) {
		withBuildType(t, "production")
		for _, values := range []settings.Settings{
			nil,
			{settings.SendLogsToSigNozKey: false},
			{settings.SendLogsToSigNozKey: "true"},
		} {
			client := &fakeSettingsClient{values: values}

			disableSigNozLogUploadOffNightly(ctx, client, nil)
			assert.Empty(t, client.patches, "settings %v", values)
		}
	})

	t.Run("retries until the backend answers", func(t *testing.T) {
		withBuildType(t, "")
		down := errors.New("backend not running")
		client := &fakeSettingsClient{values: on(), settingsErr: []error{down, down}}

		disableSigNozLogUploadOffNightly(ctx, client, make([]time.Duration, 2))
		assert.Equal(t, false, client.values[settings.SendLogsToSigNozKey])
	})

	t.Run("retries a failed patch", func(t *testing.T) {
		withBuildType(t, "production")
		client := &fakeSettingsClient{values: on(), patchErr: []error{errors.New("save failed")}}

		disableSigNozLogUploadOffNightly(ctx, client, make([]time.Duration, 1))
		assert.Len(t, client.patches, 2)
		assert.Equal(t, false, client.values[settings.SendLogsToSigNozKey])
	})

	t.Run("gives up after the last retry", func(t *testing.T) {
		withBuildType(t, "production")
		down := errors.New("backend not running")
		client := &fakeSettingsClient{values: on(), settingsErr: []error{down, down, down}}

		disableSigNozLogUploadOffNightly(ctx, client, make([]time.Duration, 1))
		assert.Equal(t, true, client.values[settings.SendLogsToSigNozKey])
		assert.Len(t, client.settingsErr, 1, "one attempt plus one retry")
	})

	t.Run("stops when the context is cancelled", func(t *testing.T) {
		withBuildType(t, "production")
		cctx, cancel := context.WithCancel(ctx)
		cancel()
		down := errors.New("backend not running")
		client := &fakeSettingsClient{values: on(), settingsErr: []error{down, down}}

		disableSigNozLogUploadOffNightly(cctx, client, []time.Duration{time.Hour})
		assert.Len(t, client.settingsErr, 1)
	})
}

func TestDisableSigNozLogUploadBeforeStart(t *testing.T) {
	require.NoError(t, settings.InitSettings(t.TempDir()))
	t.Cleanup(settings.Reset)

	var patches []settings.Settings
	patch := func(s settings.Settings) error {
		patches = append(patches, s)
		return settings.Patch(s)
	}

	t.Run("turns it off before start outside nightly", func(t *testing.T) {
		for _, buildType := range []string{"", "production", "beta"} {
			withBuildType(t, buildType)
			patches = nil
			require.NoError(t, settings.Set(settings.SendLogsToSigNozKey, true))

			require.NoError(t, DisableSigNozLogUploadBeforeStart(patch))
			assert.False(t, settings.GetBool(settings.SendLogsToSigNozKey), "build type %q", buildType)
			assert.Len(t, patches, 1, "build type %q", buildType)
		}
	})

	t.Run("leaves nightly on", func(t *testing.T) {
		withBuildType(t, "nightly")
		patches = nil
		require.NoError(t, settings.Set(settings.SendLogsToSigNozKey, true))

		require.NoError(t, DisableSigNozLogUploadBeforeStart(patch))
		assert.True(t, settings.GetBool(settings.SendLogsToSigNozKey))
		assert.Empty(t, patches)
	})

	t.Run("does not patch when already off", func(t *testing.T) {
		withBuildType(t, "production")
		patches = nil
		require.NoError(t, settings.Set(settings.SendLogsToSigNozKey, false))

		require.NoError(t, DisableSigNozLogUploadBeforeStart(patch))
		assert.Empty(t, patches)
	})

	t.Run("returns a failed patch", func(t *testing.T) {
		withBuildType(t, "production")
		require.NoError(t, settings.Set(settings.SendLogsToSigNozKey, true))
		failed := errors.New("save failed")

		err := DisableSigNozLogUploadBeforeStart(func(settings.Settings) error { return failed })
		assert.ErrorIs(t, err, failed)
	})
}
