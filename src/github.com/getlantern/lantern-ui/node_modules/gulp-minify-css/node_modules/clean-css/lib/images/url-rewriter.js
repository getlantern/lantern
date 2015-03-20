var path = require('path');
var url = require('url');

var UrlScanner = require('../utils/url-scanner');

function UrlRewriter(options, context) {
  this.options = options;
  this.context = context;
}

UrlRewriter.prototype.process = function (data) {
  var self = this;

  return new UrlScanner(data, this.context).reduce(function (url, tempData) {
    url = url.replace(/^url\(\s*['"]?|['"]?\s*\)$/g, '');
    tempData.push('url(' + rebase(url, self.options) + ')');
  });
};

function rebase(resource, options) {
  // TODO: this is getting insane now - pending refactor in #436
  var importUrl = resource.substring(resource.length - 4) == '.css';
  var dataUri = resource.indexOf('data:') === 0;
  var specialUrl = resource[0] == '/' ||
    resource[0] == '#' ||
    (!options.imports && importUrl) ||
    dataUri ||
    /^https?:\/\//.exec(resource) !== null ||
    /__\w+__/.exec(resource) !== null;
  var rebased;

  if (false === options.urls) {
    if (options.imports && importUrl)
      specialUrl = false;
    else
      specialUrl = true;
  }

  if (specialUrl)
    return dataUri ? '\'' + resource + '\'' : resource;

  if (/https?:\/\//.test(options.toBase))
    return url.resolve(options.toBase, resource);

  if (options.absolute) {
    rebased = path
      .resolve(path.join(options.fromBase, resource))
      .replace(options.toBase, '');
  } else {
    rebased = path.relative(options.toBase, path.join(options.fromBase, resource));
  }

  return process.platform == 'win32' ?
    rebased.replace(/\\/g, '/') :
    rebased;
}

module.exports = UrlRewriter;
