'use strict';

/**
 * Argv is a extremely light weight options parser for Node.js it's been built
 * for just one single purpose, parsing arguments. It does nothing more than
 * that.
 *
 * @param {Array} argv The arguments that need to be parsed, defaults to process.argv
 * @returns {Object} Parsed arguments.
 * @api public
 */
function parse(argv) {
  argv = argv || process.argv.slice(2);

  /**
   * This is where the actual parsing happens, we can use array#reduce to
   * iterate over the arguments and change it to an object. We can easily bail
   * out of the loop by destroying `argv` array.
   *
   * @param {Object} argh The object that stores the parsed arguments
   * @param {String} option The command line flag
   * @param {Number} index The position of the flag in argv's
   * @param {Array} argv The argument variables
   * @returns {Object} argh, the parsed commands
   * @api private
   */
  return argv.reduce(function parser(argh, option, index, argv) {
    var next = argv[index + 1]
      , value
      , data;

    //
    // Special case, -- indicates that it should stop parsing the options and
    // store everything in a "special" key.
    //
    if (option === '--') {
      //
      // By splicing the argv array, we also cancel the reduce as there are no
      // more options to parse.
      //
      argh.argv = argh.argv || [];
      argh.argv = argh.argv.concat(argv.splice(index + 1));
      return argh;
    }

    if (data = /^--?(?:no|disable)-(.*)/.exec(option)) {
      //
      // --no-<key> indicates that this is a boolean value.
      //
      insert(argh, data[1], false, option);
    } else if (data = /^-(?!-)(.*)/.exec(option)) {
      insert(argh, data[1], true, option);
    } else if (data = /^--([^=]+)=\W?([\s!#$%&\x28-\x7e]+)\W?$/.exec(option)) {
      //
      // --foo="bar" and --foo=bar are alternate styles to --foo bar.
      //
      insert(argh, data[1], data[2], option);
    } else if (data = /^--(.*)/.exec(option)) {
      //
      // Check if this was a bool argument
      //
      if (!next || next.charAt(0) === '-' || (value = /^true|false$/.test(next))) {
        insert(argh, data[1], value ? argv.splice(index + 1, 1)[0] : true, option);
      } else {
        value = argv.splice(index + 1, 1)[0];
        insert(argh, data[1], value, option);
      }
    } else {
      //
      // This argument is not prefixed.
      //
      if (!argh.argv) argh.argv = [];
      argh.argv.push(option);
    }

    return argh;
  }, Object.create(null));
}

/**
 * Inserts the value in the argh object
 *
 * @param {Object} argh The object where we store the values
 * @param {String} key The received command line flag
 * @param {String} value The command line flag's value
 * @param {String} option The actual option
 * @api private
 */
function insert(argh, key, value, option) {
  //
  // Automatic value conversion. This makes sure we store the correct "type"
  //
  if ('string' === typeof value && !isNaN(+value)) value = +value;
  if (value === 'true' || value === 'false') value = value === 'true';

  var single = option.charAt(1) !== '-'
    , properties = key.split('.')
    , position = argh;

  if (single && key.length > 1) return key.split('').forEach(function short(char) {
    insert(argh, char, value, option);
  });

  //
  // We don't have any deeply nested properties, so we should just bail out
  // early enough so we don't have to do any processing
  //
  if (!properties.length) return argh[key] = value;

  while (properties.length) {
    var property = properties.shift();

    if (properties.length) {
      if ('object' !== typeof position[property] && !Array.isArray(position[property])) {
        position[property] = Object.create(null);
      }
    } else {
      position[property] = value;
    }

    position = position[property];
  }
}

/**
 * Lazy parse the process arguments when `argh.argv` is accessed. This is the
 * same as simply calling `argh()`.
 *
 * @return {Object} Parsed process arguments.
 */
Object.defineProperty(parse, 'argv', {
  get: function argv() {
    return argv.parsed || (argv.parsed = parse());
  }
});

module.exports = parse;
