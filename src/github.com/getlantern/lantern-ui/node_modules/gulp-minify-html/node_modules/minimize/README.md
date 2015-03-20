# HTML minifier

[![Version npm][version]](http://browsenpm.org/package/minimize)[![Build Status][build]](https://travis-ci.org/Moveo/minimize)[![Dependencies][david]](https://david-dm.org/moveo/minimize)[![Coverage Status][cover]](https://coveralls.io/r/moveo/minimize?branch=master)

[version]: http://img.shields.io/npm/v/minimize.svg?style=flat-square
[build]: http://img.shields.io/travis/Moveo/minimize/master.svg?style=flat-square
[david]: https://img.shields.io/david/moveo/minimize.svg?style=flat-square
[cover]: http://img.shields.io/coveralls/Moveo/minimize/master.svg?style=flat-square

Minimize is a HTML minifier based on the node-htmlparser. This depedency will
ensure output is solid and correct. Minimize is focussed on HTML5 and will not
support older HTML drafts. It is not worth the effort and the web should move
forward. Currently, HTML minifier is only usuable server side. Client side
minification will be added in a future release.

*Minimize does not correctly parse inline PHP or raw template files. Simply
because this is not valid HTML and never will be either. The output of the
templaters should be parsed and minified.*

## Features

- fast and stable HTML minification (no inline PHP or templates)
- highly configurable
- CLI interface usable with stdin and files
- can distinguish conditional IE comments and/or SSI
- build on the foundations of [htmlparser2][fb55]
- pluggable interface that allows to hook into each element

## Upcoming in release 2.0

- minification of inline javascript with uglify or similar
- client side minimize support

## Usage

To get the minified content make sure to provide a callback. Optional an options
object can be provided. All options are listed below and `false` per default.

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({
      empty: true,        // KEEP empty attributes
      cdata: true,        // KEEP CDATA from scripts
      comments: true,     // KEEP comments
      ssi: true,          // KEEP Server Side Includes
      conditionals: true, // KEEP conditional internet explorer comments
      spare: true,        // KEEP redundant attributes
      quotes: true,       // KEEP arbitrary quotes
      loose: true         // KEEP one whitespace
    });

minimize.parse(content, function (error, data) {
  console.log(data);
});
```

## Options

**Empty**

Empty attributes can usually be removed, by default all are removed, excluded
HTML5 _data-*_ and microdata attributes. To retain empty elements regardless
value, do:

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ empty: true });

minimize.parse(
  '<h1 id=""></h1>',
  function (error, data) {
    // data output: <h1 id=""></h1>
  }
);
```

**CDATA**

CDATA is only required for HTML to parse as valid XML. For normal webpages this
is rarely the case, thus CDATA around javascript can be omitted. By default
CDATA is removed, if you would like to keep it, pass true:

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ cdata: true });

minimize.parse(
  '<script type="text/javascript">\n//<![CDATA[\n...code...\n//]]>\n</script>',
  function (error, data) {
    // data output: <script type=text/javascript>//<![CDATA[\n...code...\n//]]></script>
  }
);
```

**Comments**

Comments inside HTML are usually beneficial while developing. Hiding your
comments in production is sane, safe and will reduce data transfer. If you
ensist on keeping them, fo1r instance to show a nice easter egg, set the option
to true. Keeping comments will also retain any Server Side Includes or
conditional IE statements.

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ comments: true });

minimize.parse(
  '<!-- some HTML comment -->\n     <div class="slide nodejs">',
  function (error, data) {
    // data output: <!-- some HTML comment --><div class="slide nodejs">
  }
);
```

**Server Side Includes (SSI)**

Server side includes are special set of commands that are support by several
web servers. The markup is very similar to regular HTML comments. Minimize can
be configured to retain SSI comments.

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ ssi: true });

minimize.parse(
  '<!--#include virtual="../quote.txt" -->\n     <div class="slide nodejs">',
  function (error, data) {
    // data output: <!--#include virtual="../quote.txt" --><div class="slide nodejs">
  }
);
```

**Conditionals**

Conditional comments only work in IE, and are thus excellently suited to give
special instructions meant only for IE. Minimize can be configured to retain
these comments. But since the comments are only working until IE9 (inclusive)
the default is to remove the conditionals.

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ conditionals: true });

minimize.parse(
  "<!--[if ie6]>Cover microsofts' ass<![endif]-->\n<br>",
  function (error, data) {
    // data output: <!--[if ie6]>Cover microsofts' ass<![endif]-->\n<br>
  }
);
```

**Spare**

Spare attributes are of type boolean of which the value can be omitted in HTML5.
To keep attributes intact for support of older browsers, supply:

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ spare: true });

minimize.parse(
  '<input type="text" disabled="disabled"></h1>',
  function (error, data) {
    // data output: <input type=text disabled=disabled></h1>
  }
);
```

**Quotes**

Quotes are always added around attributes that have spaces or an equal sign in
their value. But if you require quotes around all attributes, simply pass
quotes:true, like below.

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ quotes: true });

minimize.parse(
  '<p class="paragraph" id="title">\n    Some content\n  </p>',
  function (error, data) {
    // data output: <p class="paragraph" id="title">Some content</p>
  }
);
```

**Loose**

Minimize will only keep whitespaces in structural elements and remove all other
redundant whitespaces. This option is useful if you need whitespace to keep the
flow between text and input elements. Downside: whitespaces or newlines after
block level elements will also have one trailing whitespace.

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ loose: true });

minimize.parse(
  '<h1>title</h1>  <p class="paragraph" id="title">\n  content\n  </p>    ',
  function (error, data) {
    // data output: <h1>title</h1> <p class="paragraph" id="title"> content </p> '
  }
);
```

**Plugins**

Register a set of plugins that will be ran on each iterated element. Plugins
are ran in order, errors will stop the iteration and invoke the completion
callback.

```javascript
var Minimize = require('minimize')
  , minimize = new Minimize({ plugins: [
      id: 'remove',
      element: function element(node, next) {
        if (node.type === 'text') delete node.data;
        next();
      }
    ]});

minimize.parse(
  '<h1>title</h1>',
  function (error, data) {
    // data output: <h1></h1>
  }
);
```

## Tests

Tests can be easily run by using either of the following commands. Travis.ci is
used for continous integration.

```bash
make test
make test-watch
npm test
```

## Benchmarks


## Credits
Minimize is influenced by the [HTML minifier][kangax] of kangax. This module
parses the DOM as string as opposes to an object. However, retaining flow is more
diffucult if the DOM is parsed sequentially. Minimize is not client-side ready.
Kangax minifier also provides some additional options like linting. Minimize
will retain strictly to the business of minifying. Minimize is already used in
production by [Nodejitsu][nodejitsu].

[node-htmlparser][fb55] of fb55 is used to create an object representation
of the DOM.

[kangax]: https://github.com/kangax/html-minifier/
[fb55]: https://github.com/fb55/htmlparser2
[nodejitsu]: http://www.nodejitsu.com/
