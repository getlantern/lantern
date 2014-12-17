# EventSource for Go [![Build Status](https://travis-ci.org/msgehard/goEventSource.png?branch=master)](https://travis-ci.org/msgehard/goEventSource)

This library is an initial implementation of Server Sent Events(SSE)/EventSource for Go.
It is patterned after the [Go Websockets](https://code.google.com/p/go/source/browse/?repo=net#hg%2Fwebsocket) library.
It is very much a work in progress. Pull requests welcome.

## Example app

Found in the examples directory. You can run it from the examples directory with:

```
go run main.go
```


## Development
  
Please write tests for any code that you add. To run existing tests:

```
  bin/test
```

## References

For more information about SSE/EventSource, see:

[http://en.wikipedia.org/wiki/Server-sent_events](http://en.wikipedia.org/wiki/Server-sent_events)

[http://www.html5rocks.com/en/tutorials/eventsource/basics/](http://www.html5rocks.com/en/tutorials/eventsource/basics/)
