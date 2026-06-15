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

// FlutterEventEmitter forwards events to the host (Flutter via gomobile on
// mobile, or the Dart port on FFI). SendEvent passes the fields BY VALUE rather
// than a *FlutterEvent: gomobile marshals a Go pointer argument as a refnum'd
// proxy and resolves it (go_seq_from_refnum) while invoking the foreign method,
// so a GC that collects the short-lived event mid-call aborts the process
// ("Unknown reference: <n>" in cproxyutils_FlutterEventEmitter_SendEvent) —
// reliably hit when the app backgrounds. Strings are copied across the
// boundary, so nothing Go-owned outlives the call.
type FlutterEventEmitter interface {
	SendEvent(eventType string, message string)
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
