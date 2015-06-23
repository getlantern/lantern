// Utility to test multicast discovery library in different devices

package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
	"github.com/getlantern/multicast"
)

func main() {
	log.Println("Multicast discovery utility running...")

	mc := multicast.JoinMulticast()

	f, err := mc.Conn.File()
	err = syscall.SetsockoptInt(int(f.Fd()), syscall.IPPROTO_IP, syscall.IP_MULTICAST_LOOP, 1)
	if err != nil {
		log.Fatal("Error setting up socket for multicast loop")
	}

	mc.Period = 1
	mc.AddPeerCallback = func(peer string) {
		log.Println("Added new peer:", peer)
	}
	mc.RemovePeerCallback = func(peer string) {
		log.Println("Removed peer:", peer)
	}
	mc.StartMulticast()

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func(){
		<- c
		log.Println("Leaving multicast group...")
		mc.LeaveMulticast()
		log.Println("Quitting multicast discovery...")
		os.Exit(0)
	}()

	// Sleep forever in main goroutine
	select{}
}
