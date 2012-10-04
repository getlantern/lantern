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

The UI is implemented as an [AngularJS](http://angularjs.org) app. Using the
[AngularJS Batarang](https://github.com/angular/angularjs-batarang)
Chrome extension (especially the performance tab) is highly recommended for
development. As recommended, this repo was started with the
[angular-seed](https://github.com/angular/angular-seed). The
`scripts/web-server.js` script has been modified to attach a bayeux server
via Faye to simulate the Lantern cometd server, and has also been modified to
provide a work-in-progress http API the frontend can call to notify the backend
of user interactions.

[Specs](https://github.com/getlantern/lantern-ui/blob/master/SPECS.md) are
currently being developed to represent the full state of the application at any
given time, as well as transitions between states. The specs are being
developed in parallel to the new UI and for now are frequently changing to
meet its needs.
