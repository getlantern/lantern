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

func Pub(topic interface{}, args ...interface{}) {
	bus.Publish(reflect.TypeOf(topic).String(), topic)
}

func Sub(topic interface{}, fn interface{}) error {
	return bus.SubscribeAsync(reflect.TypeOf(topic).String(), fn, true)
}
