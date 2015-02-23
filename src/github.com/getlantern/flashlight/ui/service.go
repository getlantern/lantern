package ui

import (
	"encoding/json"
	"fmt"
	"sync"
)

type helloFnType func(func(interface{}) error) error

type Service struct {
	Type       string
	In         <-chan interface{}
	Out        chan<- interface{}
	in         chan interface{}
	out        chan interface{}
	newMessage func() interface{}
	helloFn    helloFnType
}

var (
	mu               sync.RWMutex
	defaultUIChannel *UIChannel

	services = make(map[string]*Service)
)

func (s *Service) write() {
	// Watch for new messages and send them to the combined output.
	for msg := range s.out {
		b, err := newEnvelope(s.Type, msg)
		if err != nil {
			log.Error(err)
			continue
		}
		defaultUIChannel.Out <- b
	}
}

func Register(t string, newMessage func() interface{}, helloFn helloFnType) (*Service, error) {
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
		Type:       t,
		in:         make(chan interface{}, 100),
		out:        make(chan interface{}, 100),
		newMessage: newMessage,
		helloFn:    helloFn,
	}
	s.In, s.Out = s.in, s.out

	// Sending existent clients the hello message of the new service.
	if helloFn != nil {
		helloFn(func(msg interface{}) error {
			b, err := newEnvelope(s.Type, msg)
			if err != nil {
				return err
			}
			log.Tracef("Sending initial message to existent clients: %q", b)
			defaultUIChannel.Out <- b
			return nil
		})
	}

	// Adding new service to service map.
	services[t] = s
	mu.Unlock()

	go s.write()
	return s, nil
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
			if err := s.helloFn(writer); err != nil {
				log.Errorf("Error writing to socket: %q", err)
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
		// Determining message type.
		var envType EnvelopeType
		err := json.Unmarshal(b, &envType)

		if err != nil {
			log.Errorf("Unable to parse JSON update from browser: %q", err)
			continue
		}

		// Delegating response to the service that registered with the given type.
		if services[envType.Type] == nil {
			log.Errorf("Message type %v belongs to an unkown service.", envType.Type)
			return
		}

		env := &Envelope{}
		err = json.Unmarshal(b, env)
		if err != nil {
			log.Errorf("Unable to unmarshal message of type %v: %v", envType.Type, err)
			return
		}
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
