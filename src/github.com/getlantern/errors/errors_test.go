package errors

import (
	"bytes"
	"fmt"
	"regexp"
	"testing"

	"github.com/getlantern/context"
	"github.com/getlantern/hidden"
	"github.com/getlantern/ops"
	"github.com/stretchr/testify/assert"
)

var (
	replaceNumbers = regexp.MustCompile("[0-9]+")
)

func TestFull(t *testing.T) {
	var firstErr Error

	// Iterate past the size of the hidden buffer
	for i := 0; i < len(hiddenErrors)*2; i++ {
		op := ops.Begin("op1").Set("ca", 100).Set("cd", 100)
		e := New("Hello %v", "There").Op("My Op").With("DaTa_1", 1)
		op.End()
		if firstErr == nil {
			firstErr = e
		}
		assert.Equal(t, "Hello There", e.Error()[:11])
		op = ops.Begin("op2").Set("ca", 200).Set("cb", 200).Set("cc", 200)
		e3 := Wrap(fmt.Errorf("I'm wrapping your text: %v", e)).Op("outer op").With("dATA+1", i).With("cb", 300)
		op.End()
		assert.Equal(t, e, e3.(*structured).cause, "Wrapping a regular error should have extracted the contained *Error")
		m := make(context.Map)
		e3.Fill(m)
		assert.Equal(t, i, m["data_1"], "Error's data should dominate all")
		assert.Equal(t, 200, m["ca"], "Error's context should dominate cause")
		assert.Equal(t, 300, m["cb"], "Error's data should dominate its context")
		assert.Equal(t, 200, m["cc"], "Error's context should come through")
		assert.Equal(t, 100, m["cd"], "Cause's context should come through")
		assert.Equal(t, "My Op", e.(*structured).data["error_op"], "Op should be available from cause")

		for _, call := range e3.(*structured).callStack {
			t.Logf("at %v", call)
		}
	}

	e3 := Wrap(fmt.Errorf("I'm wrapping your text: %v", firstErr)).With("a", 2)
	assert.Nil(t, e3.(*structured).cause, "Wrapping an *Error that's no longer buffered should have yielded no cause")
}

func TestNewWithCause(t *testing.T) {
	cause := buildCause()
	outer := New("Hello %v", cause)
	assert.Equal(t, "Hello World", hidden.Clean(outer.Error()))
	assert.Equal(t, "Hello %v", outer.(*structured).ErrorClean())
	assert.Equal(t,
		"github.com/getlantern/errors.TestNewWithCause (errors_test.go:999)",
		replaceNumbers.ReplaceAllString(outer.(*structured).data["error_location"].(string), "999"))
	assert.Equal(t, cause, outer.(*structured).cause)

	// Make sure that stacktrace prints out okay
	buf := &bytes.Buffer{}
	buf.WriteString(outer.Error())
	buf.WriteByte('\n')
	outer.PrintStack(buf, "")
	expected := `Hello World
  at github.com/getlantern/errors.TestNewWithCause (errors_test.go:999)
  at testing.tRunner (testing.go:999)
  at runtime.goexit (asm_amd999.s:999)
Caused by: World
  at github.com/getlantern/errors.buildCause (errors_test.go:999)
  at github.com/getlantern/errors.TestNewWithCause (errors_test.go:999)
  at testing.tRunner (testing.go:999)
  at runtime.goexit (asm_amd999.s:999)
Caused by: orld
Caused by: ld
  at github.com/getlantern/errors.buildSubSubCause (errors_test.go:999)
  at github.com/getlantern/errors.buildSubCause (errors_test.go:999)
  at github.com/getlantern/errors.buildCause (errors_test.go:999)
  at github.com/getlantern/errors.TestNewWithCause (errors_test.go:999)
  at testing.tRunner (testing.go:999)
  at runtime.goexit (asm_amd999.s:999)
Caused by: d
`

	assert.Equal(t, expected, replaceNumbers.ReplaceAllString(hidden.Clean(buf.String()), "999"))
	assert.Equal(t, buildSubSubSubCause(), outer.RootCause())
}

func buildCause() Error {
	return New("W%v", buildSubCause())
}

func buildSubCause() error {
	return fmt.Errorf("or%v", buildSubSubCause())
}

func buildSubSubCause() error {
	return New("l%v", buildSubSubSubCause())
}

func buildSubSubSubCause() error {
	return fmt.Errorf("d")
}

func TestWrapNil(t *testing.T) {
	assert.Nil(t, doWrapNil())
}

func doWrapNil() error {
	return Wrap(nil)
}
