package utils

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/getlantern/radiance/issue"
)

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

// CreateLogAttachment reads one or more log files and returns attachments
func CreateLogAttachments(logDir string, files ...string) []*issue.Attachment {
	if len(files) == 0 {
		return nil
	}

	logDir = strings.TrimSpace(logDir)

	var out []*issue.Attachment
	for _, f := range files {
		f = strings.TrimSpace(f)
		if f == "" {
			continue
		}

		path := f
		if logDir != "" && !filepath.IsAbs(f) {
			path = filepath.Join(logDir, f)
		}

		data, err := os.ReadFile(path)
		if err != nil {
			log.Printf("could not read log file %q: %v", path, err)
			continue
		}

		out = append(out, &issue.Attachment{
			Name: filepath.Base(path),
			Data: data,
		})
	}

	if len(out) == 0 {
		return nil
	}
	return out
}
