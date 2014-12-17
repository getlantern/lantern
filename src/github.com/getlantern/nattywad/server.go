package nattywad

import (
	"fmt"
	"net"
	"sync"

	"github.com/getlantern/go-natty/natty"
	"github.com/getlantern/waddell"
)

// ServerSuccessCallback is a function that gets invoked when a server NAT
// traversal results in a UDP five tuple. The function allows the consumer of
// nattywad to bind to the resulting local and remote addresses and start
// whatever processing it needs to. ServerSuccessCallback should return true to
// indicate that the server is bound and ready, which will cause nattywad to
// emit a ServerReady message. Only once this has happened will the client on
// the other side of the NAT traversal actually get a five tuple through its
// own callback.
type ServerSuccessCallback func(local *net.UDPAddr, remote *net.UDPAddr) bool

// ServerFailureCallback is a function that gets invoked when a server NAT
// traversal fails for any reason.
type ServerFailureCallback func(err error)

// Server is a server that answers NAT traversal requests received via waddell.
// When a NAT traversal results in a 5-tuple, the OnFiveTuple callback is
// called.
type Server struct {
	// Client: the waddell Client that this server uses to communicate with
	// waddell.
	Client *waddell.Client

	// OnSuccess: a callback that's invoked once a five tuple has been
	// obtained. Must be specified in order for Server to work.
	OnSuccess ServerSuccessCallback

	// OnFailure: a optional callback that's invoked when a NAT traversal fails.
	// If unpopulated, failures aren't reported.
	OnFailure ServerFailureCallback

	stopCh chan interface{}
	peers  map[waddell.PeerId]*peer
}

func (s *Server) Start() {
	s.stopCh = make(chan interface{}, 1)
	s.peers = make(map[waddell.PeerId]*peer)
	go s.receiveMessages()
}

func (s *Server) Stop() {
	s.stopCh <- nil
}

func (s *Server) receiveMessages() {
	in := s.Client.In(NattywadTopic)
	for {
		select {
		case <-s.stopCh:
			return
		default:
			wm, ok := <-in
			if !ok {
				log.Errorf("Done receiving messages from waddell")
				s.stopCh <- nil
			}
			s.processMessage(message(wm.Body), wm.From)
		}
	}
}

func (s *Server) processMessage(msg message, from waddell.PeerId) {
	p := s.peers[from]
	if p == nil {
		p = &peer{
			id:         from,
			wc:         s.Client,
			traversals: make(map[traversalId]*natty.Traversal),
			onSuccess:  s.OnSuccess,
			onFailure:  s.OnFailure,
		}
		s.peers[from] = p
	}
	p.answer(msg)
}

type peer struct {
	id              waddell.PeerId
	wc              *waddell.Client
	onSuccess       ServerSuccessCallback
	onFailure       ServerFailureCallback
	traversals      map[traversalId]*natty.Traversal
	traversalsMutex sync.Mutex
}

func (p *peer) answer(msg message) {
	p.traversalsMutex.Lock()
	defer p.traversalsMutex.Unlock()
	traversalId := msg.getTraversalId()
	t := p.traversals[traversalId]
	if t == nil {
		// Set up a new Natty traversal
		t = natty.Answer(Timeout)
		out := p.wc.Out(NattywadTopic)
		go func() {
			// Send
			for {
				msgOut, done := t.NextMsgOut()
				if done {
					return
				}
				out <- waddell.Message(p.id, traversalId.toBytes(), []byte(msgOut))
			}
		}()

		go func() {
			// Receive
			defer func() {
				p.traversalsMutex.Lock()
				defer p.traversalsMutex.Unlock()
				delete(p.traversals, traversalId)
				err := t.Close()
				if err != nil {
					log.Debugf("Unable to close traversal: %s", err)
				}
			}()

			ft, err := t.FiveTuple()
			if err != nil {
				p.fail("Unable to answer traversal %d: %s", traversalId, err)
				return
			}

			local, remote, err := ft.UDPAddrs()
			if err != nil {
				p.fail("Unable to get UDP addresses for FiveTuple: %s", err)
				return
			}

			if p.onSuccess(local, remote) {
				// Server is ready, notify client
				out <- waddell.Message(p.id, traversalId.toBytes(), []byte(ServerReady))
			}
		}()
		p.traversals[traversalId] = t
	}
	t.MsgIn(string(msg.getData()))
}

func (p *peer) fail(message string, args ...interface{}) {
	err := fmt.Errorf(message, args...)
	log.Debug(err)
	if p.onFailure != nil {
		p.onFailure(err)
	}
}
