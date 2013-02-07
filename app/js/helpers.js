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
    JSONPointer = jsonpatch.JSONPointer,
    PatchApplyError = jsonpatch.PatchApplyError;

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
  throw new TypeError('expected array or plain object, got '+typeof collection);
}

function applyPatch(obj, patch) {
  patch = new JSONPatch(patch, true); // mutate = true
  patch.apply(obj);
}

function getByPath(obj, path) {
  try {
    return (new JSONPointer(path)).get(obj);
  } catch (e) {
    if (!(e instanceof PatchApplyError)) throw e;
  }
}

var _export = [makeLogger, randomChoice, applyPatch, getByPath];
if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  var module = angular.module('app.helpers', []);
  _.forEach(_export, function(func) {
    module.constant(func.name, func);
  });
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  _.forEach(_export, function(func) {
    exports[func.name] = func;
  });
}
