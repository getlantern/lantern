// package wfilter provides facilities for adding filtering to io.Writer.
package wfilter

import (
	"bytes"
	"io"
)

const (
	MaxLineLength = 2 << 15
)

type FilterFunc func(w io.Writer, line string) (int, error)

// lines creates a filtering writer that filters on a line by line basis using
// the given filterFunc. FilterFunc is given the string for the current line
// along with the original writer, and it can write whatever it wants. It should
// return the bytes written and any error encountered.
func Lines(w io.Writer, filterFunc FilterFunc) io.Writer {
	return &lfw{w, filterFunc, nil}
}

type lfw struct {
	io.Writer
	filterFunc FilterFunc
	line       []byte
}

func (w *lfw) Write(buf []byte) (int, error) {
	if w.line == nil {
		w.line = make([]byte, 0, len(buf))
	}
	i := bytes.IndexRune(buf, '\n') + 1
	if i > 0 {
		w.line = append(w.line, buf[:i]...)
		n, err := w.filterFunc(w.Writer, string(w.line))
		w.line = nil
		return n, err
	}
	if len(w.line)+len(buf) > MaxLineLength {
		// Don't let lines get too long
		w.line = nil
	} else {
		w.line = append(w.line, buf...)
	}
	return len(buf), nil
}
