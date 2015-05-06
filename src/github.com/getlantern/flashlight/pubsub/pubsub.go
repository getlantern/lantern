// package pubsub provides a global publish and subscribe infrastructure
// for lantern
package pubsub

import (
	"strconv"

	"github.com/asaskevich/EventBus"
)

var (
	bus = EventBus.New()
)

const (
	Location = iota
)

// Pub publishes the given interface to any listeners for that interface.
func Pub(topic int, data interface{}) {
	bus.Publish(strconv.Itoa(topic), data)
}

// Sub subscribes to specific interfaces with the specified callback
// function.
func Sub(topic int, fn interface{}) error {
	return bus.SubscribeAsync(strconv.Itoa(topic), fn, true)
}
