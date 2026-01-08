package utils

type Opts struct {
	LogDir           string
	DataDir          string
	Deviceid         string
	LogLevel         string
	Locale           string
	TelemetryConsent bool
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
