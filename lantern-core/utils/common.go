package utils

import (
	"encoding/json"
	"log/slog"
	"sort"

	"github.com/sagernet/sing-box/experimental/libbox"
)

type Opts struct {
	LogDir           string
	DataDir          string
	Deviceid         string
	LogLevel         string
	Locale           string
	Env              string
	TelemetryConsent bool
	Platform         PlatformInterface
	// EnvOverrides is a JSON-encoded map[string]string applied via
	// os.Setenv before radiance's common.Init runs. Used to forward
	// shell-set RADIANCE_* vars from the main Lantern process into
	// the macOS/iOS system extension, which has no shell env
	// inheritance of its own. Gomobile doesn't marshal maps, so we
	// pass JSON; empty string means no overrides.
	EnvOverrides string
}

// LogValue redacts EnvOverrides' JSON body so forwarded env values don't
// leak into logs; only the sorted key names are kept for debugging.
func (o *Opts) LogValue() slog.Value {
	parsed := ParseEnvOverrides(o.EnvOverrides)
	keys := make([]string, 0, len(parsed))
	for k := range parsed {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return slog.GroupValue(
		slog.String("data_dir", o.DataDir),
		slog.String("log_dir", o.LogDir),
		slog.String("device_id", o.Deviceid),
		slog.String("log_level", o.LogLevel),
		slog.String("locale", o.Locale),
		slog.String("env", o.Env),
		slog.Bool("telemetry_consent", o.TelemetryConsent),
		slog.Any("env_override_keys", keys),
	)
}

// ParseEnvOverrides decodes the JSON-encoded RADIANCE_* map forwarded
// from the host app (see Opts.EnvOverrides). Invalid JSON is logged and
// returns nil — an env plumbing bug shouldn't block the tunnel, and
// returning nil on error avoids applying a partially-populated map.
func ParseEnvOverrides(s string) map[string]string {
	if s == "" {
		return nil
	}
	var m map[string]string
	if err := json.Unmarshal([]byte(s), &m); err != nil {
		slog.Warn("failed to parse EnvOverrides JSON", slog.Any("error", err))
		return nil
	}
	return m
}

type PrivateServerEventListener interface {
	OpenBrowser(url string) error
	OnPrivateServerEvent(event string)
	OnError(err string)
}

// FlutterEvent represents the structure sent to Flutter.
type FlutterEvent struct {
	Type    string `json:"type"`
	Message string `json:"message"`
}

type FlutterEventEmitter interface {
	SendEvent(event *FlutterEvent)
}

type PlatformInterface interface {
	libbox.PlatformInterface
	RestartService() error
	PostServiceClose()
}
