package notify

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

type sender struct {
	out chan interface{}
}

func (s *sender) Send(in interface{}) {
	s.out <- in
}

func TestNotify(t *testing.T) {
	s := &sender{out: make(chan interface{})}
	register := func(t string) (UISender, error) {
		return s, nil
	}
	n, err := NewNotifications(register)
	assert.Nil(t, err)

	buttons := []*Button{&Button{Title: "OK"}}
	not := &Notification{
		Type:    "basic",
		Title:   "Data Cap",
		Message: "Please fix this",
		IconURL: "lantern_logo.png",
		Buttons: buttons,
	}
	n.Notify(not)

	incoming := <-s.out

	assert.Equal(t, not, incoming)
}
