'use strict';

if (typeof inspect != 'function') {
  try {
    var inspect = require('util').inspect;
  } catch (e) {
    var inspect = function(x) { return JSON.stringify(x); };
  }
}

if (typeof _ != 'function') {
  var _ = require('../lib/lodash.js')._;
}

if (typeof jsonpatch != 'object') {
  var jsonpatch = require('../lib/jsonpatch.js');
}
var JSONPatch = jsonpatch.JSONPatch,
    JSONPointer = jsonpatch.JSONPointer;

function makeLogger(prefix) {
  return function() {
    var s = '[' + prefix + '] ';
    for (var i=0, l=arguments.length, ii=arguments[i]; i<l; ii=arguments[++i])
      s += (_.isObject(ii) ? inspect(ii, false, null, true) : ii)+' ';
    console.log(s);
  };
}

var log = makeLogger('helpers');


function randomChoice(collection) {
  if (_.isArray(collection)) {
    return collection[_.random(0, collection.length-1)];
  } else if (_.isPlainObject(collection)) {
    return randomChoice(_.keys(collection));
  }
  throw Error('expected array or plain object, got '+typeof collection);
}

function applyPatch(obj, patch) {
  patch = new JSONPatch(patch, true); // mutate = true
  patch.apply(obj);
}

function _validateObj(obj) {
  if (!_.isPlainObject(obj))
    throw Error('expected plain object, got '+typeof obj);
}

function _validPath(path) {
  if (!_.isString(path)) return false;
  if (path === '/') return true;
  var split = path.split('/');
  if (split.length < 2) return false; // at least one '/'
  if (split[0] !== '') return false; // starts with '/'
  split.shift();
  return _.all(split); // no empty components, e.g. '/foo/bar//baz'
}

function _validatePath(path) {
  if (!_validPath(path)) throw Error('invalid path: '+path);
}

function getByPath(obj, path, defaultVal) {
  _validateObj(obj);
  if (_.isUndefined(path)) path = '/';
  if (path === '/') return obj;
  _validatePath(path);
  path = path.split('/');
  for (var i=1, l=path.length, name=path[i]; i<l; name=path[++i]) {
    if (name && _.isObject(obj) && name in obj) {
      obj = obj[name];
    } else {
      return defaultVal;
    }
  }
  return obj;
}

function _get_parent_and_last(obj, path) {
  path = path.split('/');
  return {
    last: path.pop(),
    parent: path.length > 1 ? getByPath(obj, path.join('/')) : obj
  };
}

function deleteByPath(obj, path) {
  _validateObj(obj);
  if (path === '/') {
    for (var key in obj)
      delete obj[key];
    return true;
  }
  _validatePath(path);
  var parent_last = _get_parent_and_last(obj, path),
      parent = parent_last.parent,
      last = parent_last.last;
  if (_.isPlainObject(parent) && last in parent) {
    delete parent[last];
    return true;
  }
  return false;
}

function setByPath(obj, path, val) {
  _validateObj(obj);
  if (path === '/') throw Error('Cannot overwrite root object')
  _validatePath(path);
  var parent_last = _get_parent_and_last(obj, path),
      parent = parent_last.parent,
      last = parent_last.last;
  if (_.isPlainObject(parent) && last in parent) {
    parent[last] = val;
  } else {
    throw Error('"'+last+'" not in '+JSON.stringify(obj));
  }
}

// XXX DRY
if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  angular.module('app.helpers', [])
    // XXX move app.services' logging stuff here?
    .constant('randomChoice', randomChoice)
    .constant('applyPatch', applyPatch)
    .constant('getByPath', getByPath)
    .constant('setByPath', setByPath)
    .constant('deleteByPath', deleteByPath)
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  module.exports = {
    makeLogger: makeLogger,
    randomChoice: randomChoice,
    applyPatch: applyPatch,
    getByPath: getByPath,
    setByPath: setByPath,
    deleteByPath: deleteByPath
  };
}
