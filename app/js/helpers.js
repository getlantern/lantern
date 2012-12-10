'use strict';

if (typeof inspect != 'function') {
  try {
    var inspect = require('util').inspect;
  } catch(e) {
    var inspect = function(x) { return JSON.stringify(x); };
  }
}
if (typeof _ != 'function') {
  try {
    var _ = require('../lib/lodash.js')._;
  } catch(e) {
    console.error('No _ (lodash) object found. Functions requiring it will not work.');
  }
}

function makeLogger(prefix) {
  return function() {
    var s = '[' + prefix + '] ';
    for (var i=0, l=arguments.length, ii=arguments[i]; i<l; ii=arguments[++i])
      s += (_.isObject(ii) ? inspect(ii, false, null, true) : ii)+' ';
    console.log(s);
  };
}

//var log = makeLogger('helpers');

function getByPath(obj, path, defaultVal) {
  path = (path || '').split('.');
  for (var i=0, name=path[i];
       name && !_.isUndefined(obj);
       obj=name ? obj[name] : obj, name=path[++i]);
  if (_.isUndefined(obj) && !_.isUndefined(defaultVal))
    return defaultVal;
  return obj;
}

function deleteByPath(obj, path) {
  if (path == '') {
    for (var key in obj)
      delete obj[key];
    return;
  }
  path = path.split('.');
  var name = path[0], i = 0, l = path.length;
  for (; i<l-1 && path[i+1]; ++i) {
    obj = obj[name];
    name = path[i+1];
  }
  if (i == l - 1 && name)
    delete obj[name];
}

function merge(dst, src, path) {
  if (!_.isObject(dst)) {
    throw Error('dst must be an object');
  }
  path = (path || '').split('.');
  var lastdst, name, i = 0;
  for (name=path[i]; path[i]; name=path[++i] || name) {
    if (_.isUndefined(dst[name])) {
      dst[name] = {};
    }
    if (path[i+1] && !_.isObject(dst[name])) {
      //log('property', name, 'is', dst[name], 'not an object, setting to {}');
      dst[name] = {};
    }
    lastdst = dst;
    dst = dst[name];
  }
  if (!_.isObject(src)) {
    if (!lastdst) {
      throw Error("Can't merge non-object source into object at top level");
    }
    lastdst[name] = src;
    return;
  }
  if (_.isArray(src)) {
    if (!lastdst) {
      throw Error("Can't merge array source into object at top level");
    }
    //log('src is array, replacing with dst rather than merging');
    lastdst[name] = _.clone(src);
    return;
  }
  for (var key in src) {
    merge(dst, src[key], key);
  }
}

if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  angular.module('app.helpers', [])
    // XXX move app.services' logging stuff here?
    .constant('getByPath', getByPath)
    .constant('deleteByPath', deleteByPath)
    .constant('merge', merge);
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  module.exports = {
    makeLogger: makeLogger,
    getByPath: getByPath,
    deleteByPath: deleteByPath,
    merge: merge
  };
}
