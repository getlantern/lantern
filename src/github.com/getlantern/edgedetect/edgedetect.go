package edgedetect

import (
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("edgedetect")
)

func DefaultBrowserIsEdge() bool {
	return defaultBrowserIsEdge()
}
