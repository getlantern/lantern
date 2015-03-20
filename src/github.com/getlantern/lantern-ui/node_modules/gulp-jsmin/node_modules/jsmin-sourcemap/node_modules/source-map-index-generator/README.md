# source-map-index-generator [![Donate on Gittip](http://badgr.co/gittip/twolfson.png)](https://www.gittip.com/twolfson/)

Generate [source-maps][sourcemap] from index mappings.

[sourcemap]: https://github.com/mozilla/source-map

## Getting Started
Install the module with: `npm install source-map-index-generator`

```javascript
// Load in SourceMapIndexGenerator
var SourceMapIndexGenerator = require('source-map-index-generator');

// Data output by node-jsmin2
var input = [
      '// First line comment',
      'var test = {',
      '  a: "b"',
      '};'
    ].join('\n'),
    output = 'var test={a:"b"};',
    srcFile = 'input.js',
    coordmap = {"22":0,"23":1,"24":2,"25":3,"26":4,"27":5,"28":6,"29":7,"31":8,"33":9,"37":10,"38":11,"40":12,"41":13,"42":14,"44":15,"45":16};

// Generate source map via SourceMapIndexGenerator
var generator = new SourceMapIndexGenerator(generatorProps);

// Add the index coordinate mapping
generator.addIndexMapping({
  src: srcFile,
  input: input,
  output: output,
  map: coordmap
});

// Collect our source-map
generator.toString(); // {"version":3,"file":"min.js","sources":["input.js"],"names":[],"mappings":"AACA,CAAC,CAAC,CAAC,CAAC,CAAC,CAAC,CAAC,CAAE,CAAE,CACT,CAAC,CAAE,CAAC,CAAC,CACP,CAAC"}
```

## Documentation
This module returns a constructor for `SourceMapIndexGenerator`.

### new SourceMapIndexGenerator(startOfSourceMap)

To create a new one, you must pass an object with the following properties:

* `file`: The filename of the generated source that this source map is
  associated with.

* `sourceRoot`: An optional root for all relative URLs in this source map.

### SourceMapIndexGenerator.prototype.addIndexMapping(mapping)

Add code with an index based mapping to the file collection.

The mapping object
should have the following properties:

* `src`: Filepath to original src.

* `input`: Unminified JavaScript.

* `output`: Minified JavaScript.

* `map`: Map of character index to character index (number -> number)

* `lineOffset`: An optional line offset to add to mappings.

## Contributing
In lieu of a formal styleguide, take care to maintain the existing coding style. Add unit tests for any new or changed functionality. Lint and test your code using [grunt](https://github.com/gruntjs/grunt).

## License
Copyright (c) 2013 Todd Wolfson
Licensed under the MIT license.
