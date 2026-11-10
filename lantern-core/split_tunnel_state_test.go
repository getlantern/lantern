//go:build !novpn

package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/vpn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func (c *splitTunnelTestClient) SetSplitTunnelPolicy(ctx context.Context, policy vpn.SplitTunnelPolicy) error {
	if err := c.record(ctx, "policy"); err != nil {
		return err
	}
	return c.handler.SetPolicy(policy)
}

type splitStateTestClient struct {
	*splitTunnelTestClient
	filtersErr, settingsErr, policyErr error
}

func (c *splitStateTestClient) Settings(ctx context.Context) (settings.Settings, error) {
	if c.settingsErr != nil {
		return nil, c.settingsErr
	}
	return settings.Settings{
		settings.SplitTunnelKey:       c.handler.IsEnabled(),
		settings.SplitTunnelPolicyKey: string(c.handler.Policy()),
	}, nil
}

func (c *splitStateTestClient) SplitTunnelFilters(ctx context.Context) (vpn.SplitTunnelFilter, error) {
	if c.filtersErr != nil {
		return vpn.SplitTunnelFilter{}, c.filtersErr
	}
	return c.splitTunnelTestClient.SplitTunnelFilters(ctx)
}

func (c *splitStateTestClient) SetSplitTunnelPolicy(ctx context.Context, policy vpn.SplitTunnelPolicy) error {
	if c.policyErr != nil {
		return c.policyErr
	}
	return c.splitTunnelTestClient.SetSplitTunnelPolicy(ctx, policy)
}

func splitStateCore(t *testing.T) (*LanternCore, *splitStateTestClient) {
	t.Helper()
	c := &splitStateTestClient{splitTunnelTestClient: newSplitTunnelTestClient(t, t.TempDir())}
	return &LanternCore{ctx: t.Context(), splitTunnel: splitTunnelPaths{client: c}}, c
}

func decodeSplitState(t *testing.T, payload string) splitTunnelState {
	t.Helper()
	var state splitTunnelState
	require.NoError(t, json.Unmarshal([]byte(payload), &state))
	return state
}

func TestSplitTunnelStateReadsSettingsAndFilters(t *testing.T) {
	lc, c := splitStateCore(t)
	require.NoError(t, c.handler.SetEnabled(true))
	require.NoError(t, c.handler.SetPolicy(vpn.SplitTunnelPolicyInclude))
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{DomainSuffix: []string{"site.test"}}))
	stateJSON, err := lc.GetSplitTunnelState()
	require.NoError(t, err)
	assert.Equal(t, splitTunnelState{
		Enabled: true,
		Policy:  vpn.SplitTunnelPolicyInclude,
		Filters: c.handler.Filters(),
	}, decodeSplitState(t, stateJSON))

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
}

func TestSplitTunnelSwitchClearsListsAndClearKeepsWebsites(t *testing.T) {
	lc, c := splitStateCore(t)
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{DomainSuffix: []string{"site.test"}, ProcessName: []string{"app"}}))
	payload, err := lc.SwitchSplitTunnelPolicy("include")
	require.NoError(t, err)
	state := decodeSplitState(t, payload)
	assert.Equal(t, vpn.SplitTunnelPolicyInclude, state.Policy)
	assert.Empty(t, state.Filters.DomainSuffix)
	assert.Empty(t, state.Filters.ProcessName)

	// Selecting the current policy keeps the lists.
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{
		DomainSuffix: []string{"site.test"}, ProcessName: []string{"app"}, PackageName: []string{"some.app"},
	}))
	_, err = lc.SwitchSplitTunnelPolicy("include")
	require.NoError(t, err)
	assert.NotEmpty(t, c.handler.Filters().ProcessName)

	payload, err = lc.ClearSplitTunnelApps()
	require.NoError(t, err)
	assert.Equal(t, []string{"site.test"}, decodeSplitState(t, payload).Filters.DomainSuffix)
	assert.Empty(t, c.handler.Filters().ProcessName)
	assert.Empty(t, c.handler.Filters().PackageName)

	_, err = lc.SwitchSplitTunnelPolicy("bogus")
	assert.Error(t, err)
	c.policyErr = errors.New("policy write failed")
	_, err = lc.SwitchSplitTunnelPolicy("exclude")
	assert.ErrorIs(t, err, c.policyErr)
	assert.Equal(t, vpn.SplitTunnelPolicyInclude, c.handler.Policy())
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
	require.NoError(t, lc.RemoveSplitTunnelItem(vpn.TypeDomainSuffix, "*.BÜCHER.de"))
	assert.Empty(t, c.handler.Filters().DomainSuffix)

	// A rule saved before normalization is removed by its saved value.
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{DomainSuffix: []string{"*.Legacy.com"}}))
	require.NoError(t, lc.RemoveSplitTunnelItem(vpn.TypeDomainSuffix, "*.Legacy.com"))
	assert.Empty(t, c.handler.Filters().DomainSuffix)
}
