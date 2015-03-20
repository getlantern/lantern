var path = require('path');
var UrlRewriter = require('../images/url-rewriter');

function SourceReader(context, data) {
  this.outerContext = context;
  this.data = data;
}

SourceReader.prototype.toString = function () {
  if (typeof this.data == 'string')
    return this.data;
  if (Buffer.isBuffer(this.data))
    return this.data.toString();
  if (Array.isArray(this.data))
    return fromArray(this.outerContext, this.data);

  return fromHash(this.outerContext, this.data);
};

function fromArray(outerContext, sources) {
  return sources
    .map(function (source) {
      return outerContext.options.processImport === false ?
        source + '@shallow' :
        source;
    })
    .map(function (source) {
      return !outerContext.options.relativeTo || /^https?:\/\//.test(source) ?
        source :
        path.relative(outerContext.options.relativeTo, source);
    })
    .map(function (source) { return '@import url(' + source + ');'; })
    .join('');
}

function fromHash(outerContext, sources) {
  var data = [];
  var toBase = path.resolve(outerContext.options.target || process.cwd());

  for (var source in sources) {
    var styles = sources[source].styles;
    var inputSourceMap = sources[source].sourceMap;

    var rewriter = new UrlRewriter({
      absolute: !!outerContext.options.root,
      relative: !outerContext.options.root,
      imports: true,
      urls: outerContext.options.rebase,
      fromBase: path.dirname(path.resolve(source)),
      toBase: toBase
    }, this.outerContext);
    styles = rewriter.process(styles);

    if (outerContext.options.sourceMap && inputSourceMap) {
      var absoluteSource = path.resolve(source);
      styles = outerContext.sourceTracker.store(absoluteSource, styles);
      outerContext.inputSourceMapTracker.trackLoaded(absoluteSource, inputSourceMap);
    }

    data.push(styles);
  }

  return data.join('');
}

module.exports = SourceReader;
