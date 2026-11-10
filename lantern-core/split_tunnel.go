package lanterncore

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"runtime"
	"slices"
	"sync"

	"github.com/getlantern/lantern/lantern-core/internal/processpath"
	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/vpn"
)

type splitTunnelClient interface {
	Settings(context.Context) (settings.Settings, error)
	SplitTunnelFilters(context.Context) (vpn.SplitTunnelFilter, error)
	AddSplitTunnelItems(context.Context, vpn.SplitTunnelFilter) error
	RemoveSplitTunnelItems(context.Context, vpn.SplitTunnelFilter) error
	SetSplitTunnelPolicy(context.Context, vpn.SplitTunnelPolicy) error
}

type splitTunnelState struct {
	Enabled bool                  `json:"enabled"`
	Policy  vpn.SplitTunnelPolicy `json:"policy"`
	Filters vpn.SplitTunnelFilter `json:"filters"`
}

// GetSplitTunnelState returns the enabled flag, policy and filters as JSON.
func (lc *LanternCore) GetSplitTunnelState() (string, error) {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	lc.splitTunnel.mu.Lock()
	defer lc.splitTunnel.mu.Unlock()
	return lc.splitTunnel.stateJSONLocked(ctx)
}

func (s *splitTunnelPaths) stateJSONLocked(ctx context.Context) (string, error) {
	config, err := s.client.Settings(ctx)
	if err != nil {
		return "", err
	}
	state := splitTunnelState{Policy: splitTunnelPolicy(config)}
	state.Enabled, _ = config[settings.SplitTunnelKey].(bool)
	if runtime.GOOS == "windows" {
		state.Filters, err = s.migrateLocked(ctx)
	} else {
		state.Filters, err = s.client.SplitTunnelFilters(ctx)
	}
	if err != nil {
		return "", err
	}
	b, err := json.Marshal(state)
	return string(b), err
}

func splitTunnelPolicy(config settings.Settings) vpn.SplitTunnelPolicy {
	policy, _ := config[settings.SplitTunnelPolicyKey].(string)
	if p := vpn.SplitTunnelPolicy(policy); p.Valid() {
		return p
	}
	return vpn.SplitTunnelPolicyExclude
}

// SwitchSplitTunnelPolicy changes the policy. A changed policy clears both
// lists first, since a bypass list means the opposite under Include only.
func (lc *LanternCore) SwitchSplitTunnelPolicy(policy string) (string, error) {
	p := vpn.SplitTunnelPolicy(policy)
	if !p.Valid() {
		return "", fmt.Errorf("invalid split-tunnel policy: %q", policy)
	}
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	lc.splitTunnel.mu.Lock()
	defer lc.splitTunnel.mu.Unlock()
	config, err := lc.splitTunnel.client.Settings(ctx)
	if err != nil {
		return "", err
	}
	if splitTunnelPolicy(config) != p {
		filter, err := lc.splitTunnel.client.SplitTunnelFilters(ctx)
		if err != nil {
			return "", err
		}
		if err := lc.splitTunnel.removeLocked(ctx, filter); err != nil {
			return "", err
		}
		if err := lc.splitTunnel.client.SetSplitTunnelPolicy(ctx, p); err != nil {
			return "", err
		}
	}
	return lc.splitTunnel.stateJSONLocked(ctx)
}

// ClearSplitTunnelApps removes all selected apps but keeps websites.
func (lc *LanternCore) ClearSplitTunnelApps() (string, error) {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	lc.splitTunnel.mu.Lock()
	defer lc.splitTunnel.mu.Unlock()
	filter, err := lc.splitTunnel.client.SplitTunnelFilters(ctx)
	if err != nil {
		return "", err
	}
	filter.Domain, filter.DomainSuffix, filter.DomainKeyword, filter.DomainRegex = nil, nil, nil, nil
	if err := lc.splitTunnel.removeLocked(ctx, filter); err != nil {
		return "", err
	}
	return lc.splitTunnel.stateJSONLocked(ctx)
}

type splitTunnelPaths struct {
	mu          sync.Mutex
	client      splitTunnelClient
	pendingSave bool
}

// removeLocked removes filter, leaving a failed save for the next read to retry.
func (s *splitTunnelPaths) removeLocked(ctx context.Context, filter vpn.SplitTunnelFilter) error {
	s.pendingSave = true
	if err := s.client.RemoveSplitTunnelItems(ctx, filter); err != nil {
		return err
	}
	s.pendingSave = false
	return nil
}

func (s *splitTunnelPaths) prepareConnect(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	config, err := s.client.Settings(ctx)
	if err != nil {
		return err
	}
	if enabled, _ := config[settings.SplitTunnelKey].(bool); !enabled {
		return nil
	}
	_, err = s.migrateLocked(ctx)
	return err
}

// prepareSplitTunnel migrates saved Windows paths. Unmigrated rules still
// match, just less completely, so a failure here doesn't block connecting.
func (lc *LanternCore) prepareSplitTunnel(ctx context.Context) {
	if runtime.GOOS != "windows" {
		return
	}
	ctx, cancel := context.WithTimeout(ctx, ipcStatusTimeout)
	defer cancel()
	if err := lc.splitTunnel.prepareConnect(ctx); err != nil {
		slog.Warn("Could not migrate split-tunnel executable paths", "error", err)
	}
}

func (s *splitTunnelPaths) filters(ctx context.Context) (vpn.SplitTunnelFilter, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.migrateLocked(ctx)
}

