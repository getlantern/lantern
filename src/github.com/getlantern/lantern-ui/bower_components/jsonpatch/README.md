JSONPatch
=========

An implementation of the [JSONPatch][#jsonpatch] and [JSONPointer][#jsonpointer] IETF RFCs that works in Node.JS and the Browser (as a plain module or with AMD).

A [Dharmafly][#dharmafly] project written by [Thomas Parslow][#tom] <tom@almostobsolete.net> and released with the kind permission of [NetDev][#netdev].

**For full documentation, see [jsonpatchjs.com][#site]**

[![Build Status](https://secure.travis-ci.org/dharmafly/jsonpatch.js.png)](http://travis-ci.org/dharmafly/jsonpatch.js)
[![browser support](http://ci.testling.com/dharmafly/jsonpatch.js.png)](http://ci.testling.com/dharmafly/jsonpatch.js)

Quick Example
-------------

```javascript
    mydoc = {
      "baz": "qux",
      "foo": "bar"
    };
    thepatch = [
      { "op": "replace", "path": "/baz", "value": "boo" }
    ]
    patcheddoc = jsonpatch.apply_patch(mydoc, thepatch);
    // patcheddoc now equals {"baz": "boo", "foo": "bar"}}
```

And that's all you need for basic use. If the patch is invalid or won't apply then you'll get an error thrown. The original doc is NOT mutated so you can use it for other things afterwards, mutating the document is supported via a flag if you need it.

For more see the [docs][#site].

Is it any good?
---------------

Yes, I hope so

Does it work in the browser?
----------------------------

Yes. The tests will run in the browser as well if you want to check. It's been tested in modern browsers and even in IE6!


Does it work with Node.JS?
--------------------------

Yes. Install with:

    npm install jsonpatch

Are there tests?
----------------

Yes, there are tests. It also passes JSHint. You can (and should) run the tests yourself by running this from the project directory:

    npm test

Or you can open `test/runner.html` in a browser of your choice.

We're using [Travis][#travis] and [Testling CI][#testling] to automatically run the tests on Node.JS and in a range of browsers every time a change is commited to this repository. The badges at the top of this readme display the current build status (which should always be passing).


Origin of the project
---------------------

[Dharmafly][#dharmafly] is currently working to create a collaboration web app for [NetDev][#netdev] that comprises a [Node.js][#nodejs] RESTful API on the back-end and an HTML5 [Backbone.js][#backbone] application on the front. The JSONPatch library was created as an essential part of the RESTful API, and has been subsequently open sourced for the community with NetDev's permission.

I've fixed/improved stuff
-------------------------

Great! Send me a pull request [through GitHub](http://github.com/dharmafly/jsonpatch.js) or get in touch on Twitter [@almostobsolete][#tom-twitter] or email at tom@almostobsolete.net

[#site]:http://jsonpatchjs.com
[#tom]: http://www.almostobsolete.net
[#tom-twitter]: https://twitter.com/almostobsolete
[#netdev]: http://www.netdev.co.uk
[#dharmafly]: http://dharmafly.com
[#nodejs]: http://nodejs.org
[#backbone]: http://documentcloud.github.com/backbone/
[#jsonpatch]: http://tools.ietf.org/html/rfc6902
[#jsonpointer]: http://tools.ietf.org/html/rfc6901
[#travis]: http://travis-ci.org/dharmafly/jsonpatch.js
[#testling]: http://ci.testling.com/dharmafly/jsonpatch.js
