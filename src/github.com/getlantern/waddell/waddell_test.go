package waddell

import (
	"fmt"
	"io/ioutil"
	"math/rand"
	"net"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/testify/assert"
)

const (
	Hello         = "Hello"
	HelloYourself = "Hello %s!"

	NumPeers = 100

	TestTopic = TopicId(1)
)

// TestPeerIdRoundTrip makes sure that we can write and read a PeerId to/from a
// byte array.
func TestPeerIdRoundTrip(t *testing.T) {
	b := make([]byte, PeerIdLength)
	orig := randomPeerId()
	orig.write(b)
	read, err := readPeerId(b)
	if err != nil {
		t.Errorf("Unable to read peer id: %s", err)
	} else {
		assert.Equal(t, orig, read)
	}
}

func TestPeerIdStringRoundTrip(t *testing.T) {
	orig := randomPeerId()
	read, err := PeerIdFromString(orig.String())
	if err != nil {
		t.Errorf("Unable to read peer id: %s", err)
	} else {
		assert.Equal(t, orig, read)
	}
}

func TestTopicIdRoundTrip(t *testing.T) {
	orig := TopicId(5)
	read, err := readTopicId(orig.toBytes())
	if err != nil {
		t.Errorf("Error reading topic id: %s", err)
	} else {
		assert.Equal(t, orig, read)
	}
}

func TestTopicIdTruncation(t *testing.T) {
	orig := TopicId(5)
	_, err := readTopicId(orig.toBytes()[:1])
	assert.Error(t, err)
}

func TestBadDialerWithNoReconnect(t *testing.T) {
	cfg := &ClientConfig{
		ReconnectAttempts: 0,
		Dial: func() (net.Conn, error) {
			return nil, fmt.Errorf("I won't dial, no way!")
		},
	}
	client, err := NewClient(cfg)
	assert.Error(t, err, "Connecting with no reconnect attempts should have failed")
	if err == nil {
		client.Close()
	}
}

func TestBadDialerWithMultipleReconnect(t *testing.T) {
	cfg := &ClientConfig{
		ReconnectAttempts: 2,
		Dial: func() (net.Conn, error) {
			return nil, fmt.Errorf("I won't dial, no way!")
		},
	}
	start := time.Now()
	client, err := NewClient(cfg)
	defer client.Close()
	delta := time.Now().Sub(start)
	assert.Error(t, err, "Connecting with 2 reconnect attempts should have failed")
	expectedDelta := reconnectDelayInterval * 3
	assert.True(t, delta >= expectedDelta, fmt.Sprintf("Reconnecting didn't wait long enough. Should have waited %s, only waited %s", expectedDelta, delta))
}

func TestPeersPlainText(t *testing.T) {
	doTestPeers(t, false)
}

func TestPeersTLS(t *testing.T) {
	doTestPeers(t, true)
}

