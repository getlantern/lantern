package nattywad

import (
	"net"
	"sync"
	"testing"

	"github.com/davecgh/go-spew/spew"
	"github.com/getlantern/testify/assert"
	"github.com/getlantern/waddell"
)

// TestRoundTrip is an integration test that tests a round trip with client and
// server, using a waddell server in the cloud.
func TestRoundTrip(t *testing.T) {
	// Start a waddell server
	wserver := &waddell.Server{}
	laddr := "localhost:0"
	log.Debugf("Starting waddell at %s", laddr)
	listener, err := net.Listen("tcp", laddr)
	if err != nil {
		t.Fatalf("Unable to listen at %s: %s", laddr, err)
	}
	waddr := listener.Addr().String()

	go func() {
		err = wserver.Serve(listener)
		if err != nil {
			t.Fatalf("Unable to start waddell at %s: %s", waddr, err)
		}
	}()

	var wg sync.WaitGroup
	wg.Add(2)

	serverIdCh := make(chan waddell.PeerId)

	wc, err := waddell.NewClient(&waddell.ClientConfig{
		Dial: func() (net.Conn, error) {
			return net.Dial("tcp", waddr)
		},
		OnId: func(id waddell.PeerId) {
			serverIdCh <- id
		},
	})
	if err != nil {
		t.Fatalf("Unable to start waddell client: %s", err)
	}

	server := &Server{
		Client: wc,
		OnSuccess: func(local *net.UDPAddr, remote *net.UDPAddr) bool {
			log.Debugf("Success! %s -> %s", local, remote)
			wg.Done()
			return true
		},
		OnFailure: func(err error) {
			t.Errorf("Server - Traversal failed: %s", err)
			wg.Done()
		},
	}
	server.Start()

	clientMgr := &waddell.ClientMgr{
		Dial: func(addr string) (net.Conn, error) {
			return net.Dial("tcp", addr)
		},
		ReconnectAttempts: 10,
	}

	client := &Client{
		ClientMgr: clientMgr,
		OnSuccess: func(info *TraversalInfo) {
			log.Debugf("Client - Success! %s", spew.Sdump(info))
			wg.Done()
		},
		OnFailure: func(info *TraversalInfo) {
			t.Errorf("Client - Traversal failed: %s", spew.Sdump(info))
			wg.Done()
		},
	}
	serverId := <-serverIdCh
	client.Configure([]*ServerPeer{&ServerPeer{
		ID:          serverId.String(),
		WaddellAddr: waddr,
	}})

	wg.Wait()
	assert.Empty(t, client.workers, "No workers should be left")
}
