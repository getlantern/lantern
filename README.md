# lantern-ui

Replacement UI for [Lantern](https://github.com/getlantern/lantern).

## Overview

This is the proposed repository for the future UI of
[Lantern](https://github.com/getlantern/lantern), featuring the [Vizzuality
visualization](http://vizzuality.github.com/lantern/). It is maintained as
a separate repository to facilitate development. This code can be run
independently of Lantern's Java backend with a lightweight node.js http server
using [Faye](http://faye.jcoglan.com/) to implement Lantern's bayeux server
([CometD](http://cometd.org/)).

If we can eventually record the state the real Lantern backend pushes to the
frontend, we can have the mock backend replay the captured states, so the full
behavior of the frontend can be tested independently.

See [SPECS.md](https://github.com/getlantern/lantern-ui/blob/master/SPECS.md)
for specifications of the state and the state transitions developed for the new
UI (work in progress).


## Getting Started

Install required dependencies (sudo as necessary):

* [Node.js](http://nodejs.org/): `brew install node` or equivalent for your
  system

* [NPM](http://npmjs.org/): `curl http://npmjs.org/install.sh | sh`

* [Faye](http://faye.jcoglan.com/): `npm install -g faye`

* [node-sleep](https://github.com/ErikDubbelboer/node-sleep): `npm install -g
  sleep`

  (We assume `npm install -g` installs node modules to
  `/usr/local/share/npm/lib/node_modules/`, which is where symlinks under
  `node_modules/` point. Adjust as necessary.)

* [Compass](http://compass-style.org/): `gem install compass`
  
* [Compass Twitter Bootstrap](https://github.com/vwall/compass-twitter-bootstrap):
  `gem install compass_twitter_bootstrap`

  (We are currently just including the entire
  [Twitter bootstrap](http://twitter.github.com/bootstrap/) library in
  `app/lib/bootstrap/`, but we will switch to Compass Twitter Bootstrap if
  we need to do any customization.)

Tell compass to watch for changes in the `sass` directory if you need to update
the stylesheets:

    $ scripts/start-compass.sh &
    >>> Compass is watching for changes. Press Ctrl-C to Stop.


Start up the Node.js server simulating the Lantern backend:

    $ scripts/web-server.js
    Bayeux-attached http server running at http://localhost:8000

The new UI should now be available at
[http://localhost:8000/app/index.html](http://localhost:8000/app/index.html)

The UI is implemented as an [AngularJS](http://angularjs.org) app. As
recommended, this repo was started with the
[angular-seed](https://github.com/angular/angular-seed). The
`scripts/web-server.js` script has been modified to attach a bayeux server
via Faye to simulate the Lantern backend.

The bayeux server currently only pushes an initial dummy state to the frontend.
[Specs](https://github.com/getlantern/lantern-ui/blob/master/SPECS.md) are
currently being developed to represent the full state of the application at any
given time, as well as transitions between states. Once the specs are set, the
real Lantern backend can implement them alongside its old implementation, and
the new UI can be coded to conform to the new specs. To make testing easier, we
could record sample logs of the updates sent by the real backend and then have
the mock backend replay them in unit tests and even live on demand.
