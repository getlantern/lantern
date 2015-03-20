### 1.0.1 / 2013-12-10

* Add `Adapter#close()` method for gracefully shutting down the server
* Fix error recover bug in WebSocket that made transport cycle through `up`/`down` state
* Update Promise implementation to pass `promises-aplus-tests 2.0`
* Correct some incorrect variable names in the Ruby transports
* Make logging methods public to fix a problem on Ruby 2.1


### 1.0.0 / 2013-10-01

* Client changes:
  * Allow clients to be instantiated with URI objects rather than strings
  * Add a `ca` option to the Node `Client` class for passing in trusted server certificates
  * Objects supporting the `callback()` method in JavaScript are now Promises
  * Fix protocol-relative URI parsing in the client
  * Remove the `getClientId()` and `getState()` methods from the `Client` class
* Transport changes:
  * Add request-size limiting to all batching transports
  * Make the WebSocket transport more robust against quiet network periods and clients going to sleep
  * Support cookies across all transports when using the client on Node.js or Ruby
  * Support custom headers in the `cross-origin-long-polling` and server-side `websocket` transports
* Adapter changes:
  * Support the `rack.hijack` streaming API
  * Migrate to MultiJson for JSON handling on Ruby, allowing use of JRuby
  * Escape U+2028 and U+2029 in JSON-P output
  * Fix a bug stopping requests being routed when the mount point is `/`
  * Fix various bugs that cause errors to be thrown if we try to send a message over a closed socket
  * Remove the `listen()` method from `Adapter` in favour of using server-specific APIs
* Server changes:
  * Use cryptographically secure random number generators to create client IDs
  * Allow extensions to access request properties by using 3-ary methods
  * Objects supporting the `bind()` method now implement the full `EventEmitter` API
  * Stop the server from forwarding the `clientId` property of published messages
* Miscellaneous:
  * Support Browserify by returning the client module
  * `Faye.logger` can now be a logger object rather than a function


### 0.8.9 / 2013-02-26

* Specify ciphers for SSL on Node to mitigate the BEAST attack
* Mitigate increased risk of socket hang-up errors in Node v0.8.20
* Fix race condition when processing outgoing extensions in the Node server
* Fix problem loading the client script when using `{mount: '/'}`
* Clean up connection objects when a WebSocket is re-used with a new clientId
* All JavaScript code now runs in strict mode
* Select transport on handshake, instead of on client creation to allow time for `disable()` calls
* Do not speculatively open WebSocket/EventSource connections if they are disabled
* Gracefully handle WebSocket messages with no data on the client side
* Close and reconnect WebSocket when onerror is fired, not just when onclose is fired
* Fix problem with caching of EventSource connections with stale clientIds
* Don't parse query strings when checking if a URL is same-origin or not


### 0.8.8 / 2013-01-10

* Patch security hole allowing remote execution of arbitrary Server methods


### 0.8.7 -- removed due to error while publishing


### 0.8.6 / 2012-10-07

* Make sure messages pushed to the client over a socket pass through outgoing extensions


### 0.8.5 / 2012-09-30

* Fix a bug in `URI.parse()` that caused Faye endpoints to inherit search and hash from `window.location`


### 0.8.4 / 2012-09-29

* Optimise upgrade process so that WebSocket is tested earlier and the connection is cached
* Check that EventSource actually works to work around broken Opera implementation
* Emit `connection:open` and `connection:close` events from the Engine proxy
* Increase size of client IDs from 128 to 160 bits
* Fix bug with relative URL resolution in IE
* Limit the JSON-P transport's message buffer so it doesn't create over-long URLs
* Send `Pragma: no-cache` with XHR requests to guard against iOS 6 POST caching
* Add `charset=utf-8` to response Content-Type headers


### 0.8.3 / 2012-07-15

* `Client#subscribe` returns an array of Subscriptions if given an array of channels
* Allow different endpoints to be specified per-transport
* Only use IE's `XDomainRequest` for same-protocol requests
* Replace URL parser with one that treats relative URLs the same as the browser
* Improve logging of malformed requests and detect problems earlier
* Make sure socket connections are closed when a client session is timed out
* Stop WebSocket reconnecting after `window.onbeforeunload`


### 0.8.2 / 2012-04-12

* Fix replacement of `null` with `{}` in `copyObject()`
* Make EventSource transport trigger `transport:up/down` events
* Supply source map for minified JavaScript client, and include source in gem
* Return `Content-Length: 0` for 304 responses
* Handle pre-flight CORS requests from old versions of Safari


