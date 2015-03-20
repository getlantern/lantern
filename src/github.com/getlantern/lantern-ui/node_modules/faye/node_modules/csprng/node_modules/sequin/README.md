# sequin [![Build status](https://secure.travis-ci.org/jcoglan/sequin.png)](http://travis-ci.org/jcoglan/sequin)

Generates uniformly distributed ints in any base from a bit sequence, according
to the algorithm [described by Christian
Perfect](http://checkmyworking.com/2012/06/converting-a-stream-of-binary-digits-to-a-stream-of-base-n-digits/).


## Installation

```
$ npm install sequin
```


## Usage

Construct a stream using an array of `0`/`1` values, or using a `Buffer` with
the second argument set to `8`:

```js
var Sequin = require('sequin'),
    crypto = require('crypto'),
    stream = new Sequin(crypto.randomBytes(10), 8);
```

The stream's `generate(k)` method returns an integer less than `k`, or `null` if
there are not enough bits left in the stream to generate an integer of the
required size.

```js
var Sequin = require('sequin'),
    stream = new Sequin([1,1,0,1,0,1,0,1,1,1,1,1,0,0,1]);

stream.generate(5) // -> 3
stream.generate(5) // -> 3
stream.generate(5) // -> 1
stream.generate(5) // -> null
```


## License

(The MIT License)

Copyright (c) 2012-2013 James Coglan

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the 'Software'), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

