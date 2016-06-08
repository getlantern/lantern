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

type fholder struct {
	f func() CallStack
}

func (fh *fholder) labyrinth() CallStack {
	for {
		return fh.f()
	}
}

func TestTrace(t *testing.T) {
	t.Parallel()

	fh := fholder{
		f: func() CallStack {
			cs := Trace()
			return cs
		},
	}

	cs := fh.labyrinth()

	lines := []int{50, 41, 55}

	for i, line := range lines {
		if got, want := cs[i].line(), line; got != want {
			t.Errorf("got line[%d] == %v, want line[%d] == %v", i, got, i, want)
		}
	}
}
