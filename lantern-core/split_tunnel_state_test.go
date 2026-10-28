//go:build !novpn

package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"testing"

	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/ipc"
	"github.com/getlantern/radiance/vpn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type splitStateTestClient struct {
	*splitTunnelTestClient
	stateErr, filtersErr, settingsErr, mutationErr error
}

func (c *splitStateTestClient) SplitTunnelState(context.Context) (vpn.SplitTunnelState, error) {
	return c.handler.State(), c.stateErr
}

func (c *splitStateTestClient) Settings(ctx context.Context) (settings.Settings, error) {
	if c.settingsErr != nil {
		return nil, c.settingsErr
	}
	return settings.Settings{settings.SplitTunnelKey: c.handler.IsEnabled(), settings.SplitTunnelPolicyKey: string(c.handler.Policy())}, nil
}

func (c *splitStateTestClient) SplitTunnelFilters(ctx context.Context) (vpn.SplitTunnelFilter, error) {
	if c.filtersErr != nil {
		return vpn.SplitTunnelFilter{}, c.filtersErr
	}
	return c.splitTunnelTestClient.SplitTunnelFilters(ctx)
}

func (c *splitStateTestClient) SwitchSplitTunnelPolicy(_ context.Context, policy vpn.SplitTunnelPolicy) (vpn.SplitTunnelState, error) {
	if c.mutationErr != nil {
		return vpn.SplitTunnelState{}, c.mutationErr
	}
	err := c.handler.SwitchPolicy(policy)
	return c.handler.State(), err
}

func (c *splitStateTestClient) ClearSplitTunnelApps(context.Context) (vpn.SplitTunnelState, error) {
	if c.mutationErr != nil {
		return vpn.SplitTunnelState{}, c.mutationErr
	}
	err := c.handler.ClearApps()
	return c.handler.State(), err
}

func splitStateCore(t *testing.T) (*LanternCore, *splitStateTestClient) {
	t.Helper()
	c := &splitStateTestClient{splitTunnelTestClient: newSplitTunnelTestClient(t, t.TempDir())}
	return &LanternCore{ctx: t.Context(), splitTunnel: splitTunnelPaths{client: c}}, c
}

func decodeSplitState(t *testing.T, payload string) splitTunnelSnapshot {
	t.Helper()
	var state splitTunnelSnapshot
	require.NoError(t, json.Unmarshal([]byte(payload), &state))
	return state
}

func TestSplitTunnelStateCapabilitiesAndFailures(t *testing.T) {
	lc, c := splitStateCore(t)
	require.NoError(t, c.handler.SetEnabled(true))
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{ProcessPath: []string{"missing.exe"}}))
	stateJSON, err := lc.GetSplitTunnelState()
	require.NoError(t, err)
	state := decodeSplitState(t, stateJSON)
	assert.True(t, state.Supported)
	assert.Equal(t, c.handler.State(), state.SplitTunnelState)
	for _, status := range []int{http.StatusNotFound, http.StatusMethodNotAllowed} {
		c.stateErr = &ipc.Error{Status: status}
		stateJSON, err = lc.GetSplitTunnelState()
		require.NoError(t, err)
		state = decodeSplitState(t, stateJSON)
		assert.False(t, state.Supported)
		assert.Equal(t, c.handler.State(), state.SplitTunnelState)
	}
	c.settingsErr = errors.New("settings unavailable")
	_, err = lc.GetSplitTunnelState()
	assert.ErrorIs(t, err, c.settingsErr)
	c.settingsErr = nil
	c.filtersErr = errors.New("filters unavailable")
	_, err = lc.GetSplitTunnelState()
	assert.ErrorIs(t, err, c.filtersErr)
	payload, err := lc.GetSplitTunnelItems()
	assert.ErrorIs(t, err, c.filtersErr)
	assert.Empty(t, payload)
	c.filtersErr = nil
	c.stateErr = &ipc.Error{Status: http.StatusInternalServerError, Message: "read failed"}
	_, err = lc.GetSplitTunnelState()
	assert.ErrorIs(t, err, c.stateErr)
}

func TestSplitTunnelSwitchAndClearReturnAuthoritativeState(t *testing.T) {
	lc, c := splitStateCore(t)
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{DomainSuffix: []string{"site.test"}, ProcessName: []string{"app"}}))
	payload, err := lc.SwitchSplitTunnelPolicy("include")
	require.NoError(t, err)
	state := decodeSplitState(t, payload)
	assert.Empty(t, state.Filters.DomainSuffix)
	assert.Empty(t, state.Filters.ProcessName)
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{
		DomainSuffix: []string{"site.test"}, ProcessName: []string{"hidden"}, ProcessPath: []string{"gone.exe"},
		ProcessPathRegex: []string{"missing.*"}, PackageName: []string{"uninstalled.app"},
	}))
	_, err = lc.SwitchSplitTunnelPolicy("include")
	require.NoError(t, err)
	assert.NotEmpty(t, c.handler.Filters().ProcessPath)
	for _, legacy := range []bool{false, true} {
		if legacy {
			require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{PackageName: []string{"uninstalled.app"}}))
			c.mutationErr = &ipc.Error{Status: http.StatusNotFound}
			c.stateErr = c.mutationErr
		}
		payload, err = lc.ClearSplitTunnelApps()
		require.NoError(t, err)
		state = decodeSplitState(t, payload)
		assert.Equal(t, vpn.SplitTunnelFilter{DomainSuffix: []string{"site.test"}}, state.Filters)
		assert.Equal(t, !legacy, state.Supported)
	}
	c.mutationErr = errors.New("saved but apply failed")
	_, err = lc.SwitchSplitTunnelPolicy("exclude")
	assert.ErrorIs(t, err, c.mutationErr)
	_, err = lc.ClearSplitTunnelApps()
	assert.ErrorIs(t, err, c.mutationErr)
}

func TestSplitTunnelWebsiteWritesAreValidatedAndDeduplicated(t *testing.T) {
	lc, c := splitStateCore(t)
	for _, invalid := range []string{"*", "*ir", "127.0.0.1", "foo..com"} {
		require.Error(t, lc.AddSplitTunnelItem(vpn.TypeDomainSuffix, invalid))
	}
	assert.Empty(t, c.handler.Filters().DomainSuffix)
	require.NoError(t, lc.AddSplitTunnelItem(vpn.TypeDomainSuffix, "*.BÜCHER.de."))
	require.NoError(t, lc.AddSplitTunnelItem(vpn.TypeDomainSuffix, ".xn--bcher-kva.de"))
	assert.Equal(t, []string{".xn--bcher-kva.de"}, c.handler.Filters().DomainSuffix)
}
