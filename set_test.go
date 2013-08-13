package goset

import "testing"

func Test_New(t *testing.T) {
	s := New()

	if s.Size() != 0 {
		t.Error("New() whitout any parameters should create a set with zero size")
	}
}
