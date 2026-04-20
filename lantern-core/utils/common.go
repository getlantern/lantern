package utils

import (
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
