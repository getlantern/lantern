package pubsub

import (
	"runtime"
	"testing"
)

type str struct {
	Val string
}

func TestSub(t *testing.T) {
	if Sub(&str{}, func(teststr *str) {}) != nil {
		t.Fail()
	}
	if Sub(&str{}, "String") == nil {
		t.Fail()
	}
}

func TestPublish(t *testing.T) {
	var received string = ""
	Sub(&str{}, func(s *str) {
		received = s.Val
	})
	Pub(&str{Val: "test"})

	runtime.Gosched()
	if received != "test" {
		t.Error("Did not get expected string!")
	}
}
