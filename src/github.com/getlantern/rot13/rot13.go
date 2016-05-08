// Package rot13 provides ROT13 "encryption" and "decryption".
package rot13

import (
	"io"
)

type rot13Writer struct {
	wrapped io.Writer
}

type rot13Reader struct {
	wrapped io.Reader
}

// NewWriter creates a new io.Writer that encrypts with ROT13.
func NewWriter(wrapped io.Writer) io.Writer {
	return &rot13Writer{wrapped}
}

// NewReader creates a new io.Reader that encrypts with ROT13.
func NewReader(wrapped io.Reader) io.Reader {
	return &rot13Reader{wrapped}
}

func (r *rot13Writer) Write(p []byte) (int, error) {
	o := make([]byte, len(p))
	for i := 0; i < len(p); i++ {
		o[i] = p[i] + 13
	}
	return r.wrapped.Write(o)
}

func (r *rot13Reader) Read(p []byte) (int, error) {
	n, err := r.wrapped.Read(p)
	if err != nil {
		return n, err
	}
	for i := 0; i < n; i++ {
		p[i] = p[i] - 13
	}
	return n, err
}
