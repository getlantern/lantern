package natty

import (
	elog "log"
	"net"
	"time"

	natty "."
)

func ExampleOffer() {
	t := natty.Offer(15 * time.Second)
	defer t.Close()

	// Process outbound messages
	go func() {
		for {
			msg, done := t.NextMsgOut()
			if done {
				return
			}
			// TODO: Send message to peer via signaling channel
			elog.Printf("Sent: %s", msg)
		}
	}()

	// Process inbound messages
	go func() {
		for {
			// TODO: Get message from signaling channel
			var msg string
			t.MsgIn(msg)
		}
	}()

	// Try it with a really short timeout (should error)
	fiveTuple, err := t.FiveTuple()
	if err != nil {
		elog.Fatal(err)
	}

	local, remote, err := fiveTuple.UDPAddrs()
	if err != nil {
		elog.Fatal(err)
	}

	// TODO: Wait for peer to signal that it's ready to receive traffic
	conn, err := net.DialUDP("udp", local, remote)
	if err != nil {
		elog.Fatal(err)
	}
	for {
		_, err := conn.Write([]byte("My data"))
		if err != nil {
			elog.Fatal(err)
		}
	}
}

func ExampleAnswer() {
	t := natty.Answer(15 * time.Second)
	defer t.Close()

	// Process outbound messages
	go func() {
		for {
			msg, done := t.NextMsgOut()
			if done {
				return
			}
			// TODO: Send message to peer via signaling channel
			elog.Printf("Sent: %s", msg)
		}
	}()

	// Process inbound messages
	go func() {
		for {
			// TODO: Get message from signaling channel
			var msg string
			t.MsgIn(msg)
		}
	}()

	fiveTuple, err := t.FiveTuple()
	if err != nil {
		elog.Fatal(err)
	}

	local, _, err := fiveTuple.UDPAddrs()
	if err != nil {
		elog.Fatal(err)
	}

	conn, err := net.ListenUDP("udp", local)
	if err != nil {
		elog.Fatal(err)
	}

	// TODO: signal to peer that we're ready to receive traffic

	b := make([]byte, 1024)
	for {
		n, addr, err := conn.ReadFrom(b)
		if err != nil {
			elog.Fatal(err)
		}

		elog.Printf("Received message '%s' from %s", string(b[:n]), addr)
	}
}
