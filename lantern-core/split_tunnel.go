package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"runtime"
	"sync"

	"github.com/getlantern/lantern/lantern-core/internal/processpath"
	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/ipc"
	"github.com/getlantern/radiance/vpn"
)

type splitTunnelClient interface {
	Settings(context.Context) (settings.Settings, error)
	SplitTunnelFilters(context.Context) (vpn.SplitTunnelFilter, error)
	AddSplitTunnelItems(context.Context, vpn.SplitTunnelFilter) error
	RemoveSplitTunnelItems(context.Context, vpn.SplitTunnelFilter) error
}

type splitTunnelStateClient interface {
	SplitTunnelState(context.Context) (vpn.SplitTunnelState, error)
	SwitchSplitTunnelPolicy(context.Context, vpn.SplitTunnelPolicy) (vpn.SplitTunnelState, error)
	ClearSplitTunnelApps(context.Context) (vpn.SplitTunnelState, error)
}

type splitTunnelSnapshot struct {
	vpn.SplitTunnelState
	Supported bool `json:"supported"`
}

func unsupportedSplitTunnelAPI(err error) bool {
	var response *ipc.Error
	return errors.As(err, &response) && (response.Status == http.StatusNotFound || response.Status == http.StatusMethodNotAllowed)
}

// GetSplitTunnelState returns the saved snapshot, marking legacy daemon projections unsupported.
func (lc *LanternCore) GetSplitTunnelState() (string, error) {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	lc.splitTunnel.mu.Lock()
	defer lc.splitTunnel.mu.Unlock()
	if runtime.GOOS == "windows" {
		if _, err := lc.splitTunnel.migrateLocked(ctx); err != nil {
			return "", err
		}
	}
	return lc.splitTunnel.stateJSONLocked(ctx)
}

func (s *splitTunnelPaths) stateJSONLocked(ctx context.Context) (string, error) {
	state, err := s.client.(splitTunnelStateClient).SplitTunnelState(ctx)
	supported := err == nil
	if unsupportedSplitTunnelAPI(err) {
		config, configErr := s.client.Settings(ctx)
		if configErr != nil {
			return "", configErr
		}
		state.Enabled, _ = config[settings.SplitTunnelKey].(bool)
		policy, _ := config[settings.SplitTunnelPolicyKey].(string)
		state.Policy = vpn.SplitTunnelPolicy(policy)
		if !state.Policy.Valid() {
			state.Policy = vpn.SplitTunnelPolicyExclude
		}
		state.Filters, err = s.client.SplitTunnelFilters(ctx)
	}
	if err != nil {
		return "", err
	}
	encoded, err := json.Marshal(splitTunnelSnapshot{SplitTunnelState: state, Supported: supported})
	return string(encoded), err
}

// SwitchSplitTunnelPolicy clears both lists only when the daemon changes policy.
func (lc *LanternCore) SwitchSplitTunnelPolicy(policy string) (string, error) {
	p := vpn.SplitTunnelPolicy(policy)
	if !p.Valid() {
		return "", fmt.Errorf("invalid split-tunnel policy: %q", policy)
	}
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	lc.splitTunnel.mu.Lock()
	defer lc.splitTunnel.mu.Unlock()
	state, err := lc.splitTunnel.client.(splitTunnelStateClient).SwitchSplitTunnelPolicy(ctx, p)
	if err != nil {
		return "", err
	}
	encoded, err := json.Marshal(splitTunnelSnapshot{SplitTunnelState: state, Supported: true})
	return string(encoded), err
}

// ClearSplitTunnelApps removes every stored app selector and preserves website selections.
func (lc *LanternCore) ClearSplitTunnelApps() (string, error) {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStateChangeTimeout)
	defer cancel()
	lc.splitTunnel.mu.Lock()
	defer lc.splitTunnel.mu.Unlock()
	state, err := lc.splitTunnel.client.(splitTunnelStateClient).ClearSplitTunnelApps(ctx)
	if unsupportedSplitTunnelAPI(err) {
		filter, err := lc.splitTunnel.client.SplitTunnelFilters(ctx)
		if err != nil {
			return "", err
		}
		filter.Domain, filter.DomainSuffix, filter.DomainKeyword, filter.DomainRegex = nil, nil, nil, nil
		if err := lc.splitTunnel.client.RemoveSplitTunnelItems(ctx, filter); err != nil {
			return "", err
		}
		return lc.splitTunnel.stateJSONLocked(ctx)
	}
	if err != nil {
		return "", err
	}
	encoded, err := json.Marshal(splitTunnelSnapshot{SplitTunnelState: state, Supported: true})
	return string(encoded), err
}

type splitTunnelPaths struct {
	mu     sync.Mutex
	client splitTunnelClient
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

func (lc *LanternCore) prepareSplitTunnel(ctx context.Context) error {
	if runtime.GOOS != "windows" {
		return nil
	}
	ctx, cancel := context.WithTimeout(ctx, ipcStatusTimeout)
	defer cancel()
	return lc.splitTunnel.prepareConnect(ctx)
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
	if len(added.ProcessPath)+len(added.ProcessPathRegex)+len(removed.ProcessPath)+len(removed.ProcessPathRegex) == 0 {
		return filter, nil
	}
	// Persist replacements before removing the old paths and aliases.
	if len(added.ProcessPath)+len(added.ProcessPathRegex) > 0 {
		if err := s.client.AddSplitTunnelItems(ctx, added); err != nil {
			return filter, fmt.Errorf("saving executable path rules: %w", err)
		}
	}
	if len(removed.ProcessPath)+len(removed.ProcessPathRegex) > 0 {
		if err := s.client.RemoveSplitTunnelItems(ctx, removed); err != nil {
			return filter, fmt.Errorf("saving migrated executable paths: %w", err)
		}
	}
	return s.client.SplitTunnelFilters(ctx)
}

func (s *splitTunnelPaths) update(ctx context.Context, filter vpn.SplitTunnelFilter, remove bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	current, err := s.migrateLocked(ctx)
	if err != nil {
		return err
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
	if remove {
		err = s.client.RemoveSplitTunnelItems(ctx, filter)
	} else {
		err = s.client.AddSplitTunnelItems(ctx, filter)
	}
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
	return lc.splitTunnel.client.AddSplitTunnelItems(ctx, filter)
}
