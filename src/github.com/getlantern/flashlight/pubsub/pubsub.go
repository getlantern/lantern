// package pubsub provides a global publish and subscribe infrastructure
// for lantern
package pubsub

import (
	"reflect"

	"github.com/asaskevich/EventBus"
)

var (
	bus = EventBus.New()
)

// Pub publishes the given interface to any listeners for that interface.
func Pub(topic interface{}) {
	bus.Publish(reflect.TypeOf(topic).String(), topic)
}

// Sub subscribes to specific interfaces with the specified callback
// function.
func Sub(topic interface{}, fn interface{}) error {
	return bus.SubscribeAsync(reflect.TypeOf(topic).String(), fn, true)
}
