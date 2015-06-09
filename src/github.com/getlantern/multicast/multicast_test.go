package multicast

import (
	"fmt"
	"log"
	"net"
	"os"
	"syscall"
	"sync"
	"testing"
	"time"
)

const verbose = false

func TestMulticast(t *testing.T) {
        mc1 := JoinMulticast()
        if mc1 == nil {
                t.Fatal()
        } else if verbose {
		log.Println("Joined and listening to multicast IP", mc1.Addr.IP, "on port", mc1.Addr.Port)
	}

	// Enable Multicast looping for testing
	f, err := mc1.Conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal(err)
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
                        t.Fatal(e)
                }

		if verbose {
			log.Printf("--> Sent %d bytes: %s\n", n, msg)
		}

                e = mc.LeaveMulticast()

                if e != nil {
                        t.Fatal(e)
                } else if verbose {
			log.Println("Leaving multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
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
                t.Fatal()
        } else if verbose {
		log.Println("Joined and listening to multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
	}

        b := make([]byte, 1000)
        n, _, e := mc.read(b)
        if e != nil {
                t.Fatal(e)
        }

        if n <= 0 {
		t.Fatal("No data received in multicast messages")
        }
	if verbose {
		log.Println("Node", id , "<-- Received", n, "bytes:", string(b))
	}

        e = mc.LeaveMulticast()
        if e != nil {
                t.Fatal(e)
        } else if verbose {
		log.Println("Node", id, "leaving multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
	}
}

func TestMulticastMessages(t *testing.T) {
	mc1 := JoinMulticast()
        if mc1 == nil {
                t.Fatal()
        }

	// Enable Multicast looping for testing
	f, err := mc1.Conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal(err)
	}

	mc1.Period = 1
	mc1.StartMulticast()

        mc2 := JoinMulticast()
        if mc2 == nil {
                t.Fail()
        }

        b := make([]byte, maxUDPMsg)
        n, _, e := mc2.read(b)
        if e != nil {
                t.Fatal(e)
        }
        if n > 0 {
		host, _ := os.Hostname()
		addrs, _ := net.LookupIP(host)
		if string(helloMessage(addrs)) != string(b[:n]) {
			// Print bytes, not string, to see if any padding occurred
			fmt.Printf("Expected: %x\n",string(helloMessage(addrs)))
			fmt.Printf("Received: %x\n",string(b[:n]))
			t.Fatal("Multicast Hello message is incorrectly formatted")
		}
        } else {
                log.Println("Received 0 bytes")
        }

        e = mc2.LeaveMulticast()
        if e != nil {
                t.Fatal(e)
        }
}


func TestMulticastAnnouncing(t *testing.T) {
	mc1 := JoinMulticast()
        if mc1 == nil {
                t.Fatal()
        }

	// Enable Multicast looping for testing
	f, err := mc1.Conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		t.Fatal(err)
	}

	mc1.Period = 1
	go mc1.sendHellos()

        mc2 := JoinMulticast()
        if mc2 == nil {
                t.Fatal()
        }

	mc2.StartMulticast()

	time.Sleep(time.Millisecond * 1100) // Just enough to let the multicast run

	// Should be zero because we don't add ourselves to the peers map
	if len(mc2.peers) != 0 {
		t.Fail()
	}
}
