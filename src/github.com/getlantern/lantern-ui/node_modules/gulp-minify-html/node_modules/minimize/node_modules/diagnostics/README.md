# Diagnostics

[![Build Status](https://travis-ci.org/3rd-Eden/diagnostics.svg?branch=master)](https://travis-ci.org/3rd-Eden/diagnostics)

Diagnostics provides a set of tools that is designed to help you with debugging
your Node.js and front-end applications. 

## Installation

```
npm install --save diagnostics
```

We're starting out small but every major release will unlock another piece of
the puzzle. The following tools are already at your disposal: 

## Logging

Logging is something you always need in your applications, if you don't know
what's going on, it's damn hard to fix it. This is especially true with async
systems when your stack traces are most likely completely useless. In
diagnostics we ship a simple logger which can be turned on and off using
environment variables. So it's out of the way for your users and there when you
need it.

The logger is exposed as function:

```js
var log = require('diagnostics')('example');

log('foo %s', 'bar');
```

The first argument in the function is the namespace of you log function. All log
message will be prefixed with. But we also allow a second argument. This can be
used to configure the logger. The following options can be configured:

- `color`: The color for the namespace, this can be a hex (#FFF) color string or
  the name of a color. If no color is provided we will generate consistently
  hashed color from the given namespace and use that instead.
- `color**s**`: Forcefully enable or disable the use of colors in the log
  output. If no `colors` boolean is provided we will determine if it's a proper
  tty and show colors.
- `stream`: The stream instance we should write our logs to. We default to
  `process.stdout` (unless you change the default using the `.to` method).
- `precise`: By default our log timing is rounded up to the nearest number. If
  you need more precise timing you can set this option to true.

#### Multiple streams

The beauty of this logger is that it allows a custom stream where you can write
the data to. So you can just log it all to a separate server, database and what
not. But we don't just allow one stream we allow multiple streams so you might
want to log to disk AND just output it in your terminal. The only thing you need
to do is either use:

```js
require('diagnostics').to([
  stream1,
  stream2
]);
```

To set multiple streams as the default streams or supply an array for the logger
it self:

```js
var log = require('diagnostics')('example', { stream: [
  stream1,
  stream2
]});

log('foo');
```

In addition to using the `DEBUG` environment variable you can also the
`DIAGNOSTICS` environment variable.

## License

MIT
