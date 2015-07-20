package rotator

import "io"

// Rotator interface
type Rotator interface {
	// a Write method, a Close method
	io.WriteCloser
	// WriteString writes strings to the file.
	WriteString(str string) (n int, err error)
}
