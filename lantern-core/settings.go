package lanterncore

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"

	"github.com/getlantern/radiance/common/settings"
)

const appSettingsFile = "settings.json"

func defaultAppSettings() AppSettings {
	return AppSettings{
		IsSplitTunnelingOn:       false,
		Locale:                   "en_US",
		OAuthToken:               "",
		UserLoggedIn:             false,
		BlockAds:                 false,
		Email:                    "",
		ShowSplashScreen:         true,
		TelemetryDialogDismissed: false,
		TelemetryConsent:         false,
		SuccessfulConnection:     false,
		RoutingModeRaw:           "full_tunnel",
		DataCapThreshold:         "",
		SchemaVersion:            1,
	}
}

type AppSettings struct {
	IsSplitTunnelingOn       bool   `json:"isSplitTunnelingOn"`
	Locale                   string `json:"locale"`
	OAuthToken               string `json:"oAuthToken"`
	UserLoggedIn             bool   `json:"userLoggedIn"`
	BlockAds                 bool   `json:"blockAds"`
	Email                    string `json:"email"`
	ShowSplashScreen         bool   `json:"showSplashScreen"`
	TelemetryDialogDismissed bool   `json:"telemetryDialogDismissed"`
	TelemetryConsent         bool   `json:"telemetryConsent"`
	SuccessfulConnection     bool   `json:"successfulConnection"`
	RoutingModeRaw           string `json:"routingModeRaw"`
	DataCapThreshold         string `json:"dataCapThreshold"`

	SelectedServerLocation json.RawMessage `json:"selectedServerLocation,omitempty"`
	DeveloperMode          *developerMode  `json:"developerMode,omitempty"`

	SchemaVersion int `json:"schemaVersion,omitempty"`
}

type appSettingsStore struct {
	mu sync.Mutex
}

var asStore = &appSettingsStore{}

func (s *appSettingsStore) path() string {
	return filepath.Join(settings.GetString(settings.DataPathKey), appSettingsFile)
}

func (s *appSettingsStore) loadUnlocked() (AppSettings, error) {
	p := s.path()
	b, err := os.ReadFile(p)
	if err != nil {
		if os.IsNotExist(err) {
			return defaultAppSettings(), nil
		}
		return AppSettings{}, err
	}
	if len(b) == 0 {
		return defaultAppSettings(), nil
	}

	var cfg AppSettings
	if err := json.Unmarshal(b, &cfg); err != nil {
		// If corrupted, reset to defaults
		return defaultAppSettings(), nil
	}

	if cfg.Locale == "" {
		cfg.Locale = "en_US"
	}
	if cfg.RoutingModeRaw == "" {
		cfg.RoutingModeRaw = "full_tunnel"
	}
	if cfg.SchemaVersion == 0 {
		cfg.SchemaVersion = 1
	}
	return cfg, nil
}

func (s *appSettingsStore) saveUnlocked(cfg AppSettings) error {
	dir := settings.GetString(settings.DataPathKey)
	if dir == "" {
		return errors.New("data dir not set")
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	p := s.path()
	tmp := p + ".tmp"

	b, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(tmp, b, 0644); err != nil {
		return err
	}
	return os.Rename(tmp, p)
}

func (s *appSettingsStore) updateUnlocked(mut func(*AppSettings) error) (AppSettings, error) {
	cfg, err := s.loadUnlocked()
	if err != nil {
		return AppSettings{}, err
	}
	if err := mut(&cfg); err != nil {
		return AppSettings{}, err
	}
	if err := s.saveUnlocked(cfg); err != nil {
		return AppSettings{}, err
	}
	return cfg, nil
}

func loadAppSettings() (AppSettings, error) {
	asStore.mu.Lock()
	defer asStore.mu.Unlock()
	return asStore.loadUnlocked()
}

func updateAppSettings(mut func(*AppSettings) error) (AppSettings, error) {
	asStore.mu.Lock()
	defer asStore.mu.Unlock()
	return asStore.updateUnlocked(mut)
}
