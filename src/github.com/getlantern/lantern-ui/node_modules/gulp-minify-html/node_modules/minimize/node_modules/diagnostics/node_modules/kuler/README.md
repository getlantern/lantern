# kuler

Kuler is small and nifty node module that allows you to create terminal based
colors using hex color codes, just like you're used to doing in your CSS. We're
in a modern world now and terminals support more than 16 colors so we are stupid
to not take advantage of this.

## Installation

```
npm install --save kuler
```

## Usage

Kuler provides a really low level API as we all have different opinions on how
to build and write coloring libraries. To use it you first have to require it:

```js
'use strict';

var kuler = require('kuler');
```

There are two different API's that you can use. A constructor based API which
uses a `.style` method to color your text:

```js
var str = kuler('foo').style('#FFF');
```

Or an alternate short version:

```js
var str = kuler('foo', 'red');
```

The color code sequence is automatically terminated at the end of the string so
the colors do no bleed to other pieces of text. So doing: 

```js
console.log(kuler('red', 'red'), 'normal');
```

Will work without any issues.

## License

MIT
