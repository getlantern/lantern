//go:build windows

package wintunmgr

import (
	"context"
	"fmt"

	"github.com/getlantern/golog"
	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wintun"
)

var (
	log = golog.LoggerFor("lantern-core.wintunmgr")
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
		log.Debugf("Wintun running version: %d", v)
	}

	if ad, err := wintun.OpenAdapter(m.AdapterName); err == nil {
		log.Debugf("Opened existing Wintun adapter %q", m.AdapterName)
		return ad, nil
	}

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	default:
	}

	// installs the driver on first use
	ad, err := wintun.CreateAdapter(m.AdapterName, m.PoolName, m.GUID)
	if err != nil {
		return nil, fmt.Errorf("create Wintun adapter %q: %w", m.AdapterName, err)
	}
	log.Debugf("Created Wintun adapter %q (pool=%q)", m.AdapterName, m.PoolName)
	return ad, nil
}

// Open tries opening the adapter by name
func (m *Manager) Open() (*wintun.Adapter, error) {
	ad, err := wintun.OpenAdapter(m.AdapterName)
	if err != nil {
		return nil, fmt.Errorf("open Wintun adapter %q: %w", m.AdapterName, err)
	}
	return ad, nil
}

// Create forces creation (installs driver on first use)
func (m *Manager) Create() (*wintun.Adapter, error) {
	// requires elevation
	ad, err := wintun.CreateAdapter(m.AdapterName, m.PoolName, m.GUID)
	if err != nil {
		return nil, fmt.Errorf("create Wintun adapter %q: %w", m.AdapterName, err)
	}
	return ad, nil
}

// UninstallDriver attempts to remove the Wintun driver
func (m *Manager) UninstallDriver() error {
	if err := wintun.Uninstall(); err != nil {
		return fmt.Errorf("wintun uninstall: %w", err)
	}
	return nil
}
