// Message type used for multicast discovery

package multicast

import (
	"encoding/json"
)

const (
	messageMaxSize = 512
)

type messageType int

const (
	TypeHello = 1 + iota
	TypeBye
)

type MulticastMessage struct {
	Type    messageType
	Payload string
}

func MakeHelloMessage(payload string) *MulticastMessage {
	return &MulticastMessage{
		Type:    TypeHello,
		Payload: payload,
	}
}

func MakeByeMessage(payload string) *MulticastMessage {
	return &MulticastMessage{
		Type:    TypeBye,
		Payload: payload,
	}
}

func (msg *MulticastMessage) Serialize() (b []byte, e error) {
	b, e = json.Marshal(msg)
	return
}

func Deserialize(b []byte) (msg *MulticastMessage, e error) {
	msg = new(MulticastMessage)
	e = json.Unmarshal(b, msg)
	return
}
