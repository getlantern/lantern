'use strict';

//
// Required modules.
//
var util = require('utile')
  , list = require('./list');

//
// Predefined parsing options.
//
var config = {
  empty: false,        // remove(false) or retain(true) empty attributes
  cdata: false,        // remove(false) or retain(true) CDATA from scripts
  comments: false,     // remove(false) or retain(true) comments
  conditionals: false, // remove(false) or retain(true) ie conditional comments
  ssi: false,          // remove(false) or retain(true) server side includes
  spare: false,        // remove(false) or retain(true) redundant attributes
  quotes: false,       // remove(false) or retain(true) quotes if not required
  loose: false         // remove(false) all or retain(true) one whitespace
};

/**
 * Compact the value, replace multiple white spaces and newlines
 * with a single white space.
 *
 * @param {String} value Value to compact
 * @param {Boolean} keepNewlines Do not remove newlines
 * @return {String} Compacted data
 * @api private
 */
function compact(value, keepNewlines) {
  var check = keepNewlines ? / +/g : /\s+/g;
  return value.replace(check, ' ');
}

/**
 * Helper constructor.
 *
 * @Constructor
 * @param {Object} options
 * @api public
 */
function Helpers(options) {
  this.config = util.mixin(util.clone(config), options || {});

  this.ancestor = [];
}

/**
 * Wraps the attribute in quotes, or anything that needs them.
 *
 * @param {String} value
 * @return {String}
 * @api public
 */
Helpers.prototype.quote = function quote(value) {
  var end = value[value.length - 1];

  //
  // Quote is only called if required so it's safe to return quotes on no value.
  //
  if (!value) return '""';

  //
  // Always quote attributes having spaces, equal signs,
  // having single quotes or ending in a slash.
  //
  return end === '/' || ~value.indexOf("'") || /[\s=]+/.test(value) || this.config.quotes
    ? '"' + value + '"'
    : value;
};

/**
 * Is an element inline or not.
 *
 * @param {Object} element
 * @return {Boolean}
 * @api private
 */
Helpers.prototype.isInline = function isInline(element) {
  return !!~list.inline.indexOf(element.name);
};

/**
 * Create starting tag for element, if required an additional white space will
 * be added to retain flow of inline elements.
 *
 * @param {Object} element
 * @return {String}
 * @api public
 */
Helpers.prototype.tag = function tag(element) {
  //
  // Check if the current element requires structure, store for later reference.
  //
  if (this.structure(element)) this.ancestor.push(element);

  return '<' + element.name + this.attributes(element) + '>';
};

/**
 * Loop set of attributes belonging to an element. Surrounds attributes with
 * quotes if required, omits if not.
 *
 * @param {Object} element element containing attributes
 * @return {String}
 * @api public
 */
Helpers.prototype.attributes = function attributes(element) {
  var attr = element.attribs
    , self = this
    , name = element.name
    , value, bool, allowed;

  if (!attr || typeof attr !== 'object') return '';
  return Object.keys(attr).reduce(function (result, key) {
    value = attr[key];
    bool = ~list.redundant.indexOf(key);

    //
    // Is the attribute allowed on the HTML element? If so, allow special
    // treatment. If not, then just return the full attribute and its value.
    //
    allowed = list.attributes[key];
    allowed = allowed
      ? allowed === '*' || ~allowed.indexOf(name)
      : ~key.indexOf('data-');

    //
    // Remove attributes that are empty, not boolean and no semantic value.
    //
    if (!self.config.empty && !/data|itemscope/.test(key) && !bool && !value && allowed) return result;

    //
    // Boolean attributes should be added sparse, also unset attributes
    // should remain unset if retained with `empty` option.
    //
    result = result + ' ' + key;
    if (!self.config.spare && allowed && (bool || !value.length)) return result;

    //
    // Return full attribute with value.
    //
    return result + '=' + self.quote(compact(value).trim());
  }, '');
};

/**
 * Provide closing tag for element if required.
 *
 * @param {Object} element
 * @return {String}
 * @api public
 */
Helpers.prototype.close = function close(element) {
  if (this.structure(element)) this.ancestor.pop();

  return ~list.node.indexOf(element.type) && !~list.singular.indexOf(element.name)
    ? '</' + element.name + '>'
    : '';
};

/**
 * Check the script is actual script or abused for template/config. Scripts
 * without attribute type or type="text/javascript" are JS elements by default.
 *
 * @param {Object} element
 * @return {Boolean}
 * @api public
 */
Helpers.prototype.isJS = function isJS(element) {
  return (element.type === 'script' && (!element.attribs || !element.attribs.type))
    || (element.type === 'script' && element.attribs.type === 'text/javascript');
};

/**
 * Check if the element is of type style.
 *
 * @param {Object} element
 * @return {Boolean}
 * @api public
 */
Helpers.prototype.isStyle = function isStyle(element) {
  return element.type === 'style';
};

/**
 * Check if an element needs to retain its internal structure, e.g. this goes
 * for elements like script, style, textarea or pre.
 *
 * @param {Object} element
 * @return {Boolean}
 * @api public
 */
Helpers.prototype.structure = function structure(element) {
  return element.type !== 'text'
    ? !!~list.structural.indexOf(element.name) || this.isJS(element) || this.isStyle(element)
    : false;
};

/**
 * Return trimmed text, if text requires no structure new lines and spaces will
 * be replaced with a single white space. Any white space adjacent to an inline
 * element is replaced with a single space.
 *
 * @param {Object} element
 * @return {String} text
 * @api public
 */
Helpers.prototype.text = function text(element) {
  var ancestors = this.ancestor.length
    , content = element.data
    , next = element.next
    , prev = element.prev
    , space = this.config.loose ? ' ' : '';

  //
  // Collapse space between text and inline elements, clobber space without
  // inline elements.
  //
  if (!ancestors) {
    content = compact(content.replace(
      ancestors ? /^[^\S\n]+/ : /^\s+/,
      prev && this.isInline(prev) ? ' ' : space
    ).replace(
      ancestors ? /[^\S\n]+$/ : /\s+$/,
      next && this.isInline(next) ? ' ' : space
    ));
  }

  //
  // Remove CDATA from scripts.
  //
  if (!this.config.cdata && ancestors && this.isJS(this.ancestor[ancestors - 1])) {
    content = content.replace(/\/*<!\[CDATA\[/g, '').replace(/\/*\]\]>/g, '');
  }

  return content;
};

/**
 * Returned parsed comment or empty string if config.comments = true.
 *
 * @param {Object} element
 * @return {String} comment
 * @api public
 */
Helpers.prototype.comment = function comment(element) {
  var cfg = this.config;

  function io() {
    return '<!--' + compact(element.data, true).trim() + '-->';
  }

  if (cfg.ssi && ~element.data.indexOf('#include')) return io();
  if (cfg.conditionals && (~element.data.indexOf('[if')
      || ~element.data.indexOf('<![endif'))) return io();
  if (cfg.comments) return io();

  return '';
};

/**
 * Return parsed directive.
 *
 * @param {Object} element
 * @return {String} comment
 * @api public
 */
Helpers.prototype.directive = function directive(element) {
  return '<' + element.data + '>';
};

//
// Define some proxies for easy external reference.
//
Helpers.prototype.script = Helpers.prototype.tag;
Helpers.prototype.style = Helpers.prototype.tag;

//
// Create public proxies.
//
module.exports = Helpers;
