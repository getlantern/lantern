package main

import (
	"github.com/getlantern/edgedetect"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("edgedetect.cmd")
)

func main() {
	log.Debugf("Is Edge: %v", edgedetect.DefaultBrowserIsEdge())
}
