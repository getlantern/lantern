// package wfilter provides facilities for adding filtering to io.Writer.
package wfilter

import (
	"bytes"
	"io"
)

type Prepend func(w io.Writer) (int, error)

// lines creates a filtering writer that filters on a line by line basis using
// the given filterFunc. FilterFunc is given the string for the current line
// along with the original writer, and it can write whatever it wants. It should
// return the bytes written and any error encountered.
func LinePrepender(w io.Writer, prepend Prepend) io.Writer {
	return &lp{w, prepend}
}

type lp struct {
	io.Writer
	prepend Prepend
}

func (w *lp) Write(buf []byte) (int, error) {
	totalN := 0
	for {
		_, err := w.prepend(w.Writer)
		if err != nil {
			return totalN, err
		}
		i := bytes.IndexRune(buf, '\n') + 1
		isLastLine := (i == len(buf))
		n, err := w.Writer.Write(buf[:i])
		totalN += n
		if err != nil || isLastLine {
			return totalN, err
		}
		buf = buf[i:]
	}
}
