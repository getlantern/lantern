package rotator

import (
	"io"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("sizerotator")
)

// Rotator interface
type Rotator interface {
	// a Write method, a Close method
	io.WriteCloser
	// WriteString writes strings to the file.
	WriteString(str string) (n int, err error)
}
