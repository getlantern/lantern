package ui

import (
	"encoding/json"
	"sync"
)

type envelopeType struct {
	Type string
}

type Service struct {
	Name    string
	In      chan []byte
	Out     chan []byte
	helloFn func(func([]byte) error) error
}

var (
	mu               sync.Mutex
	defaultUIChannel *UIChannel

	out      = make(chan []byte, 10)
	services = make(map[string]*Service)
)

func (s *Service) watch() {
	// Watch for new messages and sent them to the combined output.
	for b := range s.Out {
		out <- b
	}
}

func Register(name string, helloFn func(func([]byte) error) error) (*Service, error) {
	mu.Lock()

	if defaultUIChannel == nil {
		// Don't start until a service is registered.
		start()
	}

	if services[name] != nil {
		// Using panic because this would be a developer error rather that
		// something that could happen naturally.
		panic("Service was already registered.")
	}

	services[name] = &Service{
		Name: name,
		In:   make(chan []byte, 10),
		// We should probably use a buffered channel.
		Out:     make(chan []byte),
		helloFn: helloFn,
	}

	go services[name].watch()

	mu.Unlock()

	return services[name], nil
}

func start() {
	// Establish a channel to the UI for sending and receiving updates
	defaultUIChannel = NewChannel("/data", func(write func([]byte) error) error {
		// Sending hello messages.
		for _, s := range services {
			// Delegating task...
			if err := s.helloFn(write); err != nil {
				log.Errorf("Error writing to socket: %q", err)
			}
		}
		return nil
	})

	log.Debugf("Accepting websocket connections at: %s", defaultUIChannel.URL)
}

func read() {
	// Reading from the combined input.
	for b := range defaultUIChannel.In {
		// Determining message type.
		var env envelopeType
		err := json.Unmarshal(b, &env)

		if err != nil {
			log.Errorf("Unable to parse JSON update from browser: %q", err)
			continue
		}

		// Delegating response to the service that registered with the given type.
		if services[env.Type] != nil {
			// Pass this message and continue reading another one.
			go func() {
				services[env.Type].In <- b
			}()
		} else {
			log.Errorf("Message type %s belongs to an unkown service.", env.Type)
		}

	}
}
