// Message type used for multicast discovery

package multicast

import (
	"errors"
	"strings"
)

const (
	helloMsgPrefix = "Lantern Hello"
	byeMsgPrefix = "Lantern Bye"
	messageMaxSize = 16
)

type messageType int

const (
	TypeHello = iota
	TypeBye
)

type MulticastMessage struct {
	mType        messageType
}

func MakeHelloMessage() *MulticastMessage {
	return &MulticastMessage{
		mType: TypeHello,
	}
}

func MakeByeMessage() *MulticastMessage {
	return &MulticastMessage{
		mType: TypeBye,
	}
}

func (msg *MulticastMessage) Serialize() (b []byte, e error) {
	switch msg.mType {
	case TypeHello:
		return []byte(helloMsgPrefix), nil
	case TypeBye:
		return []byte(byeMsgPrefix), nil
	default:
		return nil, errors.New("Multicast message: internal error (wrong message type)")
	}
}

func Deserialize(b []byte) (msg *MulticastMessage, e error) {
	var msgType messageType
	strMsg := string(b)
	if strings.HasPrefix(strMsg, helloMsgPrefix) {
		msgType = TypeHello
	} else if strings.HasPrefix(strMsg, byeMsgPrefix) {
		msgType = TypeBye
	} else {
		return nil, errors.New("Error deserializing multicast message")
	}
	return &MulticastMessage{
		mType: msgType,
	}, nil
}
