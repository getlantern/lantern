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
		Name: "lantern.log",
		Data: data,
	}}
}
