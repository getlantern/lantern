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
	// Mcc is the network Mobile Country Code, read by the host from
	// the cellular stack (Android: first 3 chars of
	// TelephonyManager.getNetworkOperator()). Empty on WiFi-only,
	// no cellular signal, or platforms that don't expose it. Used
	// by radiance to gate activation of the heavier meek transport.
	Mcc              string
	TelemetryConsent bool
	Platform         PlatformInterface
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
