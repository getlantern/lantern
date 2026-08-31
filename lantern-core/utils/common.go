package utils

import (
	commonenv "github.com/getlantern/radiance/common/env"
	"github.com/sagernet/sing-box/experimental/libbox"
)

type Opts struct {
	LogDir           string
	DataDir          string
	Deviceid         string
	AppVersion       string
	LogLevel         string
	Locale           string
	Env              string
	TelemetryConsent bool
	Platform         PlatformInterface
}

// RadianceEnvOverrides returns values that mobile and extension processes may
// not inherit from the host. In particular, Radiance needs the installed app
// version for message targeting.
func (o *Opts) RadianceEnvOverrides() map[string]string {
	if o == nil || o.AppVersion == "" {
		return nil
	}
	return map[string]string{commonenv.AppVersion.String(): o.AppVersion}
}

// IsStaging reports whether Env selects the staging environment. Both
// spellings are accepted; keep every env check on this method so the
// vocabulary can't drift between call sites.
func (o *Opts) IsStaging() bool {
	return o.Env == "stage" || o.Env == "staging"
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

// LogListener receives log entries streamed from the IPC client.
type LogListener interface {
	OnLogEntry(entry string)
}

type PlatformInterface interface {
	libbox.PlatformInterface
	RestartService() error
	PostServiceClose()
}
