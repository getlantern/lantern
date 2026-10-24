package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"time"
)

const stunCookie = 0x2112a442

// udpPublicIP sends real UDP traffic and reads the address observed by a STUN server.
func udpPublicIP(ctx context.Context, endpoint string, connected func(net.Conn) error) (string, error) {
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	conn, err := dialer.DialContext(ctx, "udp4", endpoint)
	if err != nil {
		return "", err
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { conn.Close() })
	defer stop()
	if connected != nil {
		if err := connected(conn); err != nil {
			return "", err
		}
	}
	request := make([]byte, 20)
	binary.BigEndian.PutUint16(request, 0x0001) // Binding request, no attributes.
	binary.BigEndian.PutUint32(request[4:], stunCookie)
	if _, err := rand.Read(request[8:]); err != nil {
		return "", err
	}
	buffer := make([]byte, 1500)
	// RFC 8489 starts UDP retransmissions at 500 ms and doubles the interval.
	for attempt := 0; attempt < 4; attempt++ {
		if err := conn.SetDeadline(time.Now().Add((500 * time.Millisecond) << attempt)); err != nil {
			return "", err
		}
		if _, err := conn.Write(request); err != nil {
			return "", err
		}
		n, err := conn.Read(buffer)
		if err != nil {
			var timeout net.Error
			if errors.As(err, &timeout) && timeout.Timeout() && ctx.Err() == nil {
				continue
			}
			return "", err
		}
		return parseSTUNResponse(buffer[:n], request[8:])
	}
	return "", errors.New("STUN server did not respond")
}

// parseSTUNResponse accepts a matching IPv4 Binding success response (RFC 8489).
func parseSTUNResponse(packet, transaction []byte) (string, error) {
	if len(packet) < 20 || binary.BigEndian.Uint16(packet) != 0x0101 ||
		binary.BigEndian.Uint32(packet[4:]) != stunCookie || len(transaction) != 12 ||
		!bytes.Equal(packet[8:20], transaction) {
		return "", errors.New("invalid STUN response header")
	}
	length := int(binary.BigEndian.Uint16(packet[2:]))
	if length%4 != 0 || length != len(packet)-20 {
		return "", errors.New("invalid STUN response length")
	}
	var ip string
	for offset := 20; offset < len(packet); {
		if len(packet)-offset < 4 {
			return "", errors.New("truncated STUN attribute")
		}
		kind := binary.BigEndian.Uint16(packet[offset:])
		length := int(binary.BigEndian.Uint16(packet[offset+2:]))
		offset += 4
		padded := (length + 3) &^ 3
		if padded > len(packet)-offset {
			return "", errors.New("invalid STUN attribute length")
		}
		value := packet[offset : offset+length]
		if kind == 0x0020 { // XOR-MAPPED-ADDRESS.
			if length != 8 || value[1] != 0x01 {
				return "", errors.New("STUN response has no IPv4 mapped address")
			}
			if ip == "" {
				address := make(net.IP, net.IPv4len)
				binary.BigEndian.PutUint32(address, binary.BigEndian.Uint32(value[4:])^stunCookie)
				ip = address.String()
			}
		} else if kind < 0x8000 && kind != 0x0001 { // Ignore the legacy MAPPED-ADDRESS.
			return "", fmt.Errorf("unsupported STUN attribute %#04x", kind)
		}
		offset += padded
	}
	if ip == "" {
		return "", errors.New("STUN response is missing XOR-MAPPED-ADDRESS")
	}
	return ip, nil
}
