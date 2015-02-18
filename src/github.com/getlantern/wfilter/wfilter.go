// package wfilter provides facilities for adding filtering to io.Writer.
package wfilter

import (
	"bytes"
	"io"
	"log"
)

type Prepend func(w io.Writer) (int, error)

// LinePrepender creates an io.Writer that prepends to each line by calling the
// given prepend function. Perepend can write whatever it wants. It should
// return the bytes written and any error encountered.
func LinePrepender(w io.Writer, prepend Prepend) io.Writer {
	return &lp{w, prepend, true}
}

type lp struct {
	io.Writer
	prepend       Prepend
	prependNeeded bool
}

func (w *lp) Write(buf []byte) (int, error) {
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
		if i > 0 {
			if i < len(buf) {
				// Newline is in middle of buffer
				// Write up to newline
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
				continue
			}
			// Newline is at end of buffer, mark prependNeeded for next write
			w.prependNeeded = true
		}
		break
	}

	n, err := w.Writer.Write(buf)
	totalN += n
	return totalN, err
}
