// Message type used for multicast discovery

package multicast

import (
	"errors"
	"strings"
)

const (
	helloMsgPrefix = "Lantern Hello"
	byeMsgPrefix = "Lantern Bye"
	messageMaxSize = 39 // Max size of IPv6 address
)

type messageType int

const (
	TypeHello = iota
	TypeBye
)

type MulticastMessage struct {
	mType   messageType
	payload string
}

func MakeHelloMessage(payload string) *MulticastMessage {
	return &MulticastMessage{
		mType: TypeHello,
		payload: payload,
	}
}

func MakeByeMessage(payload string) *MulticastMessage {
	return &MulticastMessage{
		mType: TypeBye,
		payload: payload,
	}
}

func (msg *MulticastMessage) Serialize() (b []byte, e error) {
	switch msg.mType {
	case TypeHello:
		return []byte(helloMsgPrefix + msg.payload), nil
	case TypeBye:
		return []byte(byeMsgPrefix + msg.payload), nil
	default:
		return nil, errors.New("Multicast message: internal error (wrong message type)")
	}
}

func Deserialize(b []byte) (msg *MulticastMessage, e error) {
	var msgType messageType
	strMsg := string(b)
	if strings.HasPrefix(strMsg, helloMsgPrefix) {
		msgType = TypeHello
		strMsg = strings.TrimPrefix(strMsg, helloMsgPrefix)
	} else if strings.HasPrefix(strMsg, byeMsgPrefix) {
		msgType = TypeBye
		strMsg = strings.TrimPrefix(strMsg, byeMsgPrefix)
	} else {
		return nil, errors.New("Error deserializing multicast message")
	}

	return &MulticastMessage{
		mType: msgType,
		payload: strMsg,
	}, nil
}
