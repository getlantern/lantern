package pubsub

import "testing"

type str struct {
	Val string
}

func TestSub(t *testing.T) {
	if Sub(Location, func(teststr *str) {}) != nil {
		t.Fail()
	}

	// Make sure we get an error if we don't pass a func
	if Sub(Location, "String") == nil {
		t.Fail()
	}
}

func TestPublish(t *testing.T) {
	msgs := make(chan string)
	err := Sub(Location, func(s string) {
		msgs <- s
	})
	if err != nil {
		t.Fatalf("Unable to subscribe: %v", err)
	}

	Pub(Location, "test")

	msg := <-msgs
	if msg != "test" {
		t.Error("Did not get expected string!")
	}
}
