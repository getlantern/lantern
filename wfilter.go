// package wfilter provides facilities for adding filtering to io.Writer.
package wfilter

import (
	"bufio"
	"io"
)

// Lines creates a filtering writer that filters on a line by line basis using
// the given filterFunc. FilterFunc is given the string for the current line
// along with the original writer, and it can write whatever it wants. It should
// return the bytes written and any error encountered.
func Lines(w io.Writer, filterFunc func(w io.Writer, line string) (int, error)) io.Writer {
	out, in := io.Pipe()
	lw := &lfw{w, in, out}
	go lw.process(filterFunc)
	return lw
}

type lfw struct {
	io.Writer
	pipeIn  *io.PipeWriter
	pipeOut *io.PipeReader
}

func (w *lfw) Write(b []byte) (int, error) {
	return w.pipeIn.Write(b)
}

func (w *lfw) process(filterFunc func(w io.Writer, line string) (int, error)) {
	r := bufio.NewReader(w.pipeOut)
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		_, err = filterFunc(w.Writer, line)
		if err != nil {
			return
		}
	}
}
