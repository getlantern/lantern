# lantern-ui

[![Build
Status](https://secure.travis-ci.org/getlantern/lantern-ui.png)](http://travis-ci.org/getlantern/lantern-ui
"Build Status") [![Bitdeli
Badge](https://d2weczhvl823v0.cloudfront.net/getlantern/lantern-ui/trend.png)](https://bitdeli.com/free
"Bitdeli Badge")

UI for [Lantern](https://github.com/getlantern/lantern).

## Overview

This is the repository for the UI of
[Lantern](https://github.com/getlantern/lantern).

## Getting Started

Install required dependencies (`sudo` as necessary):

* [Node.js](http://nodejs.org/): `brew install node` or equivalent for your
system

* [Bower](http://bower.io): `npm install -g bower` (only needed if you want to
be able to update dependencies; they're already checked in to the
app/bower_components directory so you don't need bower just to fetch them).

* run `npm install` to fetch dependencies specified in package.json

* run `npm start`

You should get a message telling you the application is up and running with a
link to access it.

### For working on the stylesheets:

(Not necessary unless you want to change stylesheets.)

* [ruby](http://www.ruby-lang.org/) (comes with OS X)

* [compass](http://compass-style.org/) 0.12.2: `gem install compass --version
'= 0.12.2'`.

Tell compass to watch for changes in the sass stylesheets and automatically
compile them into css in the directory specified by the compass config file
(`config/compass.rb`):

    $ scripts/start-compass.sh & >>> Compass is watching for changes. Press
Ctrl-C to Stop.


## Build

Lantern UI uses [Gulp](http://gulpjs.com/) to build assets

* `npm install --global gulp` * `npm install` * `gulp build`

Embed 'dist' folder into production.

## i18n

Translated strings are fetched from json files in the "app/locale" directory
and interpolated into the app using [Angular
Translate](https://github.com/angular-translate/angular-translate).  To add or
change a translated string, update the corresponding mapping in
"app/locale/en_US.json" and add or update any references to it in the app if
needed.

### Transifex

All translatable content for Lantern has been uploaded to [the Lantern
Transifex project](https://www.transifex.com/projects/p/lantern/) to help
manage translations. Translatable strings from this code have been uploaded to
the [ui](https://www.transifex.com/projects/p/lantern/resource/ui/) resource
therein. Transifex has been set up to automatically pull updates to that
resource from [its GitHub
url](https://raw.github.com/getlantern/lantern-ui/master/app/locale/en_US.json)
(see
http://support.transifex.com/customer/portal/articles/1166968-updating-your-source-files-automatically
for more information).

After translators add translations of these strings to the Transifex project,
the [Transifex
client](http://support.transifex.com/customer/portal/articles/960804-overview)
can be used to pull them. See
http://support.transifex.com/customer/portal/articles/996157-getting-translations
for more.


## Running tests

Lantern UI does not yet have a comprehensive set of tests, but the tests that
are written are useful and are set up with continuous integration in
[Travis](https://travis-ci.org/getlantern/lantern-ui).

To run the tests locally, first install karma (`sudo` as necessary):

    npm install -g karma

and [PhantomJS](http://phantomjs.org/) (brew install phantomjs).

Then look in `.travis.yml` for the commands to run the unit and end-to-end
tests.

**TODO**: *expand this*


## Further Reading

The UI is implemented as an [AngularJS](http://angularjs.org) app. Using the
[AngularJS Batarang](https://github.com/angular/angularjs-batarang) Chrome
extension (especially the performance tab) can come in handy.

This repo was started with the
[angular-seed](https://github.com/angular/angular-seed). The
`scripts/web-server.js` script has been modified to attach a WebSocket server
as mentioned above and an http API to simulate the Lantern backend. The
application logic for the mock backend can be found in `mock/backend.js`.
