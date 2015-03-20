var jsmin = require('jsmin2'),
    SourceMapFileCollector = require('source-map-index-generator');

function Collector(params) {
  // Generate and save our SourceMapFileCollector
  var fileCollector = new SourceMapFileCollector(params);
  this.fileCollector = fileCollector;

  // Save a line offset for addition handling
  this.lineOffset = 0;

  // Save an array for code concatenation
  this.codeArr = [];
}
Collector.prototype = {
  /**
   * Add a file to minify
   * @param {Object} params
   * @param {String} params.code Code to minify
   * @param {String} params.src Filepath to original src
   */
  'addFile': function (params) {
    var input = params.code,
        codeObj = jsmin(input),
        code = codeObj.code,
        codeMap = codeObj.codeMap,
        lineOffset = this.lineOffset,
        fileCollector = this.fileCollector;

    // If there is no leading line break
    if (code.charAt(0) !== '\n') {
      // Insert a leading line break
      // DEV: This prevents conflicts between pieces of code.
      // DEV: Normally `jsmin` inserts one at this start automatically but "use strict" has discovered this edge case.
      code = '\n' + code;

      // Offset all codeMap to account for new character
      var indices = Object.getOwnPropertyNames(codeMap),
          i = 0,
          len = indices.length;
      for (; i < len; i++) {
        codeMap[indices[i]] += 1;
      }
    }

    // Count all the lines in code
    var lines = code.match(/\n/g),
        lineCount = 0;
    if (lines) {
      lineCount = lines.length;
    }

    // Add to our fileCollector
    fileCollector.addIndexMapping({
      'input': input,
      'output': code,
      'map': codeMap,
      'src': params.src,
      'lineOffset': lineOffset
    });

    // Save the new code
    this.codeArr.push(code);

    // Update the line offset
    this.lineOffset = lineOffset + lineCount;

    // Return this for a fluent interface
    return this;
  },
  /**
   * Export function for the collector
   * @return {Object} retObj
   * @return {String} retObj.code Minified JavaScript
   * @return {Object} retObj.sourcemap Sourcemap of input to minified JavaScript
   */
  'export': function () {
    // Output the source map and code
    // DEV: JSMin automatically puts a line break at the top of each statement so we can use an empty string for our join =D
    // DEV: This was true until we ran into global `"use strict";`
    var fileCollector = this.fileCollector,
        srcMap = fileCollector.toString(),
        codeArr = this.codeArr,
        code = codeArr.join(''),
        retObj = {
          'code': code,
          'sourcemap': srcMap
        };
    return retObj;
  }
};

/**
 * JSMin + source-map
 * @param {Object} params Parameters to minify and generate sourcemap with
 * @param {String} [params.dest="undefined.js"] Destination for your JavaScript (used inside of sourcemap map)
 * @param {String} [params.srcRoot] Optional root for all relative URLs
 *
 * SINGLE FILE FORMAT
 * @param {String} params.src  File path to original JavaScript (seen when an error is thrown)
 * @param {String} params.code JavaScript to minify
 *
 * MULTI FILE FORMAT
 * @param {Object[]} params.input Array of objects) to minify
 * @param {String} params.input[n].src File path to original JavaScript (seen when an error is thrown)
 * @param {String} params.input[n].code JavaScript to minify
 *
 * @return {Object} retObj
 * @return {String} retObj.code Minified JavaScript
 * @return {Object} retObj.sourcemap Sourcemap of input to minified JavaScript
 */
module.exports = function (params) {
  var dest = params.dest || 'undefined.js',
      srcRoot = params.srcRoot,
      input = params.input,
      collectorParams = {'file': dest};

  // If there is a sourceRoot, use it
  if (srcRoot) {
    collectorParams.sourceRoot = srcRoot;
  }

  // Generate our collector
  var collector = new Collector(collectorParams);

  // If there is no input, build one
  if (!input) {
    input = [{'src': params.src, 'code': params.code}];
  } else if (!Array.isArray(input)) {
  // Otherwise, if input is not an array, cast it to one
    input = [input];
  }

  // Add each of the files
  var addFile = collector.addFile.bind(collector);
  input.forEach(addFile);

  // Retun the retObj
  var retObj = collector['export']();
  return retObj;
};