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
	TimeZone         string
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

// SameInterfaceUpdateListener compares the Go listener behind gomobile proxies.
func SameInterfaceUpdateListener(a, b libbox.InterfaceUpdateListener) bool {
	return a != nil && b != nil && a == b
}
