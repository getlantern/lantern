# AngularUI - The companion suite for AngularJS

***

[![Build Status](https://travis-ci.org/angular-ui/ui-utils.png?branch=master)](https://travis-ci.org/angular-ui/ui-utils)

## Usage

### Requirements

* **AngularJS v1.0.0+** is currently required.
* **jQuery*** Until the refactor is complete, some directives still require jQuery

## Installation

Add the specific modules to your dependencies, or add the entire lib by depending on `ui.utils`

```javascript
angular.module('myApp', ['ui.keypress', 'ui.event', ...])
// or if ALL modules are loaded along with modules/utils.js
angular.module('myApp', ['ui.utils'])
```

Each directive and filter is now it's own module and will have a relevant README.md in their respective folders

## Development

At this time, we do not have a build script. You must include all `.js` files you wish to work on.
We will likely be adding a `Gruntfile.js` in the near future for this

### Requirements

0. Install [Node.js](http://nodejs.org/) and NPM (should come with)

1. Install global dependencies `grunt-cli`, `bower`, and `karma`:

    ```bash
    $ npm install -g karma grunt-cli bower
    ```

2. Install local dependencies:

    ```bash
    $ npm install
    $ bower install
    ```

### Running Tests

Make sure all tests pass in order for your Pull Request to be accepted

You can choose what browsers to test in: `Chrome,ChromeCanary,Firefox,PhantomJS`

```bash
$ karma start --browsers=Chrome,Firefox test/test.conf.js
```
