# emits

[![Version npm](http://img.shields.io/npm/v/emits.svg?style=flat-square)](http://browsenpm.org/package/emits)[![Build Status](http://img.shields.io/travis/primus/emits/master.svg?style=flat-square)](https://travis-ci.org/primus/emits)[![Dependencies](https://img.shields.io/david/primus/emits.svg?style=flat-square)](https://david-dm.org/primus/emits)[![Coverage Status](http://img.shields.io/coveralls/primus/emits/master.svg?style=flat-square)](https://coveralls.io/r/primus/emits?branch=master)[![IRC channel](http://img.shields.io/badge/IRC-irc.freenode.net%23primus-00a8ff.svg?style=flat-square)](http://webchat.freenode.net/?channels=primus)

## Installation

This module is compatible with browserify and node.js and is therefore released
through npm:

```
npm install --save emits
```

## Usage

In all examples we assume that you've assigned the `emits` function to the
prototype of your class. This class should inherit from an `EventEmitter` class
which uses the `emit` function to emit events and the `listeners` method to list
the listeners of a given event. For example:

```js
'use strict';

var EventEmitter = require('events').EventEmitter
  , emits = require('emits');

function Example() {
  EventEmitter.call(this);
}

require('util').inherits(Example, EventEmitter);

//
// You can directly assign the function to the prototype if you wish or store it
// in a variable and then assign it to the prototype. What pleases you more.
//
Example.prototype.emits = emits; // require('emits');

//
// Also initialize the example so we can use the assigned method.
//
var example = new Example();
```

Now that we've set up our example code we can finally demonstrate the beauty of
this functionality. To create a function that emits `data` we can simply do:

```js
var data = example.emits('data');
```

Every time you invoke the `data()` function it will emit the `data` event with
all the arguments you supplied. If you want to "curry" some extra arguments you
can add those after the event name:

```js
var data = example.emits('data', 'foo');
```

Now when you call `data()` the `data` event will receive `foo` as first argument
and the rest of the arguments would be the ones that you've supplied to the
`data()` function.

If you supply a function as last argument we assume that this is an argument
parser. This allows you to modify arguments, prevent the emit of the event or
just clear all supplied arguments (except for the ones that are curried in).

```js
var data = example.emits('data', function parser(arg) {
  return 'bar';
})
```

In the example above we've transformed the incoming argument to `bar`. So when
you call `data()` it will emit a `data` event with `bar` as the only argument.

To prevent the emitting from happening you need to return the `parser` function
that you supplied. This is the only reliable way to determine if we need to
prevent an emit:

```js
var data = example.emits('data', function parser() {
  return parser;
});
```

If you return `undefined` from the parser we assume that no modification have
been made to the arguments and we should emit our received arguments. If `null`
is returned we assume that all received arguments should be removed.

### Patterns

In Primus the most common pattern for this module is to proxy events from one
instance to another:

```js
eventemitter.on('data', example.emits('data'));
```

It is also very useful to re-format data. For example, in the case of WebSockets,
if we don't want to reference `evt.data` every time we need to access the data,
we can parse the argument as following:

```js
var ws = new WebSocket('wss://example.org/path');
ws.onmessage = example.emits('data', function parser(evt) {
  return evt.data;
});
```

In the example above we will now emit the `data` event with a direct reference
to `evt.data`. The following final example shows how you can prevent events
from being emitted.

```js
var ws = new WebSocket('wss://example.org/path');
ws.onmessage = example.emits('data', function parser(evt) {
  var data;

  try { data = JSON.parse(evt.data); }
  catch (e) { return parser; }

  if ('object' !== typeof data || Array.isArray(data)) {
    return parser;
  }

  return data;
});
```

By returning a reference to the parser we tell the emit function that we
don't want to emit the event. So the `data` event will only be fired if
we've received a valid JSON document from the server and it's an object.

## License

MIT
