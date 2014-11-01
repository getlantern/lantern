package stack

import "testing"

func TestFindSigpanic(t *testing.T) {
	t.Parallel()
	sp := findSigpanic()
	if got, want := sp.Name(), "runtime.sigpanic"; got != want {
		t.Errorf("got == %v, want == %v", got, want)
	}
}
