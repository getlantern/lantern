package wfilter

import (
	"bytes"
	"fmt"
	"io"
	"sync/atomic"
	"testing"

	"github.com/getlantern/testify/assert"
)

func TestLines(t *testing.T) {
	buf := bytes.NewBuffer(nil)
	i := int32(0)
	w := LinePrepender(buf, func(w io.Writer) (int, error) {
		j := atomic.AddInt32(&i, 1)
		return fmt.Fprintf(w, "%d ", j)
	})

	n, err := fmt.Fprint(w, "A")
	if assert.NoError(t, err, "Error writing A") {
		assert.Equal(t, 1, n, "Wrong bytes written for A")
	}
	n, err = fmt.Fprintln(w, "")
	if assert.NoError(t, err, "Error writing newline after A") {
		assert.Equal(t, 1, n, "Wrong bytes written for newline after A")
	}
	n, err = fmt.Fprintf(w, "B\nC")
	if assert.NoError(t, err, "Error writing BC") {
		assert.Equal(t, 3, n, "Wrong bytes written for BC")
	}
	n, err = fmt.Fprintln(w, "\nD")
	if assert.NoError(t, err, "Error writing D") {
		assert.Equal(t, 3, n, "Wrong bytes written for D")
	}

	assert.Equal(t, expected, string(buf.Bytes()))
}

var expected = `1 A
2 B
3 C
4 D
`
