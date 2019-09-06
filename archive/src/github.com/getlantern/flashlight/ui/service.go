package ui

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"
)

type helloFnType func(func(interface{}) error) error

type Service struct {
	Type    string
	In      <-chan interface{}
	Out     chan<- interface{}
	in      chan interface{}
	out     chan interface{}
	stopCh  chan bool
	helloFn helloFnType
}

var (
	mu               sync.RWMutex
	defaultUIChannel *UIChannel

	services = make(map[string]*Service)
)

func (s *Service) write() {
	// Watch for new messages and send them to the combined output.
	for {
		select {
		case <-s.stopCh:
			log.Trace("Received message on stop channel")
			return
		case msg := <-s.out:
			log.Tracef("Creating new envelope for %v", s.Type)
			b, err := newEnvelope(s.Type, msg)
			if err != nil {
				log.Error(err)
				continue
			}
			defaultUIChannel.Out <- b
		}
	}
}

func Register(t string, helloFn helloFnType) (*Service, error) {
	log.Tracef("Registering UI service %s", t)
	mu.Lock()

	if services[t] != nil {
		// Using panic because this would be a developer error rather that
		// something that could happen naturally.
		panic("Service was already registered.")
	}

	if defaultUIChannel == nil {
		// Don't start until a service is registered.
		start()
	}

	s := &Service{
		Type:    t,
		in:      make(chan interface{}, 100),
		out:     make(chan interface{}, 100),
		stopCh:  make(chan bool),
		helloFn: helloFn,
	}
	s.In, s.Out = s.in, s.out

	// Sending existent clients the hello message of the new service.
	if helloFn != nil {
		err := helloFn(func(msg interface{}) error {
			b, err := newEnvelope(s.Type, msg)
			if err != nil {
				return err
			}
			log.Tracef("Sending initial message to existent clients")
			defaultUIChannel.Out <- b
			return nil
		})
		if err != nil {
			log.Debugf("Error running Hello function", err)
		}
	}

	// Adding new service to service map.
	services[t] = s
	mu.Unlock()

	log.Tracef("Registered UI service %s", t)
	go s.write()
	return s, nil
}

func Unregister(t string) {
	log.Tracef("Unregistering service: %v", t)
	if services[t] != nil {
		services[t].stopCh <- true
		delete(services, t)
	}
}

func start() {
	// Establish a channel to the UI for sending and receiving updates
	defaultUIChannel = NewChannel("/data", func(write func([]byte) error) error {
		// Sending hello messages.
		mu.RLock()
		for _, s := range services {
			writer := func(msg interface{}) error {
				b, err := newEnvelope(s.Type, msg)
				if err != nil {
					return err
				}
				return write(b)
			}

			// Delegating task...
			if s.helloFn != nil {
				if err := s.helloFn(writer); err != nil {
					log.Errorf("Error writing to socket: %q", err)
				}
			}
		}
		mu.RUnlock()
		return nil
	})

	go read()

	log.Debugf("Accepting websocket connections at: %s", defaultUIChannel.URL)
}

func read() {
	// Reading from the combined input.
	for b := range defaultUIChannel.In {
		log.Tracef("Got incoming message from UI for %v", defaultUIChannel.URL)
		// Determining message type.
		var envType EnvelopeType
		err := json.Unmarshal(b, &envType)

		if err != nil {
			log.Errorf("Unable to parse JSON update from browser: %q", err)
			continue
		}

		// Delegating response to the service that registered with the given type.
		if services[envType.Type] == nil {
			log.Errorf("Message type %v belongs to an unknown service.", envType.Type)
			continue
		}

		env := &Envelope{}
		d := json.NewDecoder(strings.NewReader(string(b)))
		d.UseNumber()
		err = d.Decode(env)
		if err != nil {
			log.Errorf("Unable to unmarshal message of type %v: %v", envType.Type, err)
			continue
		}
		log.Tracef("Forwarding message: %v", env)
		// Pass this message and continue reading another one.
		services[env.Type].in <- env.Message
	}
}

func newEnvelope(t string, msg interface{}) ([]byte, error) {
	b, err := json.Marshal(&Envelope{
		EnvelopeType: EnvelopeType{t},
		Message:      msg,
	})
	if err != nil {
		return nil, fmt.Errorf("Unable to marshal message of type %v: %v", t, msg)
	}
	return b, nil
}
