package utils

import (
	"log"
	"os"

	"github.com/getlantern/radiance/issue"
)

type Opts struct {
	LogDir   string
	DataDir  string
	Deviceid string
	LogLevel string
	Locale   string
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

// DialEvent represents structured data for dial success and failure events.
type DialEvent struct {
	EventType    string `json:"event_type"`              // "dial_success" or "dial_failure"
	Timestamp    int64  `json:"timestamp"`               // Unix timestamp in milliseconds
	Group        string `json:"group,omitempty"`         // Server group (e.g., "lantern", "user", "all")
	Tag          string `json:"tag,omitempty"`           // Server tag/identifier
	Error        string `json:"error,omitempty"`         // Error message if failure
	DurationMs   int64  `json:"duration_ms,omitempty"`   // Time taken for dial operation
	ServerType   string `json:"server_type,omitempty"`   // Type of server being connected to
}

// CreateLogAttachment tries to read the log file at logFilePath and returns
// an []*issue.Attachment with the log (if found)
func CreateLogAttachment(logFilePath string) []*issue.Attachment {
	if logFilePath == "" {
		return nil
	}
	data, err := os.ReadFile(logFilePath)
	if err != nil {
		log.Printf("could not read log file %q: %v", logFilePath, err)
		return nil
	}
	return []*issue.Attachment{{
		Name: "flutter.log",
		Data: data,
	}}
}
