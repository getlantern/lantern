EventBus
======
[![GoDoc](https://godoc.org/github.com/asaskevich/EventBus?status.svg)](https://godoc.org/github.com/asaskevich/EventBus) [![Coverage Status](https://img.shields.io/coveralls/asaskevich/EventBus.svg)](https://coveralls.io/r/asaskevich/EventBus?branch=master) [![Build Status](https://travis-ci.org/asaskevich/EventBus.svg)](https://travis-ci.org/asaskevich/EventBus)

Package EventBus is the little and lightweight eventbus with async compatibility for GoLang.

#### Installation
Make sure that Go is installed on your computer.
Type the following command in your terminal:

	go get github.com/asaskevich/EventBus

After it the package is ready to use.

#### Import package in your project
Add following line in your `*.go` file:
```go
import "github.com/asaskevich/EventBus"
```
If you unhappy to use long `EventBus`, you can do something like this:
```go
import (
	evbus "github.com/asaskevich/EventBus"
)
```

#### Example
```go
func calculator(a int, b int) {
	fmt.Printf("%d\n", a + b)
}

func main() {
	bus := EventBus.New();
	bus.Subscribe("main:calculator", calculator);
	bus.Publish("main:calculator", 20, 40);
	bus.Unsubscribe("main:calculator");
}
```

#### Implemented methods
* **New()**
* **Subscribe()**
* **SubscribeOnce()**
* **HasCallback()**
* **Unsubscribe()**
* **Publish()**
* **SubscribeAsync()**
* **SubscribeOnceAsync()**
* **WaitAsync()**

#### New()
New returns new EventBus with empty handlers.
```go
bus := EventBus.New();
```

#### Subscribe(topic string, fn interface{}) error
Subscribe to a topic. Returns error if `fn` is not a function.
```go
func Handler() { ... }
...
bus.Subscribe("topic:handler", Handler)
```

#### SubscribeOnce(topic string, fn interface{}) error
Subscribe to a topic once. Handler will be removed after executing. Returns error if `fn` is not a function.
```go
func HelloWorld() { ... }
...
bus.SubscribeOnce("topic:handler", HelloWorld)
```

#### Unsubscribe(topic string) error
Remove callback defined for a topic. Returns error if there are no callbacks subscribed to the topic.
```go
bus.Unsubscribe("topic:handler");
```

#### HasCallback(topic string) bool
Returns true if exists any callback subscribed to the topic.

#### Publish(topic string, args ...interface{})
Publish executes callback defined for a topic. Any addional argument will be tranfered to the callback.
```go
func Handler(str string) { ... }
...
bus.Subscribe("topic:handler", Handler)
...
bus.Publish("topic:handler", "Hello, World!");
```

#### SubscribeAsync(topic string, fn interface{}, transactional bool)
Subscribe to a topic with an asyncrhonous callback. Returns error if `fn` is not a function.
```go
func slowCalculator(a, b int) {
	time.Sleep(3 * time.Second)
	fmt.Printf("%d\n", a + b)
}

bus := EventBus.New()
bus.SubscribeAsync("main:slow_calculator", slowCalculator, false)
	
bus.Publish("main:slow_calculator", 20, 60)
	
fmt.Println("start: do some stuff while waiting for a result")
fmt.Println("end: do some stuff while waiting for a result") 
	
bus.WaitAsync() // wait for all async callbacks to complete
	
fmt.Println("do some stuff after waiting for result") 
```
Transactional determines whether subsequent callbacks for a topic are run serially (true) or concurrently(false)

#### SubscribeOnceAsync(topic string, args ...interface{})
SubscribeOnceAsync works like SubscribeOnce except the callback to executed asynchronously

####  WaitAsync()
WaitAsync waits for all async callbacks to complete.

#### Notes
Documentation is available here: [godoc.org](https://godoc.org/github.com/asaskevich/EventBus).
Full information about code coverage is also available here: [EventBus on gocover.io](http://gocover.io/github.com/asaskevich/EventBus).

#### Support
If you do have a contribution for the package feel free to put up a Pull Request or open Issue.

#### Special thanks to [contributors](https://github.com/asaskevich/EventBus/graphs/contributors)
* [Brian Downs](https://github.com/briandowns)
* [Dominik Schulz](https://github.com/gittex)
* [bennAH](https://github.com/bennAH)
