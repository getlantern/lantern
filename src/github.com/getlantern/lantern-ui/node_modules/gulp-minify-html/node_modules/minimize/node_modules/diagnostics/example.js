'use strict';

//
// Please run this example with the correct environment flag `DEBUG=*` or
// `DEBUG=big*` or what ever. For example:
//
// ```
// DEBUG=* node example.js
// ```
//

var log;

//
// Ignore this piece of code, it's merely here so we can use the `diagnostics`
// module if installed or just the index file of this repository which makes it
// easier to test. Normally you would just do:
//
// ```js
// var log = require('diagnostics');
// ```
//
// And everything will be find and dandy.
//
try { log = require('diagnostics'); }
catch (e) { log = require('./'); }

//
// In this example we're going to output a bunch on logs which are namespace.
// This gives a visual demonstration.
//
[
  log('bigpipe'),
  log('bigpipe:pagelet'),
  log('bigpipe:page'),
  log('bigpipe:page:rendering'),
  log('bigpipe:primus:event'),
  log('primus'),
  log('primus:event'),
  log('lexer'),
  log('megatron'),
  log('cows:moo'),
  log('moo:moo'),
  log('moo'),
  log('helloworld'),
  log('helloworld:bar')
].forEach(function (log) {
  log('foo');
});
