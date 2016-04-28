package rot13

import (
	"io"
)

type ROT13Writer struct {
	wrapped io.Writer
}

type ROT13Reader struct {
	wrapped io.Reader
}

func NewWriter(wrapped io.Writer) io.Writer {
	return &ROT13Writer{wrapped}
}

func NewReader(wrapped io.Reader) io.Reader {
	return &ROT13Reader{wrapped}
}

func (r *ROT13Writer) Write(p []byte) (int, error) {
	o := make([]byte, len(p))
	for i := 0; i < len(p); i++ {
		o[i] = p[i] + 13
	}
	return r.wrapped.Write(o)
}

func (r *ROT13Reader) Read(p []byte) (int, error) {
	n, err := r.wrapped.Read(p)
	if err != nil {
		return n, err
	}
	for i := 0; i < n; i++ {
		p[i] = p[i] - 13
	}
	return n, err
}
