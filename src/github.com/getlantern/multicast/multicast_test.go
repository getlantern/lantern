package multicast

import (
	"encoding/json"
	stdLog "log"
	"sync"
	"syscall"
	"testing"
	"time"
)

const verbose = false

func TestMulticast(t *testing.T) {
	mc1 := JoinMulticast(nil, nil)
	if mc1 == nil {
		t.Fatal("Unable to join multicast group")
	} else if verbose {
		stdLog.Println("Joined and listening to multicast IP", mc1.addr.IP, "on port", mc1.addr.Port)
	}

	// Enable Multicast looping for testing
	f, err := mc1.conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal("Unable to set socket for multicast looping")
	}

	var wg sync.WaitGroup

	wg.Add(1)
	// Sender node
	go func(mc *Multicast) {
		defer wg.Done()

		// Give some time to the other goroutines to build up
		time.Sleep(time.Millisecond * 200)

		msg := "Multicast Hello World!"
		n, e := mc.write(([]byte)(msg))
		if e != nil {
			t.Fatal("Unable to multicast message")
		}

		if verbose {
			stdLog.Printf("--> Sent %d bytes: %s\n", n, msg)
		}

		mc.LeaveMulticast()
		if verbose {
			stdLog.Println("Leaving multicast IP", mc.addr.IP, "on port", mc.addr.Port)
		}
	}(mc1)

	nNodes := 9
	for i := 0; i < nNodes; i++ {
		wg.Add(1)
		go receiverNode(t, &wg, i+1)
	}
	wg.Wait()
}

func receiverNode(t *testing.T, wg *sync.WaitGroup, id int) {
	defer wg.Done()

	mc := JoinMulticast(nil, nil)
	if mc == nil {
		t.Fatal("Unable to join multicast group")
	} else if verbose {
		stdLog.Println("Joined and listening to multicast IP", mc.addr.IP, "on port", mc.addr.Port)
	}

	b := make([]byte, 1000)
	n, _, e := mc.read(b)
	if e != nil {
		t.Fatal("Unable to multicast message")
	}
	if n <= 0 {
		t.Fatal("No data received in multicast messages")
	}
	if verbose {
		stdLog.Println("Node", id, "<-- Received", n, "bytes:", string(b))
	}

	mc.LeaveMulticast()
	if verbose {
		stdLog.Println("Node", id, "leaving multicast IP", mc.addr.IP, "on port", mc.addr.Port)
	}
}

func TestMulticastMessages(t *testing.T) {
	mc1 := JoinMulticast(nil, nil)
	if mc1 == nil {
		t.Fatal("Unable to join multicast group")
	}

	// Enable Multicast looping for testing
	f, err := mc1.conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal("Unable to set socket for multicast looping")
	}

	mc1.SetPayload("testHello")
	mc1.SetPeriod(1)
	mc1.StartMulticast()
	mc1.ListenPeers()

	mc2 := JoinMulticast(nil, nil)
	if mc2 == nil {
		t.Fatal("Unable to join multicast group")
	}

	b := make([]byte, messageMaxSize)
	n, _, e := mc2.read(b)
	if e != nil {
		t.Fatal("Unable to multicast message")
	}
	if n > 0 {
		var msg multicastMessage
		if e = json.Unmarshal(b[:n], &msg); e != nil || msg.Type != typeHello || msg.Payload != "testHello" {
			stdLog.Println(string(b[:n]))
			stdLog.Println(msg)
			t.Fatal("Multicast Hello message is incorrectly formatted")
		}
	} else {
		stdLog.Println("Received 0 bytes")
	}

	mc1.LeaveMulticast()
	mc2.LeaveMulticast()
}

func TestMulticastAnnouncing(t *testing.T) {
	mc1 := JoinMulticast(nil, nil)
	if mc1 == nil {
		t.Fatal("Unable to join multicast group")
	}

	// Enable Multicast looping for testing
	f, err := mc1.conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal("Unable to set socket for multicast looping")
	}

	mc1.SetPeriod(1)
	go func() {
		if e := mc1.sendHellos(); e != nil {
			log.Fatal("Error sending hellos")
		}
	}()

	mc2 := JoinMulticast(
		func(string, []PeerInfo) {
			if verbose {
				stdLog.Println("Adding Peer")
			}
		},
		func(string, []PeerInfo) {
			if verbose {
				stdLog.Println("Removing Peer")
			}
		})
	if mc2 == nil {
		t.Fatal("Unable to join multicast group")
	}

	mc2.StartMulticast()
	mc2.ListenPeers()

	time.Sleep(time.Millisecond * 1100) // Just enough to let the multicast run

	// Should be zero because we don't add ourselves to the peers map
	if len(mc2.peers) != 0 {
		stdLog.Println("Peers in MC1", mc1.peers)
		stdLog.Println("Peers in MC2", mc2.peers)
		t.Fatal("Wrong count of peers")
	}
}
