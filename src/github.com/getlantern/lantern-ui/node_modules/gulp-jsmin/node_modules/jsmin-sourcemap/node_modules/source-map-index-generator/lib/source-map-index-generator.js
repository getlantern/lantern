var SourceMapGenerator = require('source-map').SourceMapGenerator,
    charProps = require('char-props');

/**
 * Collect multiple files into a source map
 *
 *   - file: The filename of the generated source.
 *   - sourceRoot: An optional root for all URLs in this source map.
 */
function SourceMapIndexGenerator(params) {
  // Create and save a new SourceMapGenerator
  var srcMapGenerator = new SourceMapGenerator(params);
  this.srcMapGenerator = srcMapGenerator;
}

/**
 * Add code with an index based mapping to our srcMapGenerator
 *   - params Object holding multiple parameters
 *   - params.src Filepath to original src
 *   - params.input Unminified JavaScript
 *   - params.output Minified JavaScript
 *   - params.map Map of character index to character index (number -> number)
 *   - params.lineOffset (OPTIONAL) Line offset to add to mappings
 */
SourceMapIndexGenerator.prototype.addIndexMapping = function (params) {
  // Localize items from params
  var srcFile = params.src,
      srcProps = charProps(params.input),
      destProps = charProps(params.output),
      codeMap = params.map,
      lineOffset = params.lineOffset || 0;

  // Grab the keys of the codeMap
  // DEV: If columnAt starts to be the slow part, create a map which memoizes each of the indicies it `while` loops over -- an LRU is probably best here.
  var srcMapGenerator = this.srcMapGenerator,
      lastSrcLine = 0,
      lastDestLine = 0,
      srcPoints = Object.getOwnPropertyNames(codeMap);
  srcPoints.forEach(function (srcPoint) {
    // Get the line and col of the src
    var srcLine = srcProps.lineAt(srcPoint, {'minLine': lastSrcLine}),
        srcCol = srcProps.columnAt(srcPoint);

    // Save the srcLine as our next guess
    lastSrcLine = srcLine;

    // Get the line and col of the dest
    var destPoint = codeMap[srcPoint],
        destLine = destProps.lineAt(destPoint, {'minLine': lastDestLine}),
        destCol = destProps.columnAt(destPoint);

    // Save the destLine for our next guess
    lastDestLine = destLine;

    // Create our mapping
    var mapping = {
      'original': {
        'line': srcLine + 1,
        'column': srcCol
      },
      'generated': {
        'line': destLine + 1 + lineOffset,
        'column': destCol
      },
      'source': srcFile
    };

    // Add the mapping to our generator
    srcMapGenerator.addMapping(mapping);
  });

  // Return this for a fluent interface
  return this;
};

/**
 * Export the current collection as a sourcemap
 */
SourceMapIndexGenerator.prototype.toString = function () {
  var srcMapGenerator = this.srcMapGenerator;
  return srcMapGenerator.toString();
};

// Export SourceMapIndexGenerator
module.exports = SourceMapIndexGenerator;