func (s *splitTunnelPaths) migrateLocked(ctx context.Context) (vpn.SplitTunnelFilter, error) {
	filter, err := s.client.SplitTunnelFilters(ctx)
	if err != nil {
		return filter, err
	}
	present := make(map[string]bool, len(filter.ProcessPath))
	for _, path := range filter.ProcessPath {
		present[path] = true
	}
	var added, removed vpn.SplitTunnelFilter
	var normalizedPaths []string
	for _, path := range filter.ProcessPath {
		normalized := processpath.Normalize(path)
		normalizedPaths = append(normalizedPaths, normalized)
		if normalized == path {
			continue
		}
		removed.ProcessPath = append(removed.ProcessPath, path)
		if !present[normalized] {
			added.ProcessPath = append(added.ProcessPath, normalized)
			present[normalized] = true
		}
	}
	added.ProcessPathRegex, removed.ProcessPathRegex = splitTunnelAliasChanges(normalizedPaths, filter.ProcessPathRegex)
	// Persist replacements before removing the old paths and aliases.
	if len(added.ProcessPath)+len(added.ProcessPathRegex) > 0 {
		s.pendingSave = true
		if err := s.client.AddSplitTunnelItems(ctx, added); err != nil {
			return filter, fmt.Errorf("saving executable path rules: %w", err)
		}
	}
	if len(removed.ProcessPath)+len(removed.ProcessPathRegex) == 0 && !s.pendingSave {
		return filter, nil
	}
	// Radiance can change memory before a failed save; an empty removal retries it.
	s.pendingSave = true
	if err := s.client.RemoveSplitTunnelItems(ctx, removed); err != nil {
		return filter, fmt.Errorf("saving migrated executable paths: %w", err)
	}
	s.pendingSave = false
	return s.client.SplitTunnelFilters(ctx)
}

func (s *splitTunnelPaths) update(ctx context.Context, filter vpn.SplitTunnelFilter, remove bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	current, err := s.migrateLocked(ctx)
	if err != nil {
		return err
	}
	if !remove {
		filter = withoutSaved(filter, current)
	}
	seen := make(map[string]bool)
	if !remove {
		for _, path := range current.ProcessPath {
			seen[path] = true
		}
	}
	paths := make([]string, 0, len(filter.ProcessPath))
	for _, path := range filter.ProcessPath {
		path = processpath.Normalize(path)
		if !seen[path] {
			paths = append(paths, path)
			seen[path] = true
		}
	}
	filter.ProcessPath = paths
	if remove {
		var remaining []string
		for _, path := range current.ProcessPath {
			if !seen[path] {
				remaining = append(remaining, path)
			}
		}
		_, aliases := splitTunnelAliasChanges(remaining, current.ProcessPathRegex)
		filter.ProcessPathRegex = append(filter.ProcessPathRegex, aliases...)
	} else {
		aliases, _ := splitTunnelAliasChanges(paths, current.ProcessPathRegex)
		filter.ProcessPathRegex = append(filter.ProcessPathRegex, aliases...)
	}
	s.pendingSave = true
	if remove {
		err = s.client.RemoveSplitTunnelItems(ctx, filter)
	} else {
		err = s.client.AddSplitTunnelItems(ctx, filter)
	}
	s.pendingSave = err != nil
	return err
}

// splitTunnelAliasChanges reconciles generated rules against the selected executables.
// Unrelated regex rules are left alone, even when a selected file no longer exists.
func splitTunnelAliasChanges(paths, existing []string) (added, removed []string) {
	present := make(map[string]bool, len(existing))
	for _, pattern := range existing {
		present[pattern] = true
	}
	desired := make(map[string]bool, len(paths))
	for _, path := range paths {
		pattern := processpath.AliasPattern(path)
		if pattern == "" || desired[pattern] {
			continue
		}
		desired[pattern] = true
		if !present[pattern] {
			added = append(added, pattern)
		}
	}
	for _, pattern := range existing {
		if processpath.IsAliasPattern(pattern) && !desired[pattern] {
			removed = append(removed, pattern)
		}
	}
	return added, removed
}

func (lc *LanternCore) splitTunnelFilters(ctx context.Context) (vpn.SplitTunnelFilter, error) {
	ctx, cancel := context.WithTimeout(ctx, ipcStatusTimeout)
	defer cancel()
	if runtime.GOOS == "windows" {
		return lc.splitTunnel.filters(ctx)
	}
	return lc.splitTunnel.client.SplitTunnelFilters(ctx)
}

func (lc *LanternCore) updateSplitTunnelItems(filter vpn.SplitTunnelFilter, remove bool) error {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	if runtime.GOOS == "windows" {
		return lc.splitTunnel.update(ctx, filter, remove)
	}
	lc.splitTunnel.mu.Lock()
	defer lc.splitTunnel.mu.Unlock()
	if remove {
		return lc.splitTunnel.client.RemoveSplitTunnelItems(ctx, filter)
	}
	saved, err := lc.splitTunnel.client.SplitTunnelFilters(ctx)
	if err != nil {
		return err
	}
	return lc.splitTunnel.client.AddSplitTunnelItems(ctx, withoutSaved(filter, saved))
}

// withoutSaved drops selectors that are already saved, since radiance appends duplicates.
func withoutSaved(filter, saved vpn.SplitTunnelFilter) vpn.SplitTunnelFilter {
	for _, f := range []struct {
		items *[]string
		saved []string
	}{
		{&filter.Domain, saved.Domain},
		{&filter.DomainSuffix, saved.DomainSuffix},
		{&filter.DomainKeyword, saved.DomainKeyword},
		{&filter.DomainRegex, saved.DomainRegex},
		{&filter.ProcessName, saved.ProcessName},
		{&filter.ProcessPath, saved.ProcessPath},
		{&filter.ProcessPathRegex, saved.ProcessPathRegex},
		{&filter.PackageName, saved.PackageName},
	} {
		*f.items = slices.DeleteFunc(slices.Clone(*f.items), func(item string) bool {
			return slices.Contains(f.saved, item)
		})
	}
	return filter
}
