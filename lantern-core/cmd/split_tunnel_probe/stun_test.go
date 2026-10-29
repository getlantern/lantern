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

func TestSTUNResponseRejectsMalformedPacket(t *testing.T) {
	transaction := []byte("abcdefghijkl")
	response := stunResponse(transaction)
	response[8]++
	for _, packet := range [][]byte{response[:19], response} {
		if _, err := parseSTUNResponse(packet, transaction); err == nil {
			t.Fatal("truncated or unrelated STUN response accepted")
		}
	}
}
