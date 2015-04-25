// package nattest provides the capability to test a nat-traversed UDP
// connection by sending packets back and forth between client and server. The
// client sends 10 packets containing "Ping" to the server, spaced out by 2
// seconds. Once the server receives a Ping packet, it responds with 10 packets
// containing "Pong", spaced out by 2 seconds, and then terminates. Once the
// client receives a "Pong" packet, it considers the traversal successful.
//
// Note - both the client and server ignore unexpected (gibberish) packets, so
// as long as client and server both get at least one good packet, the
// connection is considered successful.
package nattest

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"time"

	"github.com/getlantern/golog"
)

const (
	NumUDPTestPackets = 10
	PacketPause       = 2 * time.Second
	ConnTimeout       = NumUDPTestPackets * PacketPause
)

var (
	log = golog.LoggerFor("flashlight.nattest")

	pingMsg = []byte("ping")
	pongMsg = []byte("pong")
)

// Ping pings the server at the other end of a NAT-traversed UDP connection and
// looks for echo packets to confirm connectivity with the server. It returns
// true if connectivity was confirmed, false otherwise.
func Ping(local *net.UDPAddr, remote *net.UDPAddr) bool {
	conn, err := net.DialUDP("udp", local, remote)
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(ConnTimeout))

	if err != nil {
		log.Debugf("Unable to dial UDP: %s", err)
		return false
	}

	go sendPingPackets(conn)
	return readPongPackets(conn)
}

func Serve(local *net.UDPAddr) error {
	conn, err := net.ListenUDP("udp", local)
	if err != nil {
		return fmt.Errorf("Unable to listen on UDP: %s", err)
	}

	go func() {
		gotPing := false
		defer func() {
			if !gotPing {
				// If we didn't get a ping, close the conn. If we got a ping,
				// let sendPongPackets() handle it.
				conn.Close()
			}
		}()

		startTime := time.Now()
		b := make([]byte, 1024)
		for {
			if time.Now().Sub(startTime) > 30*time.Second {
				log.Tracef("Server stopped listening for UDP packets at: %s", local)
				return
			}
			n, addr, err := conn.ReadFrom(b)
			if err != nil {
				log.Debugf("Server unable to read from UDP: %s", err)
			}
			msg := b[:n]
			log.Tracef("Got UDP message from %s: '%s'", addr, msg)
			if bytes.Equal(msg, pingMsg) {
				// We got a ping message, respond and break out of loop
				gotPing = true
				go sendPongPackets(conn, addr)
				return
			} else {
				log.Debugf("Server received unexpected message: %s", msg)
			}
		}
	}()

	log.Tracef("nattest listening for UDP packets at: %s", local)
	return nil
}

func sendPingPackets(conn *net.UDPConn) {
	for i := 0; i < NumUDPTestPackets; i++ {
		_, err := conn.Write(pingMsg)
		if err != nil {
			log.Tracef("Unable to send ping packet: %v", err)
			return
		}
		time.Sleep(PacketPause)
	}
}

func sendPongPackets(conn *net.UDPConn, to net.Addr) {
	defer conn.Close()
	for i := 0; i < NumUDPTestPackets; i++ {
		_, err := conn.WriteTo(pongMsg, to)
		if err != nil {
			log.Tracef("Unable to send pong packet: %v", err)
			return
		}
		time.Sleep(PacketPause)
	}
}

func readPongPackets(conn *net.UDPConn) bool {
	// Read pong packets
	b := make([]byte, 1024)
	conn.SetReadDeadline(time.Now().Add(ConnTimeout))
	for i := 0; i < NumUDPTestPackets; i++ {
		n, addr, err := conn.ReadFrom(b)
		if err != nil {
			// io.EOF should indicate that the connection
			// is closed by the other end
			if err == io.EOF {
				return false
			} else {
				log.Debugf("Error reading UDP packet %v", err)
				time.Sleep(time.Second)
				continue
			}
		}
		msg := b[:n]
		if bytes.Equal(msg, pongMsg) {
			log.Tracef("Received pong from %v %d", addr, n)
			return true
		} else {
			log.Debugf("Client received unexpected message from %v: %s", addr, msg)
		}
		return true
	}

	return false
}
