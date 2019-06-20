// package wfilter provides facilities for adding filtering to io.Writer.
package wfilter

import (
	"bytes"
	"io"
)

type Prepend func(w io.Writer) (int, error)

// LinePrepender creates an io.Writer that prepends to each line by calling the
// given prepend function. Prepend can write whatever it wants. It should
// return the bytes written and any error encountered.
func LinePrepender(w io.Writer, prepend Prepend) io.Writer {
	return &linePrepender{w, prepend, true}
}

type linePrepender struct {
	io.Writer
	prepend       Prepend
	prependNeeded bool
}

func (w *linePrepender) Write(buf []byte) (int, error) {
	if w.prependNeeded {
		_, err := w.prepend(w.Writer)
		if err != nil {
			return 0, err
		}
		w.prependNeeded = false
	}

	// Prepend before every newline in the buffer
	totalN := 0

	for {
		i := bytes.IndexRune(buf, '\n') + 1
		newlineFound := i > 0
		newlineAtEnd := newlineFound && i == len(buf)

		if !newlineFound {
			break
		} else if newlineAtEnd {
			// Prepend will be needed at beginning of next write
			w.prependNeeded = true
			break
		} else {
			// Newline is somewhere before end
			n, err := w.Writer.Write(buf[:i])
			totalN += n
			if err != nil {
				return totalN, err
			}
			// Add prepend
			_, err = w.prepend(w.Writer)
			if err != nil {
				return totalN, err
			}
			// Remove processed portion of buffer
			buf = buf[i:]
		}
	}

	// Write what's left of buf
	n, err := w.Writer.Write(buf)
	totalN += n
	return totalN, err
}

// SimplePrepender creates an io.Writer that prepends by calling the given
// prepend function. Prepend can write whatever it wants. It should return
// the bytes written and any error encountered.
func SimplePrepender(w io.Writer, prepend Prepend) io.Writer {
	return &simplePrepender{w, prepend}
}

type simplePrepender struct {
	io.Writer
	prepend Prepend
}

func (w *simplePrepender) Write(buf []byte) (int, error) {
	written := 0

	n, err := w.prepend(w.Writer)
	written = written + n
	if err != nil {
		return written, err
	}

	n, err = w.Writer.Write(buf)
	written = written + n
	return written, err
}
