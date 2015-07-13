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
	_ = iota
	typeHello
	typeBye
)

type multicastMessage struct {
	Type    messageType
	Payload string
}

func makeHelloMessage(payload string) *multicastMessage {
	return &multicastMessage{
		Type:    typeHello,
		Payload: payload,
	}
}

func makeByeMessage(payload string) *multicastMessage {
	return &multicastMessage{
		Type:    typeBye,
		Payload: payload,
	}
}

func (msg *multicastMessage) serialize() (b []byte, e error) {
	return json.Marshal(msg)
}

func deserialize(b []byte) (msg *multicastMessage, e error) {
	msg = new(multicastMessage)
	e = json.Unmarshal(b, msg)
	return
}
