package stack

import (
	"runtime"
	"testing"
)

func TestFindSigpanic(t *testing.T) {
	t.Parallel()
	sp := findSigpanic()
	if got, want := sp.Name(), "runtime.sigpanic"; got != want {
		t.Errorf("got == %v, want == %v", got, want)
	}
}

func TestCaller(t *testing.T) {
	t.Parallel()

	c := Caller(0)
	_, file, line, ok := runtime.Caller(0)
	line--
	if !ok {
		t.Fatal("runtime.Caller(0) failed")
	}

	if got, want := c.file(), file; got != want {
		t.Errorf("got file == %v, want file == %v", got, want)
	}

	if got, want := c.line(), line; got != want {
		t.Errorf("got line == %v, want line == %v", got, want)
	}
}
