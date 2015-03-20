'use strict';

/**
 * Return a function that emits the given event.
 *
 * @param {String} event Name of the event we wish to emit.
 * @returns {Function} The function that emits all the things.
 * @api public
 */
module.exports = function emits(event) {
  var self = this
    , parser;

  for (var i = 0, l = arguments.length, args = new Array(l); i < l; i++) {
    args[i] = arguments[i];
  }

  //
  // Assume that if the last given argument is a function, it would be
  // a parser.
  //
  if ('function' === typeof args[args.length - 1]) {
    parser = args.pop();
  }

  return function emit() {
    for (var i = 0, l = arguments.length, arg = new Array(l); i < l; i++) {
      arg[i] = arguments[i];
    }

    if (parser) {
      var returned = parser.apply(self, arg);

      if (returned === parser) return false;
      if (returned === null) arg = [];
      else if (returned !== undefined) arg = returned;
    }

    return self.listeners(event).length
      ? self.emit.apply(self, args.concat(arg))
      : false;
  };
};