### 0.8.1 / 2012-03-15

* Make `Publisher#trigger` safe for event listeners that modify the listener list
* Make `Server#subscribe` return a response if the incoming message has an error
* Fix edge case in code that identifies the `clientId` of socket connections
* Return `Content-Length` headers for HTTP responses
* Don't send empty lists of messages from the WebSocket transport
* Stop client sending multiple `/meta/subscribe` messages for subscriptions made before handshaking
* Stop client treating incoming published messages as responses to `/meta/*` messages


### 0.8.0 / 2012-02-26

* Extract the Redis engine into a separate library, `faye-redis`
* Stabilize and document the Engine API so others can write backends
* Extract WebSocket and EventSource tools into a separate library, `faye-websocket`
* Improve use of WebSocket so messages are immediately pushed rather than polling
* Introduce new EventSource-based transport, for proxies that block WebSocket
* Support the Rainbows and Goliath web servers for Ruby, same as `faye-websocket`
* Improve detection of network errors and switch to fixed-interval for reconnecting
* Add `setHeader()` method to Client (e.g. for connecting to Salesforce API)
* Add `timeout()` method to `Faye.Deferrable` to match `EventMachine::Deferrable`
* Fix some bugs in client-side message handlers created with `subscribe()`
* Improve speed and memory consumption of `copyObject()`
* Switch from JSON to Yajl for JSON parsing in Ruby


### 0.7.1 / 2011-12-22

* Extension `added()` and `removed()` methods now receive the extended object
* Detection of WebSockets in RackAdapter is more strict


### 0.7.0 / 2011-11-22

* Provide an event API for monitoring engine events on the server side
* Implement server-side WebSocket connections for improved latency
* Fix WebSocket protocol bugs and expose APIs for developers to use
* Make server-side HTTP transports support SSL and cookies
* Allow clients to disable selected transports and autodisconnection
* Add callback/errback API to `Client#publish()` interface
* Add `socket` setting for the Redis engine for connecting through a Unix socket


### 0.6.7 / 2011-10-20

* Cache client script in memory and add `ETag` and `Last-Modified` headers
* Fix bug in Node Redis engine where `undefined` was used if no namespace given
* Flush Redis message queues using a transaction to avoid re-delivery of messages
* Fix race condition and timing errors present in Redis locking code
* Use `Cache-Control: no-cache, no-store` on JSON-P responses
* Improvements to the CORS and JSON-P transports
* Prevent retry handlers in transports from being invoked multiple times
* Use the current page protocol by default when parsing relative URIs


### 0.6.6 / 2011-09-12

* Add `:key` and `:cert` options to the `Adapter#listen` methods for setting up SSL
* Fix error detection of CORS transport in IE9 running IE8 compatibility mode
* Fix dependency versions so that Rubygems lets Faye install


### 0.6.5 / 2011-08-29

* Fix UTF-8 encoding bugs in draft-75/76 and protocol-8 WebSocket parsers
* Switch to streaming parser for WebSocket protocol-8
* Remove an `SREM` operation that shouldn't have been in the Redis engine
* Move `thin_extensions.rb` so it's not on the Rubygems load path


### 0.6.4 / 2011-08-18

* Support WebSocket protocol used by Chrome 14 and Firefox 6
* Fix handling of multibyte characters in WebSocket messages on Node
* Improve message routing in Node memory engine to avoid false duplicates


### 0.6.3 / 2011-07-10

* Use sequential message IDs to reduce memory usage on the client side
* Only send advice with handshake and connect responses
* Stop trying to publish `/meta/*` messages - no-one is listening and it breaks `/**`
* Fix bug causing invalid listeners to appear after a client reconnection
* Stop loading `rubygems` within our library code
* Make sure we only queue a message for each client once in the Redis engine
* Use lists instead of sets for message queues in Redis
* Improve clean-up of expired clients in Redis engine


### 0.6.2 / 2011-06-19

* Add authentication, database selection and namespacing to Redis engine
* Clean up all client data when removing clients from Redis
* Fix `cross-origin-long-polling` for `OPTIONS`-aware browsers
* Update secure WebSocket detection for recent Node versions
* Reinstate `faye.client` field in Rack environment


### 0.6.1 / 2011-06-06

* Fix `cross-origin-long-polling` support in `RackAdapter`
* Plug some potential memory leaks in `Memory` engine


### 0.6.0 / 2011-05-21

