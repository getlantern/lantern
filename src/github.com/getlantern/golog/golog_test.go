package golog

import (
	"bytes"
	"io"
	"io/ioutil"
	"os"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/getlantern/errors"
	"github.com/getlantern/ops"

	"github.com/stretchr/testify/assert"
)

var (
	expectedLog      = "SEVERITY myprefix: golog_test.go:999 Hello world\nSEVERITY myprefix: golog_test.go:999 Hello true [cvarA=a cvarB=b op=name root_op=name]\n"
	expectedErrorLog = `ERROR myprefix: golog_test.go:999 Hello world [cvarC=c cvarD=d error=Hello world error_type=errors.Error op=name root_op=name]
ERROR myprefix: golog_test.go:999   at github.com/getlantern/golog.TestError (golog_test.go:999)
ERROR myprefix: golog_test.go:999   at testing.tRunner (testing.go:999)
ERROR myprefix: golog_test.go:999   at runtime.goexit (asm_amd999.s:999)
ERROR myprefix: golog_test.go:999 Caused by: world
ERROR myprefix: golog_test.go:999   at github.com/getlantern/golog.errorReturner (golog_test.go:999)
ERROR myprefix: golog_test.go:999   at github.com/getlantern/golog.TestError (golog_test.go:999)
ERROR myprefix: golog_test.go:999   at testing.tRunner (testing.go:999)
ERROR myprefix: golog_test.go:999   at runtime.goexit (asm_amd999.s:999)
ERROR myprefix: golog_test.go:999 Hello true [cvarA=a cvarB=b cvarC=c error=Hello error_type=errors.Error op=name root_op=name]
`
	expectedTraceLog = "TRACE myprefix: golog_test.go:999 Hello world\nTRACE myprefix: golog_test.go:999 Hello true\nTRACE myprefix: golog_test.go:999 Gravy\nTRACE myprefix: golog_test.go:999 TraceWriter closed due to unexpected error: EOF\n"
	expectedStdLog   = expectedLog
)

var (
	replaceNumbers = regexp.MustCompile("[0-9]+")
)

func init() {
	ops.PutGlobal("global", "shouldn't show up")
}

func expected(severity string, log string) string {
	return strings.Replace(log, "SEVERITY", severity, -1)
}

func normalized(log string) string {
	return replaceNumbers.ReplaceAllString(log, "999")
}

func TestDebug(t *testing.T) {
	out := newBuffer()
	SetOutputs(ioutil.Discard, out)
	l := LoggerFor("myprefix")
	l.Debug("Hello world")
	defer ops.Enter("name").Put("cvarA", "a").Put("cvarB", "b").Exit()
	l.Debugf("Hello %v", true)
	assert.Equal(t, expected("DEBUG", expectedLog), out.String())
}

func TestError(t *testing.T) {
	out := newBuffer()
	SetOutputs(out, ioutil.Discard)
	l := LoggerFor("myprefix")
	ctx := ops.Enter("name").Put("cvarC", "c")
	err := errorReturner()
	err1 := errors.New("Hello %v", err)
	err2 := errors.New("Hello")
	ctx.Exit()
	l.Error(err1)
	defer ops.Enter("name2").Put("cvarA", "a").Put("cvarB", "b").Exit()
	l.Errorf("%v %v", err2, true)
	t.Log(out.String())
	assert.Equal(t, expectedErrorLog, out.String())
}

func errorReturner() error {
	defer ops.Enter("name").Put("cvarD", "d").Exit()
	return errors.New("world")
}

func TestTraceEnabled(t *testing.T) {
	originalTrace := os.Getenv("TRACE")
	err := os.Setenv("TRACE", "true")
	if err != nil {
		t.Fatalf("Unable to set trace to true")
	}
	defer func() {
		if err := os.Setenv("TRACE", originalTrace); err != nil {
			t.Fatalf("Unable to set TRACE environment variable: %v", err)
		}
	}()

	out := newBuffer()
	SetOutputs(ioutil.Discard, out)
	l := LoggerFor("myprefix")
	l.Trace("Hello world")
	l.Tracef("Hello %v", true)
	tw := l.TraceOut()
	if _, err := tw.Write([]byte("Gravy\n")); err != nil {
		t.Fatalf("Unable to write: %v", err)
	}
	if err := tw.(io.Closer).Close(); err != nil {
		t.Fatalf("Unable to close: %v", err)
	}

	// Give trace writer a moment to catch up
	time.Sleep(50 * time.Millisecond)
	assert.Regexp(t, expected("TRACE", expectedTraceLog), out.String())
}

func TestTraceDisabled(t *testing.T) {
	originalTrace := os.Getenv("TRACE")
	err := os.Setenv("TRACE", "false")
	if err != nil {
		t.Fatalf("Unable to set trace to false")
	}
	defer func() {
		if err := os.Setenv("TRACE", originalTrace); err != nil {
			t.Fatalf("Unable to set TRACE environment variable: %v", err)
		}
	}()

	out := newBuffer()
	SetOutputs(ioutil.Discard, out)
	l := LoggerFor("myprefix")
	l.Trace("Hello world")
	l.Tracef("Hello %v", true)
	if _, err := l.TraceOut().Write([]byte("Gravy\n")); err != nil {
		t.Fatalf("Unable to write: %v", err)
	}

	// Give trace writer a moment to catch up
	time.Sleep(50 * time.Millisecond)

	assert.Equal(t, "", out.String(), "Nothing should have been logged")
}

func TestAsStdLogger(t *testing.T) {
	out := newBuffer()
	SetOutputs(out, ioutil.Discard)
	l := LoggerFor("myprefix")
	stdlog := l.AsStdLogger()
	stdlog.Print("Hello world")
	defer ops.Enter("name").Put("cvarA", "a").Put("cvarB", "b").Exit()
	stdlog.Printf("Hello %v", true)
	assert.Equal(t, expected("ERROR", expectedStdLog), out.String())
}

// TODO: TraceWriter appears to have been broken since we added line numbers
// func TestTraceWriter(t *testing.T) {
// 	originalTrace := os.Getenv("TRACE")
// 	err := os.Setenv("TRACE", "true")
// 	if err != nil {
// 		t.Fatalf("Unable to set trace to true")
// 	}
// 	defer func() {
// 		if err := os.Setenv("TRACE", originalTrace); err != nil {
// 			t.Fatalf("Unable to set TRACE environment variable: %v", err)
// 		}
// 	}()
//
// 	out := newBuffer()
// 	SetOutputs(ioutil.Discard, out)
// 	l := LoggerFor("myprefix")
// 	trace := l.TraceOut()
// 	trace.Write([]byte("Hello world\n"))
// 	defer ops.Enter().Put("cvarA", "a").Put("cvarB", "b").Exit()
// 	trace.Write([]byte("Hello true\n"))
// 	assert.Equal(t, expected("TRACE", expectedStdLog), out.String())
// }

func newBuffer() *synchronizedbuffer {
	return &synchronizedbuffer{orig: &bytes.Buffer{}}
}

type synchronizedbuffer struct {
	orig  *bytes.Buffer
	mutex sync.RWMutex
}

func (buf *synchronizedbuffer) Write(p []byte) (int, error) {
	buf.mutex.Lock()
	defer buf.mutex.Unlock()
	return buf.orig.Write(p)
}

func (buf *synchronizedbuffer) String() string {
	buf.mutex.RLock()
	defer buf.mutex.RUnlock()
	return normalized(buf.orig.String())
}
