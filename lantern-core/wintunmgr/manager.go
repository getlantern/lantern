//go:build windows

package wintunmgr

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wintun"
)

// Manager owns Wintun adapter lifecycle for a given name/pool
type Manager struct {
	AdapterName string
	PoolName    string
	// deterministic GUID for stable NLA entries
	GUID *windows.GUID
}

// New returns a new Manager with some defaults
func New(adapterName, poolName string, guid *windows.GUID) *Manager {
	if adapterName == "" {
		adapterName = "Lantern"
	}
	if poolName == "" {
		poolName = adapterName
	}
	return &Manager{
		AdapterName: adapterName,
		PoolName:    poolName,
		GUID:        guid,
	}
}

// OpenOrCreateTunAdapter opens an existing adapter or creates it if missing
func (m *Manager) OpenOrCreateTunAdapter(ctx context.Context) (*wintun.Adapter, error) {
	if v, _ := wintun.RunningVersion(); v != 0 {
		slog.Debug("Wintun running version", "version", v)
	}

	start := time.Now()
	if ad, err := wintun.OpenAdapter(m.AdapterName); err == nil {
		slog.Debug("wintun.OpenAdapter opened", "name", m.AdapterName, "elapsed_ms", sinceMs(start))
		return ad, nil
	} else {
		slog.Debug("wintun.OpenAdapter miss", "name", m.AdapterName, "err", err)
	}

	select {
	case <-ctx.Done():
		slog.Debug("OpenOrCreateTunAdapter canceled", "adapter", m.AdapterName, "err", ctx.Err())
		return nil, ctx.Err()
	default:
	}

	const maxRetries = 3
	var ad *wintun.Adapter
	var err error
	for i := 1; i <= maxRetries; i++ {
		att := time.Now()
		ad, err = wintun.CreateAdapter(m.AdapterName, m.PoolName, m.GUID)
		if err == nil {
			slog.Debug("CreateAdapter created", "name", m.AdapterName, "pool", m.PoolName, "guid", m.GUID, "attempt", i, "elapsed_ms", sinceMs(att), "total_ms", sinceMs(start))
			return ad, nil
		}
		slog.Error("wintun.CreateAdapter failed", "name", m.AdapterName, "pool", m.PoolName, "attempt", i, "err", err)
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(300 * time.Millisecond):
		}
	}
	return nil, fmt.Errorf("create Wintun adapter %q after %d attempts: %w", m.AdapterName, maxRetries, err)
}

// Open tries opening the adapter by name
func (m *Manager) Open() (*wintun.Adapter, error) {
	start := time.Now()
	ad, err := wintun.OpenAdapter(m.AdapterName)
	if err != nil {
		return nil, fmt.Errorf("open Wintun adapter %q: %w", m.AdapterName, err)
	}
	slog.Debug("wintun.OpenAdapter ok", "name", m.AdapterName, "elapsed_ms", sinceMs(start))

	return ad, nil
}

// Create forces creation (installs driver on first use)
func (m *Manager) Create() (*wintun.Adapter, error) {
	start := time.Now()
	ad, err := wintun.CreateAdapter(m.AdapterName, m.PoolName, m.GUID)
	if err != nil {
		return nil, fmt.Errorf("create Wintun adapter %q: %w", m.AdapterName, err)
	}
	slog.Debug("wintun.CreateAdapter ok", "name", m.AdapterName, "pool", m.PoolName, "elapsed_ms", sinceMs(start))

	return ad, nil
}

// UninstallDriver attempts to remove the Wintun driver
func (m *Manager) UninstallDriver() error {
	if err := wintun.Uninstall(); err != nil {
		return fmt.Errorf("wintun uninstall: %w", err)
	}
	return nil
}
