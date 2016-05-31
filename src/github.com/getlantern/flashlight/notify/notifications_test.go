package notify

import (
	"encoding/json"
	"testing"

	"github.com/getlantern/flashlight/ui"
	"github.com/stretchr/testify/assert"
)

type sender struct {
}

func (s *sender) Send(interface{}) {

}

func TestNotify(t *testing.T) {
	register := func(t string) (UISender, error) {
		return &sender{}, nil
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

	b, err := json.Marshal(&ui.Envelope{
		EnvelopeType: ui.EnvelopeType{Type: "notification"},
		Message:      not,
	})

	log.Debugf("JSON:\n%v", string(b))
}
