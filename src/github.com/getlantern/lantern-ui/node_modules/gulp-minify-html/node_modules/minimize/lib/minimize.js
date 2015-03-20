'use strict';

//
// Required modules.
//
var debug = require('diagnostics')('minimize')
  , EventEmitter = require('events').EventEmitter
  , Helpers = require('./helpers')
  , html = require('htmlparser2')
  , emits = require('emits')
  , async = require('async')
  , util = require('util');

/**
 * Minimizer constructor.
 *
 * @Constructor
 * @param {Object} options parsing options, optional
 * @api public
 */
function Minimize(options) {
  options = options || {};

  this.helpers = new Helpers(options);
  this.plugins = Object.create(null);
  this.emits = emits;

  //
  // Prepare the parser.
  //
  this.htmlparser = new html.Parser(
    new html.DomHandler(this.emits('read'))
  );

  //
  // Register plugins.
  //
  this.plug(options.plugins);
}

//
// Add EventEmitter prototype.
//
util.inherits(Minimize, EventEmitter);

/**
 * Start parsing the provided content and call the callback.
 *
 * @param {String} content HTML
 * @param {Function} callback
 * @api public
 */
Minimize.prototype.parse = function parse(content, callback) {
  if (typeof callback !== 'function') throw new Error('No callback provided');

  //
  // Listen to DOM parsing, so the htmlparser callback can trigger it.
  //
  this.once('read', this.minifier, this);
  this.once('parsed', callback);

  //
  // Initiate parsing of HTML.
  //
  this.htmlparser.parseComplete(content);
};

/**
 * Parse traversable DOM to content.
 *
 * @param {Object} error
 * @param {Object} dom presented as traversable object
 * @api private
 */
Minimize.prototype.minifier = function minifier(error, dom) {
  if (error) throw new Error('Minifier failed to parse DOM', error);

  //
  // DOM has been completely parsed, emit the results.
  //
  this.traverse(dom, '', this.emits('parsed'));
};

/**
 * Traverse the data object, reduce data to string.
 *
 * @param {Array} data
 * @param {String} html compiled contents.
 * @param {Function} done Completion callback.
 * @return {String} completed HTML
 * @api private
 */
Minimize.prototype.traverse = function traverse(data, html, done) {
  var minimize = this;

  //
  // Reduce all provided elements to minimized HTML.
  //
  async.reduce(data, html, function reduce(html, element, step) {
    var plugins = Object.keys(minimize.plugins);

    //
    // Run the registered plugins before the element is processed.
    // Note that the plugins are not run in order.
    //
    if (!plugins.length) return enter();
    async.eachSeries(plugins, function plug(plugin, next) {
      minimize.plugins[plugin].element.call(minimize, element, next);
    }, enter);

    /**
     * Enter element in HTML.
     *
     * @param {Error} error
     * @api private
     */
    function enter(error) {
      if (error) return done(error);

      html += minimize.helpers[element.type](element);
      if (!element.children) return close(null, html);

      traverse.call(minimize, element.children, html, close);
    }

    /**
     * Close element in HTML.
     *
     * @param {Error} error
     * @param {String} html
     * @api private
     */
    function close(error, html) {
      if (error) return step(error);

      html += minimize.helpers.close(element);
      step(null, html);
    }
  }, done);
};

/**
 * Register provided plugins.
 *
 * @param {Array} plugins Collection of plugins
 * @api private
 */
Minimize.prototype.plug = function plug(plugins) {
  if (!Array.isArray(plugins)) return;
  var minimize = this;

  plugins.forEach(function each(plugin) {
    minimize.use(plugin);
  });
};

/**
 * Register a new plugin.
 *
 * ```js
 * bigpipe.use('dropClass', {
 *   element: function () { }
 * });
 * ```
 *
 * @param {String} id The id of the plugin.
 * @param {Object} plugin The plugin module.
 * @api public
 */
Minimize.prototype.use = function use(id, plugin) {
  if ('object' === typeof id) {
    plugin = id;
    id = plugin.id;
  }

  if (!id) throw new Error('Plugin should be specified with an id.');
  if ('string' !== typeof id) throw new Error('Plugin id should be a string.');
  if ('string' === typeof plugin) plugin = require(plugin);

  //
  // Plugin accepts an object or a function only.
  //
  if (!/^(object|function)$/.test(typeof plugin)) {
    throw new Error('Plugin should be an object or function.');
  }

  //
  // Plugin requires an element method to be specified.
  //
  if ('function' !== typeof plugin.element) {
    throw new Error('The plugin is missing an element method to execute.');
  }

  if (id in this.plugins) {
    throw new Error('The plugin name was already defined.');
  }

  debug('Added plugin `%s`', id);

  this.plugins[id] = plugin;
  return this;
};

//
// Expose the minimize function by default.
//
module.exports = Minimize;