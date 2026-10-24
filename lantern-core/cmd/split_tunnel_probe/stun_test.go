package main

import (
	"context"
	"encoding/binary"
	"net"
	"testing"
	"time"
)

func stunResponse(transaction []byte) []byte {
	response := make([]byte, 32)
	binary.BigEndian.PutUint16(response, 0x0101)
	binary.BigEndian.PutUint16(response[2:], 12)
	binary.BigEndian.PutUint32(response[4:], stunCookie)
	copy(response[8:20], transaction)
	binary.BigEndian.PutUint16(response[20:], 0x0020)
	binary.BigEndian.PutUint16(response[22:], 8)
	response[25] = 0x01
	binary.BigEndian.PutUint16(response[26:], 12345^0x2112)
	binary.BigEndian.PutUint32(response[28:], 0xc0000201^stunCookie) // 192.0.2.1.
	return response
}

func TestParseSTUNResponse(t *testing.T) {
	transaction := []byte("abcdefghijkl")
	response := stunResponse(transaction)
	got, err := parseSTUNResponse(response, transaction)
	if err != nil || got != "192.0.2.1" {
		t.Fatalf("parseSTUNResponse = %q, %v", got, err)
	}
	for _, test := range []struct {
		name string
		edit func([]byte) []byte
	}{
		{"short header", func(p []byte) []byte { return p[:19] }},
		{"response type", func(p []byte) []byte { p[0] = 0; return p }},
		{"cookie", func(p []byte) []byte { p[4] = 0; return p }},
		{"transaction", func(p []byte) []byte { p[8]++; return p }},
		{"message length", func(p []byte) []byte { p[3]++; return p }},
		{"truncated attribute", func(p []byte) []byte { p[23] = 12; return p }},
		{"IPv6", func(p []byte) []byte { p[25] = 2; return p }},
		{"unknown required attribute", func(p []byte) []byte { p[21] = 0x22; return p }},
		{"missing mapped address", func(p []byte) []byte { p[20] = 0x80; return p }},
	} {
		t.Run(test.name, func(t *testing.T) {
			packet := test.edit(append([]byte(nil), response...))
			if _, err := parseSTUNResponse(packet, transaction); err == nil {
				t.Fatal("invalid response accepted")
			}
		})
	}
}

func TestParseSTUNResponseOptionalAttributePadding(t *testing.T) {
	transaction := []byte("abcdefghijkl")
	response := stunResponse(transaction)
	response = append(response, 0x80, 0x22, 0, 3, 'c', 'i', '!', 0) // SOFTWARE, padded to four bytes.
	binary.BigEndian.PutUint16(response[2:], uint16(len(response)-20))
	if got, err := parseSTUNResponse(response, transaction); err != nil || got != "192.0.2.1" {
		t.Fatalf("parseSTUNResponse = %q, %v", got, err)
	}
}

func TestUDPPublicIP(t *testing.T) {
	server, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	done := make(chan error, 1)
	go func() {
		server.SetDeadline(time.Now().Add(5 * time.Second))
		request := make([]byte, 100)
		n, peer, err := server.ReadFrom(request)
		if err == nil && n == 20 {
			_, err = server.WriteTo(stunResponse(request[8:20]), peer)
		}
		done <- err
	}()
	var local, remote string
	got, err := udpPublicIP(ctx, server.LocalAddr().String(), func(conn net.Conn) error {
		local, remote = conn.LocalAddr().String(), conn.RemoteAddr().String()
		return nil
	})
	if err != nil || got != "192.0.2.1" {
		t.Fatalf("udpPublicIP = %q, %v", got, err)
	}
	if _, _, err := net.SplitHostPort(local); err != nil || remote != server.LocalAddr().String() {
		t.Fatalf("socket evidence = %q -> %q", local, remote)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

func TestUDPPublicIPCanceled(t *testing.T) {
	server, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()
	ctx, cancel := context.WithCancel(context.Background())
	_, err = udpPublicIP(ctx, server.LocalAddr().String(), func(net.Conn) error {
		cancel()
		return nil
	})
	if err == nil {
		t.Fatal("canceled UDP request succeeded")
	}
}
