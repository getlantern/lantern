# lantern-ui

## Overview

This is the proposed replacement UI for
[Lantern](https://github.com/getlantern/lantern). It is maintained as
a separate repository to facilitate development. This code can be run
independently of Lantern's Java backend with a lightweight node.js http server
using [Faye](http://faye.jcoglan.com/) to implement Lantern's bayeux server
(CometD).

If we can eventually record the state the real Lantern backend pushes to the
frontend, we can have the mock backend serve the captured data, so the full
behavior of the frontend can be tested independently.

(See SPECS.md for a specification of the state and the state transitions the
new frontend expects from the backend.)


## Getting Started

1. Install required dependencies:
    * [Node.js](http://nodejs.org/): `brew install node`
    * [NPM](http://npmjs.org/): `http://npmjs.org/install.sh | sh`
    * [Faye](http://faye.jcoglan.com/): `npm install -g faye`
    * [Compass](http://compass-style.org/): `gem install compass compass_twitter_bootstrap`

(Check out the
[Twitter bootstrap docs](http://twitter.github.com/bootstrap/) if you're
not yet familiar.)

1. Tell compass to start watching for changes in the `sass` directory if you
   will be hacking on the styles:

        $ scripts/start-compass.sh &
        >>> Compass is watching for changes. Press Ctrl-C to Stop.


1. Start up the Node.js server simulating the Lantern backend:

        $ scripts/web-server.js
        Http Server running at http://localhost:8000/

1. The new UI should now be available at
   [http://localhost:8000/app/index.html](http://localhost:8000/app/index.html)


## Hacking

The UI is implemented as an [AngularJS](http://angularjs.org) app, and this
repo is based on the [angular-seed](https://github.com/angular/angular-seed)
project.
