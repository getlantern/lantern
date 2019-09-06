// Package edgedetect provides support for detecing whether the default web
// browser is Microsoft Edge.
package edgedetect

import (
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("edgedetect")
)

// DefaultBrowserIsEdge returns true if and only if the default web browser is
// Microsoft Edge.
func DefaultBrowserIsEdge() bool {
	return defaultBrowserIsEdge()
}