func doTestPeers(t *testing.T, useTLS bool) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	closeActions := make([]func(), 0)
	peers := make([]*Client, 0, NumPeers)
	defer func() {
		for _, action := range closeActions {
			action()
		}

		// Wait a short time to let sockets finish closing
		time.Sleep(250 * time.Millisecond)
		assert.NoError(t, fdc.AssertDelta(0), "All file descriptors should have been closed")

		// Make sure we can't do stuff with closed client
		client := peers[0]

		err := client.SendKeepAlive()
		assert.Error(t, err, "Attempting to SendKeepAlive on closed client should fail")

		// Make sure we can't obtain in or out topics after closing clients
		defer func() {
			defer func() {
				if r := recover(); r != nil {
					log.Tracef("Recovered: %v", r)
				}
			}()
			client.In(TestTopic)
			t.Error("Attempting to get in topic on closed client should have panicked")
		}()

		defer func() {
			defer func() {
				if r := recover(); r != nil {
					log.Tracef("Recovered: %v", r)
				}
			}()
			client.Out(TestTopic)
			t.Error("Attempting to get out topic on closed client should have panicked")
		}()
	}()

	pkfile := ""
	certfile := ""
	cert := ""
	if useTLS {
		pkfile = "waddell_test_pk.pem"
		certfile = "waddell_test_cert.pem"
		certBytes, err := ioutil.ReadFile(certfile)
		if err != nil {
			log.Fatalf("Unable to read cert from file: %s", err)
		}
		cert = string(certBytes)
	}

	listener, err := Listen("localhost:0", pkfile, certfile)
	if err != nil {
		log.Fatalf("Unable to listen: %s", err)
	}

	go func() {
		server := &Server{}
		err = server.Serve(listener)
	}()

	serverAddr := listener.Addr().String()

	succeedOnDial := int32(0)
	dial := func() (net.Conn, error) {
		if atomic.CompareAndSwapInt32(&succeedOnDial, 0, 1) {
			return nil, fmt.Errorf("Deliberately failing the first time around")
		}
		return net.Dial("tcp", serverAddr)
	}

	idCallbackTriggered := int32(0)
	connect := func() *Client {
		cfg := &ClientConfig{
			Dial:              dial,
			ServerCert:        cert,
			ReconnectAttempts: 1,
			OnId: func(id PeerId) {
				atomic.AddInt32(&idCallbackTriggered, 1)
			},
		}
		client, err := NewClient(cfg)
		if err != nil {
			log.Fatalf("Unable to connect client: %s", err)
		}
		return client
	}

	peersCh := make(chan *Client, NumPeers)
	// Connect clients
	for i := 0; i < NumPeers; i++ {
		go func() {
			peer := connect()
			assert.NoError(t, err, "Unable to connect peer")
			peersCh <- peer
		}()
	}

	for i := 0; i < NumPeers; i++ {
		peer := <-peersCh
		peers = append(peers, peer)
		closeActions = append(closeActions, func() {
			err := peer.Close()
			assert.NoError(t, err, "Closing client shouldn't result in error")
		})
	}

	var wg sync.WaitGroup
	wg.Add(NumPeers)

	// Send some large data to a peer that doesn't read, just to make sure we
	// handle blocked readers okay

	// We include ClientMgr here to test it, not because it's convenient
	var cbAddr string
	var cbId PeerId
	var cbMutex sync.Mutex
	clientMgr := &ClientMgr{
		Dial: func(addr string) (net.Conn, error) {
			return net.Dial("tcp", addr)
		},
		ServerCert:        cert,
		ReconnectAttempts: 1,
		OnId: func(addr string, id PeerId) {
			cbMutex.Lock()
			defer cbMutex.Unlock()
			cbAddr = addr
			cbId = id
		},
	}
	closeActions = append(closeActions, func() {
		errs := clientMgr.Close()
		assert.Nil(t, errs, "Closing clientMgr shouldn't result in errors")
	})

	badPeer, err := clientMgr.ClientTo(serverAddr)
	if err != nil {
		log.Fatalf("Unable to connect bad peer: %s", err)
	}
	cbMutex.Lock()
	badPeerId := badPeer.CurrentId()
	assert.Equal(t, serverAddr, cbAddr, "IdCallback should have recorded the server's addr")
	assert.Equal(t, badPeerId, cbId, "IdCallback should have recorded the correct id")
	cbMutex.Unlock()
	ld := largeData()
	for i := 0; i < 10; i++ {
		if err != nil {
			log.Fatalf("Unable to get peer id: %s", err)
		}
		badPeer.Out(TestTopic) <- Message(badPeerId, ld)
	}

	// Simulate readers and writers
	for i := 0; i < NumPeers; i++ {
		peer := peers[i]
		isWriter := i%2 == 1

		if isWriter {
			go func() {
				// Simulate writer
				defer wg.Done()

				// Write to each reader
				for j := 0; j < NumPeers; j += 2 {
					recip := peers[j]
					peer.Out(TestTopic) <- Message(recip.CurrentId(), []byte(Hello[:2]), []byte(Hello[2:]))
					if err != nil {
						log.Fatalf("Unable to write hello: %s", err)
					} else {
						resp := <-peer.In(TestTopic)
						assert.Equal(t, fmt.Sprintf(HelloYourself, peer.CurrentId()), string(resp.Body), "Response should match expected.")
						assert.Equal(t, recip.CurrentId(), resp.From, "Peer on response should match expected")
					}
				}
			}()
		} else {
			go func() {
				// Simulate reader
				defer wg.Done()

				// Read from all readers
				for j := 1; j < NumPeers; j += 2 {
					err := peer.SendKeepAlive()
					if err != nil {
						log.Fatalf("Unable to send KeepAlive: %s", err)
					}
					msg := <-peer.In(TestTopic)
					assert.Equal(t, Hello, string(msg.Body), "Hello message should match expected")
					peer.Out(TestTopic) <- Message(msg.From, []byte(fmt.Sprintf(HelloYourself, msg.From)))
					if err != nil {
						log.Fatalf("Unable to write response to HELLO message: %s", err)
					}
				}
			}()
		}
	}

	wg.Wait()

	// Close server last
	closeActions = append(closeActions, func() {
		err := listener.Close()
		assert.NoError(t, err, "Closing listener shouldn't fail")
	})
	assert.Equal(t, NumPeers, idCallbackTriggered, "IdCallback should have been called once for each connected peer")
}

func largeData() []byte {
	b := make([]byte, 60000)
	for i := 0; i < len(b); i++ {
		b[i] = byte(rand.Int())
	}
	return b
}