* Extract core logic into the `Engine` class to support swappable backends
* Introduce a Redis-backed engine to support clustered web front-ends
* Use CORS for `cross-domain long-polling`
* Make server more resilient against bad requests, including empty message lists
* Perform subscription validation on the server and use errbacks to signal errors
* Prohibit publishing to wildcard channels
* Unsubscribing from a channel is now O(1) instead of O(N)
* Much more thorough and consistent unit test coverage of both versions
* Automatic integration tests using Terminus and TestSwarm


### 0.5.5 / 2011-01-16

* Open a real socket to check for WebSocket usability, not just object detection
* Catch server-side errors when handshaking with WebSockets


### 0.5.4 / 2010-12-19

* Add a `#callback` method to `Subscriptions` to detect when they become active
* Add `:extensions` option to `RackAdapter` to make it easier to extend middleware
* Detect secure WebSocket requests through the `HTTP_X_FORWARDED_PROTO` header
* Handle socket errors when sending WebSocket messages from `NodeAdapter`
* Use exponential backoff to reconnect client-side WebSockets to reduce CPU load


### 0.5.3 / 2010-10-21

* Improve detection of `wss:` requirement for secure WebSocket connections
* Correctly use default ports (80,443) for server-side HTTP connections
* Support legacy `application/x-www-form-urlencoded` POST requests
* Delete unused Channel objects that have all their subscribers removed
* Fix resend/reconnect logic in WebSocket transport
* Keep client script in memory rather than reading it from disk every time
* Prevent error-adding extensions from breaking the core protocol


### 0.5.2 / 2010-08-12

* Support draft-76 of the WebSocket protocol (FF4, Chrome 6)
* Reduce `Connection::MAX_DELAY` to improve latency


### 0.5.1 / 2010-07-21

* Fix a publishing problem in Ruby `LocalTransport`


### 0.5.0 / 2010-07-17 

* Handle multiple event listeners bound to a channel
* Add extension system for adding domain-specific logic to the protocol
* Improve handling of client reconnections if the server goes down
* Change default polling interval to 0 (immediate reconnect)
* Add support for WebSockets (draft75 only) as a network transport
* Remove support for Ruby servers other than Thin
* Make client and server compatible with CometD (1.x and 2.0) components
* Improve clean-up of unused server-side connections
* Change Node API for adding Faye service to an HTTP server


### 0.3.4 / 2010-06-20

* Stop local clients going into an infinite loop if a subscription block causes a reconnect


### 0.3.3 / 2010-06-07

* Bring Node APIs up to date with 0.1.97
* Catch `ECONNREFUSED` errors in Node clients to withstand server outages
* Refactor the `Server` internals


### 0.3.2 / 2010-04-04

* Fix problems with JSON serialization when Prototype, MooTools present
* Make the client reconnect if it doesn't hear from the server after a timeout
* Stop JavaScript server returning `NaN` for `advice.interval`
* Make Ruby server return an integer for `advice.interval`
* Ensure EventMachine is running before handling messages
* Handle `data` and `end` events properly in Node HTTP API
* Switch to `application/json` for content types and stop using querystring format in POST bodies
* Respond to any URL path under the mount point, not just the exact match


### 0.3.1 / 2010-03-09

* Pass client down through Rack stack as `env['faye.client']`
* Refactor some JavaScript internals to mirror Ruby codebase


### 0.3.0 / 2010-03-01

* Add server-side clients for Node.js and Ruby environments
* Clients support both HTTP and in-process transports
* Fix ID generation in JavaScript version to 128-bit IDs
* Fix bug in interpretation of `**` channel wildcard
* Users don't have to call `#connect()` on clients any more
* Fix timeout race conditions that were killing active connections
* Support new Node APIs from 0.1.29.


### 0.2.2 / 2010-02-10

* Kick out requests with malformed JSON as 400s


### 0.2.1 / 2010-02-04

* Fix server-side flushing of callback-polling connections
* Backend can be used cross-domain if running on Node or Thin


### 0.2.0 / 2010-02-02

* Port server to JavaScript with an adapter for Node.js
* Support Thin's async responses in the Ruby version for complete non-blocking
* Fix some minor client-side bugs in transport choice


### 0.1.1 / 2009-07-26

* Fix a broken client build


### 0.1.0 / 2009-06-15

* Ruby Bayeux server and Rack adapter
* Internally evented using EventMachine, web frontend blocks
* JavaScript client with `long-polling` and `callback-polling`

