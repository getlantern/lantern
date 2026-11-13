//go:build !novpn

package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
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
	return &LanternCore{ctx: t.Context(), splitTunnel: splitTunnelPaths{client: c, dir: t.TempDir()}}, c
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

func TestSplitTunnelSwitchKeepsListsPerPolicy(t *testing.T) {
	lc, c := splitStateCore(t)
	switchTo := func(policy string) vpn.SplitTunnelFilter {
		t.Helper()
		payload, err := lc.SwitchSplitTunnelPolicy(policy)
		require.NoError(t, err)
		state := decodeSplitState(t, payload)
		assert.Equal(t, vpn.SplitTunnelPolicy(policy), state.Policy)
		return state.Filters
	}
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{DomainSuffix: []string{"site.test"}, ProcessName: []string{"app"}}))

	// The bypass lists never go live under Include only.
	filters := switchTo("include")
	assert.Empty(t, filters.DomainSuffix)
	assert.Empty(t, filters.ProcessName)

	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{DomainSuffix: []string{"only.test"}, PackageName: []string{"some.app"}}))
	// Selecting the current policy keeps the lists.
	assert.Equal(t, []string{"only.test"}, switchTo("include").DomainSuffix)

	filters = switchTo("exclude")
	assert.Equal(t, []string{"site.test"}, filters.DomainSuffix)
	assert.Equal(t, []string{"app"}, filters.ProcessName)
	assert.Empty(t, filters.PackageName)

	filters = switchTo("include")
	assert.Equal(t, []string{"only.test"}, filters.DomainSuffix)
	assert.Equal(t, []string{"some.app"}, filters.PackageName)
	assert.Empty(t, filters.ProcessName)

	payload, err := lc.ClearSplitTunnelApps()
	require.NoError(t, err)
	assert.Equal(t, []string{"only.test"}, decodeSplitState(t, payload).Filters.DomainSuffix)
	assert.Empty(t, c.handler.Filters().PackageName)

	_, err = lc.SwitchSplitTunnelPolicy("bogus")
	assert.Error(t, err)
}

func TestSplitTunnelSwitchFailureKeepsCurrentLists(t *testing.T) {
	lc, c := splitStateCore(t)
	require.NoError(t, c.handler.AddItems(vpn.SplitTunnelFilter{DomainSuffix: []string{"site.test"}}))

	c.policyErr = errors.New("policy write failed")
	_, err := lc.SwitchSplitTunnelPolicy("include")
	assert.ErrorIs(t, err, c.policyErr)
	assert.Equal(t, vpn.SplitTunnelPolicyExclude, c.handler.Policy())
	assert.Equal(t, []string{"site.test"}, c.handler.Filters().DomainSuffix)
	c.policyErr = nil

	// Nothing changes when the lists can't be put away.
	dir := lc.splitTunnel.dir
	lc.splitTunnel.dir = filepath.Join(dir, splitTunnelListsFile, "blocked")
	require.NoError(t, os.WriteFile(filepath.Join(dir, splitTunnelListsFile), []byte("not json"), 0o600))
	_, err = lc.SwitchSplitTunnelPolicy("include")
	assert.Error(t, err)
	assert.Equal(t, vpn.SplitTunnelPolicyExclude, c.handler.Policy())
	assert.Equal(t, []string{"site.test"}, c.handler.Filters().DomainSuffix)

	// An unreadable file only loses the other policy's lists.
	lc.splitTunnel.dir = dir
	payload, err := lc.SwitchSplitTunnelPolicy("include")
	require.NoError(t, err)
	assert.Empty(t, decodeSplitState(t, payload).Filters.DomainSuffix)
	payload, err = lc.SwitchSplitTunnelPolicy("exclude")
	require.NoError(t, err)
	assert.Equal(t, []string{"site.test"}, decodeSplitState(t, payload).Filters.DomainSuffix)
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
