// package pubsub provides a global publish and subscribe infrastructure
// for lantern
package pubsub

import (
	"github.com/asaskevich/EventBus"
)

var (
	bus = EventBus.New()
)

func Pub(topic string, args ...interface{}) {
	bus.Publish(topic, args)
}

func Sub(topic string, fn interface{}) error {
	return bus.SubscribeAsync(topic, fn, true)
}
