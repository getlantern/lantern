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

func TestMulticast(t *testing.T) {
        mc1 := JoinMulticast()
        if mc1 == nil {
                t.Fatal()
        } else {
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
		log.Printf("--> Sent %d bytes: %s\n", n, msg)
                e = mc.LeaveMulticast()

                if e != nil {
                        t.Fatal(e)
                } else {
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
        } else {
		log.Println("Joined and listening to multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
	}

        b := make([]byte, 1000)
        n, e := mc.read(b)
        if e != nil {
                t.Fatal(e)
        }
        if n > 0 {
                log.Println("Node", id , "<-- Received", n, "bytes:", string(b))
        } else {
                log.Println("Received 0 bytes")
        }

        e = mc.LeaveMulticast()
        if e != nil {
                t.Fatal(e)
        } else {
		log.Println("Node", id, "leaving multicast IP", mc.Addr.IP, "on port", mc.Addr.Port)
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
	mc1.StartMulticast()

        mc2 := JoinMulticast()
        if mc2 == nil {
                t.Fatal()
        }

        b := make([]byte, 1000)
        n, e := mc2.read(b)
        if e != nil {
                t.Fatal(e)
        }
        if n > 0 {
                log.Println("<-- Received", n, "bytes:", string(b[:n]))
		host, _ := os.Hostname()
		addrs, _ := net.LookupIP(host)
		if string(helloMessage(addrs)) != string(b[:n]) {
			// Print bytes, not string, to see if any padding occurred
			fmt.Printf("%x\n",string(helloMessage(addrs)))
			fmt.Printf("%x\n",string(b[:n]))
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
