// Message type used for multicast discovery

package multicast

import (
	"errors"
	"net"
	"os"
	"strings"
)

const (
	helloMsgPrefix = "Lantern Hello"
	byeMsgPrefix = "Lantern Bye"
)

type messageType int

const (
	TypeHello = iota
	TypeBye
)

type MulticastMessage struct {
	mType        messageType
	ips          []net.IP
}

func MakeHelloMessage() *MulticastMessage {
	return makeMessage(TypeHello)
}

func MakeByeMessage() *MulticastMessage {
	return makeMessage(TypeBye)
}

func makeMessage(t messageType) *MulticastMessage {
	host, _ := os.Hostname()
	ips, _ := net.LookupIP(host)
	return &MulticastMessage{
		mType: t,
		ips: ips,
	}
}

func (msg *MulticastMessage) Serialize() (b []byte, e error) {
	switch msg.mType {
	case TypeHello:
		return []byte(helloMsgPrefix + iPsToString(msg.ips)), nil
	case TypeBye:
		return []byte(byeMsgPrefix + iPsToString(msg.ips)), nil
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

	strs := strings.Split(strMsg[1:], "|")
	ips := make([]net.IP, len(strs))

	for i, str := range strs {
		addr, e := net.ResolveUDPAddr("udp4",str)
		if e != nil {
			continue
		}
		ips[i] = addr.IP
	}
	return &MulticastMessage{
		mType: msgType,
		ips: ips,
	}, nil
}

func iPsToString(ips []net.IP) string {
	var msg string
	for _, addr := range ips {
		if ipv4 := addr.To4(); ipv4 != nil {
			msg += "|" + ipv4.String() + ":" + multicastPort
		}
	}
	return msg
}

func (msg *MulticastMessage) hasOriginIP(ip string) bool {
	for _, s := range msg.ips {
		if ip == s.String() {
			return true
		}
	}
	return false
}
