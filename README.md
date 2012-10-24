# lantern-ui

[![Build
Status](https://secure.travis-ci.org/getlantern/lantern-ui.png)](http://travis-ci.org/getlantern/lantern-ui)

Replacement UI for [Lantern](https://github.com/getlantern/lantern).

## Overview

This is the proposed repository for the future UI of
[Lantern](https://github.com/getlantern/lantern), featuring the [Vizzuality
visualization](http://vizzuality.github.com/lantern/). It is maintained as
a separate repository to facilitate development. This code can be run
independently of Lantern's Java backend with a lightweight node.js http server
using [Faye](http://faye.jcoglan.com/) to implement Lantern's bayeux server.

See [SPECS.md](https://github.com/getlantern/lantern-ui/blob/master/SPECS.md)
for specifications of the state and the state transitions developed for the new
UI (work in progress).


## Getting Started

Install required dependencies (`sudo` as necessary):

* [Node.js](http://nodejs.org/): `brew install node` or equivalent for your
  system

For working on the stylesheets:

* [Compass](http://compass-style.org/): `gem install compass`
  
* [Compass Twitter Bootstrap](https://github.com/vwall/compass-twitter-bootstrap):
  `gem install compass_twitter_bootstrap`

  (We are currently just including the entire
  [Twitter bootstrap](http://twitter.github.com/bootstrap/) library in
  `app/lib/bootstrap/`, but we will switch to Compass Twitter Bootstrap if
  we need to do any customization.)

This tells compass to watch for changes in the sass stylesheets and it will
automatically compile them into css in the directory specified by the compass
config file (`config/compass.rb`):

    $ scripts/start-compass.sh &
    >>> Compass is watching for changes. Press Ctrl-C to Stop.


Start up the Node.js server simulating the Lantern backend:

    $ scripts/web-server.js
    Bayeux-attached http server running at...

The new UI should now be available at
[http://localhost:8000/app/index.html](http://localhost:8000/app/index.html)


## Running tests

Globally install required Node.js packages (`sudo` as necessary):

    npm install -g testacular

Check out `.travis.yml` and referenced files for examples of running the
unit tests and end-to-end tests.

**TODO**: *expand this*


## Further Reading

The UI is implemented as an [AngularJS](http://angularjs.org) app. Using the
[AngularJS Batarang](https://github.com/angular/angularjs-batarang)
Chrome extension (especially the performance tab) is highly recommended for
development. As recommended, this repo was started with the
[angular-seed](https://github.com/angular/angular-seed). The
`scripts/web-server.js` script has been modified to attach a bayeux server
and a work-in-progress http API to simulate the Lantern backend.

[Specs](https://github.com/getlantern/lantern-ui/blob/master/SPECS.md) are
currently being developed to represent the full state of the application at any
given time, as well as transitions between states. The specs are being
developed in parallel to the new UI and are currently changing frequently to
meet its needs.
