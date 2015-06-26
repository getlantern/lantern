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
	mc1 := JoinMulticast()
	if mc1 == nil {
		t.Fatal("Unable to join multicast group")
	} else if verbose {
		stdLog.Println("Joined and listening to multicast IP", mc1.Addr.IP, "on port", mc1.Addr.Port)
	}

	// Enable Multicast looping for testing
	f, err := mc1.Conn.File()
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

		e = mc.LeaveMulticast()

		if e != nil {
			t.Fatal("Unable to leave multicast group")
		} else if verbose {
			stdLog.Println("Leaving multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
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

	mc := JoinMulticast()
	if mc == nil {
		t.Fatal("Unable to join multicast group")
	} else if verbose {
		stdLog.Println("Joined and listening to multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
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

	e = mc.LeaveMulticast()
	if e != nil {
		t.Fatal("Unable to leave multicast group")
	} else if verbose {
		stdLog.Println("Node", id, "leaving multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
	}
}

func TestMulticastMessages(t *testing.T) {
	mc1 := JoinMulticast()
	if mc1 == nil {
		t.Fatal("Unable to join multicast group")
	}

	// Enable Multicast looping for testing
	f, err := mc1.Conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal("Unable to set socket for multicast looping")
	}

	mc1.Period = 1
	mc1.StartMulticast()
	mc1.ListenPeers()

	mc2 := JoinMulticast()
	if mc2 == nil {
		t.Fatal("Unable to join multicast group")
	}

	b := make([]byte, messageMaxSize)
	n, _, e := mc2.read(b)
	if e != nil {
		t.Fatal("Unable to multicast message")
	}
	if n > 0 {
		var msg MulticastMessage
		if e = json.Unmarshal(b[:n], &msg); e != nil || msg.Type != TypeHello {
			t.Fatal("Multicast Hello message is incorrectly formatted")
		}
	} else {
		stdLog.Println("Received 0 bytes")
	}

	e = mc2.LeaveMulticast()
	if e != nil {
		t.Fatal("Unable to leave multicast group")
	}
}

func TestMulticastAnnouncing(t *testing.T) {
	mc1 := JoinMulticast()
	if mc1 == nil {
		t.Fatal("Unable to join multicast group")
	}

	// Enable Multicast looping for testing
	f, err := mc1.Conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal("Unable to set socket for multicast looping")
	}

	mc1.Period = 1
	go mc1.sendHellos()

	mc2 := JoinMulticast()
	if mc2 == nil {
		t.Fatal("Unable to join multicast group")
	}

	mc2.StartMulticast()
	mc2.ListenPeers()

	time.Sleep(time.Millisecond * 1100) // Just enough to let the multicast run

	// Should be zero because we don't add ourselves to the peers map
	if len(mc2.peers) != 0 {
		t.Fatal("Wrong count of peers")
	}
}
