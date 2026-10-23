package lanterncore

import (
	"context"
	"fmt"
	"runtime"
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
}

type splitTunnelPaths struct {
	mu          sync.Mutex
	client      splitTunnelClient
	pendingSave bool
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
	var added, removed []string
	for _, path := range filter.ProcessPath {
		normalized := processpath.Normalize(path)
		if normalized == path {
			continue
		}
		removed = append(removed, path)
		if !present[normalized] {
			added = append(added, normalized)
			present[normalized] = true
		}
	}
	// Persist replacements before removing the old spellings.
	if len(added) > 0 {
		s.pendingSave = true
		if err := s.client.AddSplitTunnelItems(ctx, vpn.SplitTunnelFilter{ProcessPath: added}); err != nil {
			return filter, fmt.Errorf("saving normalized executable paths: %w", err)
		}
	}
	if len(removed) == 0 && !s.pendingSave {
		return filter, nil
	}
	// Radiance can change memory before a failed save; an empty removal retries it.
	s.pendingSave = true
	if err := s.client.RemoveSplitTunnelItems(ctx, vpn.SplitTunnelFilter{ProcessPath: removed}); err != nil {
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
	s.pendingSave = true
	if remove {
		err = s.client.RemoveSplitTunnelItems(ctx, filter)
	} else {
		err = s.client.AddSplitTunnelItems(ctx, filter)
	}
	s.pendingSave = err != nil
	return err
}

func (lc *LanternCore) splitTunnelFilters(ctx context.Context) (vpn.SplitTunnelFilter, error) {
	ctx, cancel := context.WithTimeout(ctx, ipcStatusTimeout)
	defer cancel()
	if runtime.GOOS == "windows" {
		return lc.splitTunnel.filters(ctx)
	}
	return lc.client.SplitTunnelFilters(ctx)
}

func (lc *LanternCore) updateSplitTunnelItems(filter vpn.SplitTunnelFilter, remove bool) error {
	ctx, cancel := context.WithTimeout(lc.ctx, ipcStatusTimeout)
	defer cancel()
	if runtime.GOOS == "windows" {
		return lc.splitTunnel.update(ctx, filter, remove)
	}
	if remove {
		return lc.client.RemoveSplitTunnelItems(ctx, filter)
	}
	return lc.client.AddSplitTunnelItems(ctx, filter)
}
