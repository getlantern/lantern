package rot13

import (
	"bytes"
	"io"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRoundTrip(t *testing.T) {
	var in, out, rt bytes.Buffer
	for i := byte(0); i <= 255; i++ {
		err := in.WriteByte(i)
		if !assert.NoError(t, err, "Unable to write byte") {
			return
		}
		if i == 255 {
			break
		}
	}
	orig := in.Bytes()

	w := NewWriter(&out)
	r := NewReader(&out)

	n, err := io.Copy(w, &in)
	if !assert.NoError(t, err, "Unable to write rot13") {
		return
	}
	assert.EqualValues(t, 256, n, "Wrong number of bytes written")
	n, err = io.Copy(&rt, r)
	if !assert.NoError(t, err, "Unable to read rot13") {
		return
	}
	assert.EqualValues(t, 256, n, "Wrong number of bytes read")
	assert.Equal(t, len(orig), len(rt.Bytes()), "Size of round-tripped didn't equal original")
	assert.Equal(t, orig, rt.Bytes(), "Round-tripped didn't equal original")
}
