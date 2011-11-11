// fba9dc272a443cf9fdb984676a7732a6a082f4c0
/**
 * @class The built-in Array class.
 * @name Array
 */

/**
 * Creates a new array with the results of calling a provided function on every
 * element in this array. Implemented in Javascript 1.6.
 *
 * @function
 * @name Array.prototype.map
 * @see <a
 * href="https://developer.mozilla.org/En/Core_JavaScript_1.5_Reference/Objects/Array/Map">map</a>
 * documentation.
 * @param {function} f function that produces an element of the new Array from
 * an element of the current one.
 * @param [o] object to use as <tt>this</tt> when executing <tt>f</tt>.
 */
if (!Array.prototype.map) Array.prototype.map = function(f, o) {
  var n = this.length;
  var result = new Array(n);
  for (var i = 0; i < n; i++) {
    if (i in this) {
      result[i] = f.call(o, this[i], i, this);
    }
  }
  return result;
};

/**
 * Creates a new array with all elements that pass the test implemented by the
 * provided function. Implemented in Javascript 1.6.
 *
 * @function
 * @name Array.prototype.filter
 * @see <a
 * href="https://developer.mozilla.org/En/Core_JavaScript_1.5_Reference/Objects/Array/filter">filter</a>
 * documentation.
 * @param {function} f function to test each element of the array.
 * @param [o] object to use as <tt>this</tt> when executing <tt>f</tt>.
 */
if (!Array.prototype.filter) Array.prototype.filter = function(f, o) {
  var n = this.length;
  var result = new Array();
  for (var i = 0; i < n; i++) {
    if (i in this) {
      var v = this[i];
      if (f.call(o, v, i, this)) result.push(v);
    }
  }
  return result;
};

/**
 * Executes a provided function once per array element. Implemented in
 * Javascript 1.6.
 *
 * @function
 * @name Array.prototype.forEach
 * @see <a
 * href="https://developer.mozilla.org/En/Core_JavaScript_1.5_Reference/Objects/Array/ForEach">forEach</a>
 * documentation.
 * @param {function} f function to execute for each element.
 * @param [o] object to use as <tt>this</tt> when executing <tt>f</tt>.
 */
if (!Array.prototype.forEach) Array.prototype.forEach = function(f, o) {
  var n = this.length >>> 0;
  for (var i = 0; i < n; i++) {
    if (i in this) f.call(o, this[i], i, this);
  }
};

/**
 * Apply a function against an accumulator and each value of the array (from
 * left-to-right) as to reduce it to a single value. Implemented in Javascript
 * 1.8.
 *
 * @function
 * @name Array.prototype.reduce
 * @see <a
 * href="https://developer.mozilla.org/En/Core_JavaScript_1.5_Reference/Objects/Array/Reduce">reduce</a>
 * documentation.
 * @param {function} f function to execute on each value in the array.
 * @param [v] object to use as the first argument to the first call of
 * <tt>t</tt>.
 */
if (!Array.prototype.reduce) Array.prototype.reduce = function(f, v) {
  var len = this.length;
  if (!len && (arguments.length == 1)) {
    throw new Error("reduce: empty array, no initial value");
  }

  var i = 0;
  if (arguments.length < 2) {
    while (true) {
      if (i in this) {
        v = this[i++];
        break;
      }
      if (++i >= len) {
        throw new Error("reduce: no values, no initial value");
      }
    }
  }

  for (; i < len; i++) {
    if (i in this) {
      v = f(v, this[i], i, this);
    }
  }
  return v;
};
/**
 * The top-level Protovis namespace. All public methods and fields should be
 * registered on this object. Note that core Protovis source is surrounded by an
 * anonymous function, so any other declared globals will not be visible outside
 * of core methods. This also allows multiple versions of Protovis to coexist,
 * since each version will see their own <tt>pv</tt> namespace.
 *
 * @namespace The top-level Protovis namespace, <tt>pv</tt>.
 */
var pv = {};

/**
 * Protovis major and minor version numbers.
 *
 * @namespace Protovis major and minor version numbers.
 */
pv.version = {
  /**
   * The major version number.
   *
   * @type number
   * @constant
   */
  major: 3,

  /**
   * The minor version number.
   *
   * @type number
   * @constant
   */
  minor: 2
};

/**
 * Returns the passed-in argument, <tt>x</tt>; the identity function. This method
 * is provided for convenience since it is used as the default behavior for a
 * number of property functions.
 *
 * @param x a value.
 * @returns the value <tt>x</tt>.
 */
pv.identity = function(x) { return x; };

/**
 * Returns <tt>this.index</tt>. This method is provided for convenience for use
 * with scales. For example, to color bars by their index, say:
 *
 * <pre>.fillStyle(pv.Colors.category10().by(pv.index))</pre>
 *
 * This method is equivalent to <tt>function() this.index</tt>, but more
 * succinct. Note that the <tt>index</tt> property is also supported for
 * accessor functions with {@link pv.max}, {@link pv.min} and other array
 * utility methods.
 *
 * @see pv.Scale
 * @see pv.Mark#index
 */
pv.index = function() { return this.index; };

/**
 * Returns <tt>this.childIndex</tt>. This method is provided for convenience for
 * use with scales. For example, to color bars by their child index, say:
 *
 * <pre>.fillStyle(pv.Colors.category10().by(pv.child))</pre>
 *
 * This method is equivalent to <tt>function() this.childIndex</tt>, but more
 * succinct.
 *
 * @see pv.Scale
 * @see pv.Mark#childIndex
 */
pv.child = function() { return this.childIndex; };

/**
 * Returns <tt>this.parent.index</tt>. This method is provided for convenience
 * for use with scales. This method is provided for convenience for use with
 * scales. For example, to color bars by their parent index, say:
 *
 * <pre>.fillStyle(pv.Colors.category10().by(pv.parent))</pre>
 *
 * Tthis method is equivalent to <tt>function() this.parent.index</tt>, but more
 * succinct.
 *
 * @see pv.Scale
 * @see pv.Mark#index
 */
pv.parent = function() { return this.parent.index; };

/**
 * Stores the current event. This field is only set within event handlers.
 *
 * @type Event
 * @name pv.event
 */
/**
 * @private Returns a prototype object suitable for extending the given class
 * <tt>f</tt>. Rather than constructing a new instance of <tt>f</tt> to serve as
 * the prototype (which unnecessarily runs the constructor on the created
 * prototype object, potentially polluting it), an anonymous function is
 * generated internally that shares the same prototype:
 *
 * <pre>function g() {}
 * g.prototype = f.prototype;
 * return new g();</pre>
 *
 * For more details, see Douglas Crockford's essay on prototypal inheritance.
 *
 * @param {function} f a constructor.
 * @returns a suitable prototype object.
 * @see Douglas Crockford's essay on <a
 * href="http://javascript.crockford.com/prototypal.html">prototypal
 * inheritance</a>.
 */
pv.extend = function(f) {
  function g() {}
  g.prototype = f.prototype || f;
  return new g();
};

try {
  eval("pv.parse = function(x) x;"); // native support
} catch (e) {

/**
 * @private Parses a Protovis specification, which may use JavaScript 1.8
 * function expresses, replacing those function expressions with proper
 * functions such that the code can be run by a JavaScript 1.6 interpreter. This
 * hack only supports function expressions (using clumsy regular expressions, no
 * less), and not other JavaScript 1.8 features such as let expressions.
 *
 * @param {string} s a Protovis specification (i.e., a string of JavaScript 1.8
 * source code).
 * @returns {string} a conformant JavaScript 1.6 source code.
 */
  pv.parse = function(js) { // hacky regex support
    var re = new RegExp("function\\s*(\\b\\w+)?\\s*\\([^)]*\\)\\s*", "mg"), m, d, i = 0, s = "";
    while (m = re.exec(js)) {
      var j = m.index + m[0].length;
      if (js.charAt(j) != '{') {
        s += js.substring(i, j) + "{return ";
        i = j;
        for (var p = 0; p >= 0 && j < js.length; j++) {
          var c = js.charAt(j);
          switch (c) {
            case '"': case '\'': {
              while (++j < js.length && (d = js.charAt(j)) != c) {
                if (d == '\\') j++;
              }
              break;
            }
            case '[': case '(': p++; break;
            case ']': case ')': p--; break;
            case ';':
            case ',': if (p == 0) p--; break;
          }
        }
        s += pv.parse(js.substring(i, --j)) + ";}";
        i = j;
      }
      re.lastIndex = j;
    }
    s += js.substring(i);
    return s;
  };
}

/**
 * @private Computes the value of the specified CSS property <tt>p</tt> on the
 * specified element <tt>e</tt>.
 *
 * @param {string} p the name of the CSS property.
 * @param e the element on which to compute the CSS property.
 */
pv.css = function(e, p) {
  return window.getComputedStyle
      ? window.getComputedStyle(e, null).getPropertyValue(p)
      : e.currentStyle[p];
};

/**
 * @private Reports the specified error to the JavaScript console. Mozilla only
 * allows logging to the console for privileged code; if the console is
 * unavailable, the alert dialog box is used instead.
 *
 * @param e the exception that triggered the error.
 */
pv.error = function(e) {
  (typeof console == "undefined") ? alert(e) : console.error(e);
};

/**
 * @private Registers the specified listener for events of the specified type on
 * the specified target. For standards-compliant browsers, this method uses
 * <tt>addEventListener</tt>; for Internet Explorer, <tt>attachEvent</tt>.
 *
 * @param target a DOM element.
 * @param {string} type the type of event, such as "click".
 * @param {function} the event handler callback.
 */
pv.listen = function(target, type, listener) {
  listener = pv.listener(listener);
  return target.addEventListener
      ? target.addEventListener(type, listener, false)
      : target.attachEvent("on" + type, listener);
};

/**
 * @private Returns a wrapper for the specified listener function such that the
 * {@link pv.event} is set for the duration of the listener's invocation. The
 * wrapper is cached on the returned function, such that duplicate registrations
 * of the wrapped event handler are ignored.
 *
 * @param {function} f an event handler.
 * @returns {function} the wrapped event handler.
 */
pv.listener = function(f) {
  return f.$listener || (f.$listener = function(e) {
      try {
        pv.event = e;
        return f.call(this, e);
      } finally {
        delete pv.event;
      }
    });
};

/**
 * @private Returns true iff <i>a</i> is an ancestor of <i>e</i>. This is useful
 * for ignoring mouseout and mouseover events that are contained within the
 * target element.
 */
pv.ancestor = function(a, e) {
  while (e) {
    if (e == a) return true;
    e = e.parentNode;
  }
  return false;
};

/** @private Returns a locally-unique positive id. */
pv.id = function() {
  var id = 1; return function() { return id++; };
}();

/** @private Returns a function wrapping the specified constant. */
pv.functor = function(v) {
  return typeof v == "function" ? v : function() { return v; };
};
/*
 * Parses the Protovis specifications on load, allowing the use of JavaScript
 * 1.8 function expressions on browsers that only support JavaScript 1.6.
 *
 * @see pv.parse
 */
pv.listen(window, "load", function() {
   /*
    * Note: in Firefox any variables declared here are visible to the eval'd
    * script below. Even worse, any global variables declared by the script
    * could overwrite local variables here (such as the index, `i`)!  To protect
    * against this, all variables are explicitly scoped on a pv.$ object.
    */
    pv.$ = {i:0, x:document.getElementsByTagName("script")};
    for (; pv.$.i < pv.$.x.length; pv.$.i++) {
      pv.$.s = pv.$.x[pv.$.i];
      if (pv.$.s.type == "text/javascript+protovis") {
        try {
          window.eval(pv.parse(pv.$.s.text));
        } catch (e) {
          pv.error(e);
        }
      }
    }
    delete pv.$;
  });
/**
 * Abstract; see an implementing class.
 *
 * @class Represents an abstract text formatter and parser. A <i>format</i> is a
 * function that converts an object of a given type, such as a <tt>Date</tt>, to
 * a human-readable string representation. The format may also have a
 * {@link #parse} method for converting a string representation back to the
 * given object type.
 *
 * <p>Because formats are themselves functions, they can be used directly as
 * mark properties. For example, if the data associated with a label are dates,
 * a date format can be used as label text:
 *
 * <pre>    .text(pv.Format.date("%m/%d/%y"))</pre>
 *
 * And as with scales, if the format is used in multiple places, it can be
 * convenient to declare it as a global variable and then reference it from the
 * appropriate property functions. For example, if the data has a <tt>date</tt>
 * attribute, and <tt>format</tt> references a given date format:
 *
 * <pre>    .text(function(d) format(d.date))</pre>
 *
 * Similarly, to parse a string into a date:
 *
 * <pre>var date = format.parse("4/30/2010");</pre>
 *
 * Not all format implementations support parsing. See the implementing class
 * for details.
 *
 * @see pv.Format.date
 * @see pv.Format.number
 * @see pv.Format.time
 */
pv.Format = {};

/**
 * Formats the specified object, returning the string representation.
 *
 * @function
 * @name pv.Format.prototype.format
 * @param {object} x the object to format.
 * @returns {string} the formatted string.
 */

/**
 * Parses the specified string, returning the object representation.
 *
 * @function
 * @name pv.Format.prototype.parse
 * @param {string} x the string to parse.
 * @returns {object} the parsed object.
 */

/**
 * @private Given a string that may be used as part of a regular expression,
 * this methods returns an appropriately quoted version of the specified string,
 * with any special characters escaped.
 *
 * @param {string} s a string to quote.
 * @returns {string} the quoted string.
 */
pv.Format.re = function(s) {
  return s.replace(/[\\\^\$\*\+\?\[\]\(\)\.\{\}]/g, "\\$&");
};

/**
 * @private Optionally pads the specified string <i>s</i> so that it is at least
 * <i>n</i> characters long, using the padding character <i>c</i>.
 *
 * @param {string} c the padding character.
 * @param {number} n the minimum string length.
 * @param {string} s the string to pad.
 * @returns {string} the padded string.
 */
pv.Format.pad = function(c, n, s) {
  var m = n - String(s).length;
  return (m < 1) ? s : new Array(m + 1).join(c) + s;
};
/**
 * Constructs a new date format with the specified string pattern.
 *
 * @class The format string is in the same format expected by the
 * <tt>strftime</tt> function in C. The following conversion specifications are
 * supported:<ul>
 *
 * <li>%a - abbreviated weekday name.</li>
 * <li>%A - full weekday name.</li>
 * <li>%b - abbreviated month names.</li>
 * <li>%B - full month names.</li>
 * <li>%c - locale's appropriate date and time.</li>
 * <li>%C - century number.</li>
 * <li>%d - day of month [01,31] (zero padded).</li>
 * <li>%D - same as %m/%d/%y.</li>
 * <li>%e - day of month [ 1,31] (space padded).</li>
 * <li>%h - same as %b.</li>
 * <li>%H - hour (24-hour clock) [00,23] (zero padded).</li>
 * <li>%I - hour (12-hour clock) [01,12] (zero padded).</li>
 * <li>%m - month number [01,12] (zero padded).</li>
 * <li>%M - minute [0,59] (zero padded).</li>
 * <li>%n - newline character.</li>
 * <li>%p - locale's equivalent of a.m. or p.m.</li>
 * <li>%r - same as %I:%M:%S %p.</li>
 * <li>%R - same as %H:%M.</li>
 * <li>%S - second [00,61] (zero padded).</li>
 * <li>%t - tab character.</li>
 * <li>%T - same as %H:%M:%S.</li>
 * <li>%x - same as %m/%d/%y.</li>
 * <li>%X - same as %I:%M:%S %p.</li>
 * <li>%y - year with century [00,99] (zero padded).</li>
 * <li>%Y - year including century.</li>
 * <li>%% - %.</li>
 *
 * </ul>The following conversion specifications are currently <i>unsupported</i>
 * for formatting:<ul>
 *
 * <li>%j - day number [1,366].</li>
 * <li>%u - weekday number [1,7].</li>
 * <li>%U - week number [00,53].</li>
 * <li>%V - week number [01,53].</li>
 * <li>%w - weekday number [0,6].</li>
 * <li>%W - week number [00,53].</li>
 * <li>%Z - timezone name or abbreviation.</li>
 *
 * </ul>In addition, the following conversion specifications are currently
 * <i>unsupported</i> for parsing:<ul>
 *
 * <li>%a - day of week, either abbreviated or full name.</li>
 * <li>%A - same as %a.</li>
 * <li>%c - locale's appropriate date and time.</li>
 * <li>%C - century number.</li>
 * <li>%D - same as %m/%d/%y.</li>
 * <li>%I - hour (12-hour clock) [1,12].</li>
 * <li>%n - any white space.</li>
 * <li>%p - locale's equivalent of a.m. or p.m.</li>
 * <li>%r - same as %I:%M:%S %p.</li>
 * <li>%R - same as %H:%M.</li>
 * <li>%t - same as %n.</li>
 * <li>%T - same as %H:%M:%S.</li>
 * <li>%x - locale's equivalent to %m/%d/%y.</li>
 * <li>%X - locale's equivalent to %I:%M:%S %p.</li>
 *
 * </ul>
 *
 * @see <a
 * href="http://www.opengroup.org/onlinepubs/007908799/xsh/strftime.html">strftime</a>
 * documentation.
 * @see <a
 * href="http://www.opengroup.org/onlinepubs/007908799/xsh/strptime.html">strptime</a>
 * documentation.
 * @extends pv.Format
 * @param {string} pattern the format pattern.
 */
pv.Format.date = function(pattern) {
  var pad = pv.Format.pad;

  /** @private */
  function format(d) {
    return pattern.replace(/%[a-zA-Z0-9]/g, function(s) {
        switch (s) {
          case '%a': return [
              "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
            ][d.getDay()];
          case '%A': return [
              "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
              "Saturday"
            ][d.getDay()];
          case '%h':
          case '%b': return [
              "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep",
              "Oct", "Nov", "Dec"
            ][d.getMonth()];
          case '%B': return [
              "January", "February", "March", "April", "May", "June", "July",
              "August", "September", "October", "November", "December"
            ][d.getMonth()];
          case '%c': return d.toLocaleString();
          case '%C': return pad("0", 2, Math.floor(d.getFullYear() / 100) % 100);
          case '%d': return pad("0", 2, d.getDate());
          case '%x':
          case '%D': return pad("0", 2, d.getMonth() + 1)
                    + "/" + pad("0", 2, d.getDate())
                    + "/" + pad("0", 2, d.getFullYear() % 100);
          case '%e': return pad(" ", 2, d.getDate());
          case '%H': return pad("0", 2, d.getHours());
          case '%I': {
            var h = d.getHours() % 12;
            return h ? pad("0", 2, h) : 12;
          }
          // TODO %j: day of year as a decimal number [001,366]
          case '%m': return pad("0", 2, d.getMonth() + 1);
          case '%M': return pad("0", 2, d.getMinutes());
          case '%n': return "\n";
          case '%p': return d.getHours() < 12 ? "AM" : "PM";
          case '%T':
          case '%X':
          case '%r': {
            var h = d.getHours() % 12;
            return (h ? pad("0", 2, h) : 12)
                    + ":" + pad("0", 2, d.getMinutes())
                    + ":" + pad("0", 2, d.getSeconds())
                    + " " + (d.getHours() < 12 ? "AM" : "PM");
          }
          case '%R': return pad("0", 2, d.getHours()) + ":" + pad("0", 2, d.getMinutes());
          case '%S': return pad("0", 2, d.getSeconds());
          case '%Q': return pad("0", 3, d.getMilliseconds());
          case '%t': return "\t";
          case '%u': {
            var w = d.getDay();
            return w ? w : 1;
          }
          // TODO %U: week number (sunday first day) [00,53]
          // TODO %V: week number (monday first day) [01,53] ... with weirdness
          case '%w': return d.getDay();
          // TODO %W: week number (monday first day) [00,53] ... with weirdness
          case '%y': return pad("0", 2, d.getFullYear() % 100);
          case '%Y': return d.getFullYear();
          // TODO %Z: timezone name or abbreviation
          case '%%': return "%";
        }
        return s;
      });
  }

  /**
   * Converts a date to a string using the associated formatting pattern.
   *
   * @function
   * @name pv.Format.date.prototype.format
   * @param {Date} date a date to format.
   * @returns {string} the formatted date as a string.
   */
  format.format = format;

  /**
   * Parses a date from a string using the associated formatting pattern.
   *
   * @function
   * @name pv.Format.date.prototype.parse
   * @param {string} s the string to parse as a date.
   * @returns {Date} the parsed date.
   */
  format.parse = function(s) {
    var year = 1970, month = 0, date = 1, hour = 0, minute = 0, second = 0;
    var fields = [function() {}];

    /* Register callbacks for each field in the format pattern. */
    var re = pv.Format.re(pattern).replace(/%[a-zA-Z0-9]/g, function(s) {
        switch (s) {
          // TODO %a: day of week, either abbreviated or full name
          // TODO %A: same as %a
          case '%b': {
            fields.push(function(x) { month = {
                  Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5, Jul: 6, Aug: 7,
                  Sep: 8, Oct: 9, Nov: 10, Dec: 11
                }[x]; });
            return "([A-Za-z]+)";
          }
          case '%h':
          case '%B': {
            fields.push(function(x) { month = {
                  January: 0, February: 1, March: 2, April: 3, May: 4, June: 5,
                  July: 6, August: 7, September: 8, October: 9, November: 10,
                  December: 11
                }[x]; });
            return "([A-Za-z]+)";
          }
          // TODO %c: locale's appropriate date and time
          // TODO %C: century number[0,99]
          case '%e':
          case '%d': {
            fields.push(function(x) { date = x; });
            return "([0-9]+)";
          }
          // TODO %D: same as %m/%d/%y
          case '%I':
          case '%H': {
            fields.push(function(x) { hour = x; });
            return "([0-9]+)";
          }
          // TODO %j: day number [1,366]
          case '%m': {
            fields.push(function(x) { month = x - 1; });
            return "([0-9]+)";
          }
          case '%M': {
            fields.push(function(x) { minute = x; });
            return "([0-9]+)";
          }
          // TODO %n: any white space
          // TODO %p: locale's equivalent of a.m. or p.m.
          case '%p': { // TODO this is a hack
            fields.push(function(x) {
              if (hour == 12) {
                if (x == "am") hour = 0;
              } else if (x == "pm") {
                hour = Number(hour) + 12;
              }
            });
            return "(am|pm)";
          }
          // TODO %r: %I:%M:%S %p
          // TODO %R: %H:%M
          case '%S': {
            fields.push(function(x) { second = x; });
            return "([0-9]+)";
          }
          // TODO %t: any white space
          // TODO %T: %H:%M:%S
          // TODO %U: week number [00,53]
          // TODO %w: weekday [0,6]
          // TODO %W: week number [00, 53]
          // TODO %x: locale date (%m/%d/%y)
          // TODO %X: locale time (%I:%M:%S %p)
          case '%y': {
            fields.push(function(x) {
                x = Number(x);
                year = x + (((0 <= x) && (x < 69)) ? 2000
                    : (((x >= 69) && (x < 100) ? 1900 : 0)));
              });
            return "([0-9]+)";
          }
          case '%Y': {
            fields.push(function(x) { year = x; });
            return "([0-9]+)";
          }
          case '%%': {
            fields.push(function() {});
            return "%";
          }
        }
        return s;
      });

    var match = s.match(re);
    if (match) match.forEach(function(m, i) { fields[i](m); });
    return new Date(year, month, date, hour, minute, second);
  };

  return format;
};
/**
 * Returns a time format of the given type, either "short" or "long".
 *
 * @class Represents a time format, converting between a <tt>number</tt>
 * representing a duration in milliseconds, and a <tt>string</tt>. Two types of
 * time formats are supported: "short" and "long". The <i>short</i> format type
 * returns a string such as "3.3 days" or "12.1 minutes", while the <i>long</i>
 * format returns "13:04:12" or similar.
 *
 * @extends pv.Format
 * @param {string} type the type; "short" or "long".
 */
pv.Format.time = function(type) {
  var pad = pv.Format.pad;

  /*
   * MILLISECONDS = 1
   * SECONDS = 1e3
   * MINUTES = 6e4
   * HOURS = 36e5
   * DAYS = 864e5
   * WEEKS = 6048e5
   * MONTHS = 2592e6
   * YEARS = 31536e6
   */

  /** @private */
  function format(t) {
    t = Number(t); // force conversion from Date
    switch (type) {
      case "short": {
        if (t >= 31536e6) {
          return (t / 31536e6).toFixed(1) + " years";
        } else if (t >= 6048e5) {
          return (t / 6048e5).toFixed(1) + " weeks";
        } else if (t >= 864e5) {
          return (t / 864e5).toFixed(1) + " days";
        } else if (t >= 36e5) {
          return (t / 36e5).toFixed(1) + " hours";
        } else if (t >= 6e4) {
          return (t / 6e4).toFixed(1) + " minutes";
        }
        return (t / 1e3).toFixed(1) + " seconds";
      }
      case "long": {
        var a = [],
            s = ((t % 6e4) / 1e3) >> 0,
            m = ((t % 36e5) / 6e4) >> 0;
        a.push(pad("0", 2, s));
        if (t >= 36e5) {
          var h = ((t % 864e5) / 36e5) >> 0;
          a.push(pad("0", 2, m));
          if (t >= 864e5) {
            a.push(pad("0", 2, h));
            a.push(Math.floor(t / 864e5).toFixed());
          } else {
            a.push(h.toFixed());
          }
        } else {
          a.push(m.toFixed());
        }
        return a.reverse().join(":");
      }
    }
  }

  /**
   * Formats the specified time, returning the string representation.
   *
   * @function
   * @name pv.Format.time.prototype.format
   * @param {number} t the duration in milliseconds. May also be a <tt>Date</tt>.
   * @returns {string} the formatted string.
   */
  format.format = format;

  /**
   * Parses the specified string, returning the time in milliseconds.
   *
   * @function
   * @name pv.Format.time.prototype.parse
   * @param {string} s a formatted string.
   * @returns {number} the parsed duration in milliseconds.
   */
  format.parse = function(s) {
    switch (type) {
      case "short": {
        var re = /([0-9,.]+)\s*([a-z]+)/g, a, t = 0;
        while (a = re.exec(s)) {
          var f = parseFloat(a[0].replace(",", "")), u = 0;
          switch (a[2].toLowerCase()) {
            case "year": case "years": u = 31536e6; break;
            case "week": case "weeks": u = 6048e5; break;
            case "day": case "days": u = 864e5; break;
            case "hour": case "hours": u = 36e5; break;
            case "minute": case "minutes": u = 6e4; break;
            case "second": case "seconds": u = 1e3; break;
          }
          t += f * u;
        }
        return t;
      }
      case "long": {
        var a = s.replace(",", "").split(":").reverse(), t = 0;
        if (a.length) t += parseFloat(a[0]) * 1e3;
        if (a.length > 1) t += parseFloat(a[1]) * 6e4;
        if (a.length > 2) t += parseFloat(a[2]) * 36e5;
        if (a.length > 3) t += parseFloat(a[3]) * 864e5;
        return t;
      }
    }
  }

  return format;
};
/**
 * Returns a default number format.
 *
 * @class Represents a number format, converting between a <tt>number</tt> and a
 * <tt>string</tt>. This class allows numbers to be formatted with variable
 * precision (both for the integral and fractional part of the number), optional
 * thousands grouping, and optional padding. The thousands (",") and decimal
 * (".") separator can be customized.
 *
 * @returns {pv.Format.number} a number format.
 */
pv.Format.number = function() {
  var mini = 0, // default minimum integer digits
      maxi = Infinity, // default maximum integer digits
      mins = 0, // mini, including group separators
      minf = 0, // default minimum fraction digits
      maxf = 0, // default maximum fraction digits
      maxk = 1, // 10^maxf
      padi = "0", // default integer pad
      padf = "0", // default fraction pad
      padg = true, // whether group separator affects integer padding
      decimal = ".", // default decimal separator
      group = ","; // default group separator

  /** @private */
  function format(x) {
    /* Round the fractional part, and split on decimal separator. */
    if (Infinity > maxf) x = Math.round(x * maxk) / maxk;
    var s = String(Math.abs(x)).split(".");

    /* Pad, truncate and group the integral part. */
    var i = s[0], n = (x < 0) ? "-" : "";
    if (i.length > maxi) i = i.substring(i.length - maxi);
    if (padg && (i.length < mini)) i = n + new Array(mini - i.length + 1).join(padi) + i;
    if (i.length > 3) i = i.replace(/\B(?=(?:\d{3})+(?!\d))/g, group);
    if (!padg && (i.length < mins)) i = new Array(mins - i.length + 1).join(padi) + n + i;
    s[0] = i;

    /* Pad the fractional part. */
    var f = s[1] || "";
    if (f.length < minf) s[1] = f + new Array(minf - f.length + 1).join(padf);

    return s.join(decimal);
  }

  /**
   * @function
   * @name pv.Format.number.prototype.format
   * @param {number} x
   * @returns {string}
   */
  format.format = format;

  /**
   * Parses the specified string as a number. Before parsing, leading and
   * trailing padding is removed. Group separators are also removed, and the
   * decimal separator is replaced with the standard point ("."). The integer
   * part is truncated per the maximum integer digits, and the fraction part is
   * rounded per the maximum fraction digits.
   *
   * @function
   * @name pv.Format.number.prototype.parse
   * @param {string} x the string to parse.
   * @returns {number} the parsed number.
   */
  format.parse = function(x) {
    var re = pv.Format.re;

    /* Remove leading and trailing padding. Split on the decimal separator. */
    var s = String(x)
        .replace(new RegExp("^(" + re(padi) + ")*"), "")
        .replace(new RegExp("(" + re(padf) + ")*$"), "")
        .split(decimal);

    /* Remove grouping and truncate the integral part. */
    var i = s[0].replace(new RegExp(re(group), "g"), "");
    if (i.length > maxi) i = i.substring(i.length - maxi);

    /* Round the fractional part. */
    var f = s[1] ? Number("0." + s[1]) : 0;
    if (Infinity > maxf) f = Math.round(f * maxk) / maxk;

    return Math.round(i) + f;
  };

  /**
   * Sets or gets the minimum and maximum number of integer digits. This
   * controls the number of decimal digits to display before the decimal
   * separator for the integral part of the number. If the number of digits is
   * smaller than the minimum, the digits are padded; if the number of digits is
   * larger, the digits are truncated, showing only the lower-order digits. The
   * default range is [0, Infinity].
   *
   * <p>If only one argument is specified to this method, this value is used as
   * both the minimum and maximum number. If no arguments are specified, a
   * two-element array is returned containing the minimum and the maximum.
   *
   * @function
   * @name pv.Format.number.prototype.integerDigits
   * @param {number} [min] the minimum integer digits.
   * @param {number} [max] the maximum integer digits.
   * @returns {pv.Format.number} <tt>this</tt>, or the current integer digits.
   */
  format.integerDigits = function(min, max) {
    if (arguments.length) {
      mini = Number(min);
      maxi = (arguments.length > 1) ? Number(max) : mini;
      mins = mini + Math.floor(mini / 3) * group.length;
      return this;
    }
    return [mini, maxi];
  };

  /**
   * Sets or gets the minimum and maximum number of fraction digits. The
   * controls the number of decimal digits to display after the decimal
   * separator for the fractional part of the number. If the number of digits is
   * smaller than the minimum, the digits are padded; if the number of digits is
   * larger, the fractional part is rounded, showing only the higher-order
   * digits. The default range is [0, 0].
   *
   * <p>If only one argument is specified to this method, this value is used as
   * both the minimum and maximum number. If no arguments are specified, a
   * two-element array is returned containing the minimum and the maximum.
   *
   * @function
   * @name pv.Format.number.prototype.fractionDigits
   * @param {number} [min] the minimum fraction digits.
   * @param {number} [max] the maximum fraction digits.
   * @returns {pv.Format.number} <tt>this</tt>, or the current fraction digits.
   */
  format.fractionDigits = function(min, max) {
    if (arguments.length) {
      minf = Number(min);
      maxf = (arguments.length > 1) ? Number(max) : minf;
      maxk = Math.pow(10, maxf);
      return this;
    }
    return [minf, maxf];
  };

  /**
   * Sets or gets the character used to pad the integer part. The integer pad is
   * used when the number of integer digits is smaller than the minimum. The
   * default pad character is "0" (zero).
   *
   * @param {string} [x] the new pad character.
   * @returns {pv.Format.number} <tt>this</tt> or the current pad character.
   */
  format.integerPad = function(x) {
    if (arguments.length) {
      padi = String(x);
      padg = /\d/.test(padi);
      return this;
    }
    return padi;
  };

  /**
   * Sets or gets the character used to pad the fration part. The fraction pad
   * is used when the number of fraction digits is smaller than the minimum. The
   * default pad character is "0" (zero).
   *
   * @param {string} [x] the new pad character.
   * @returns {pv.Format.number} <tt>this</tt> or the current pad character.
   */
  format.fractionPad = function(x) {
    if (arguments.length) {
      padf = String(x);
      return this;
    }
    return padf;
  };

  /**
   * Sets or gets the character used as the decimal point, separating the
   * integer and fraction parts of the number. The default decimal point is ".".
   *
   * @param {string} [x] the new decimal separator.
   * @returns {pv.Format.number} <tt>this</tt> or the current decimal separator.
   */
  format.decimal = function(x) {
    if (arguments.length) {
      decimal = String(x);
      return this;
    }
    return decimal;
  };

  /**
   * Sets or gets the character used as the group separator, grouping integer
   * digits by thousands. The default decimal point is ",". Grouping can be
   * disabled by using "" for the separator.
   *
   * @param {string} [x] the new group separator.
   * @returns {pv.Format.number} <tt>this</tt> or the current group separator.
   */
  format.group = function(x) {
    if (arguments.length) {
      group = x ? String(x) : "";
      mins = mini + Math.floor(mini / 3) * group.length;
      return this;
    }
    return group;
  };

  return format;
};
/**
 * @private A private variant of Array.prototype.map that supports the index
 * property.
 */
pv.map = function(array, f) {
  var o = {};
  return f
      ? array.map(function(d, i) { o.index = i; return f.call(o, d); })
      : array.slice();
};

/**
 * Concatenates the specified array with itself <i>n</i> times. For example,
 * <tt>pv.repeat([1, 2])</tt> returns [1, 2, 1, 2].
 *
 * @param {array} a an array.
 * @param {number} [n] the number of times to repeat; defaults to two.
 * @returns {array} an array that repeats the specified array.
 */
pv.repeat = function(array, n) {
  if (arguments.length == 1) n = 2;
  return pv.blend(pv.range(n).map(function() { return array; }));
};

/**
 * Given two arrays <tt>a</tt> and <tt>b</tt>, <style
 * type="text/css">sub{line-height:0}</style> returns an array of all possible
 * pairs of elements [a<sub>i</sub>, b<sub>j</sub>]. The outer loop is on array
 * <i>a</i>, while the inner loop is on <i>b</i>, such that the order of
 * returned elements is [a<sub>0</sub>, b<sub>0</sub>], [a<sub>0</sub>,
 * b<sub>1</sub>], ... [a<sub>0</sub>, b<sub>m</sub>], [a<sub>1</sub>,
 * b<sub>0</sub>], [a<sub>1</sub>, b<sub>1</sub>], ... [a<sub>1</sub>,
 * b<sub>m</sub>], ... [a<sub>n</sub>, b<sub>m</sub>]. If either array is empty,
 * an empty array is returned.
 *
 * @param {array} a an array.
 * @param {array} b an array.
 * @returns {array} an array of pairs of elements in <tt>a</tt> and <tt>b</tt>.
 */
pv.cross = function(a, b) {
  var array = [];
  for (var i = 0, n = a.length, m = b.length; i < n; i++) {
    for (var j = 0, x = a[i]; j < m; j++) {
      array.push([x, b[j]]);
    }
  }
  return array;
};

/**
 * Given the specified array of arrays, concatenates the arrays into a single
 * array. If the individual arrays are explicitly known, an alternative to blend
 * is to use JavaScript's <tt>concat</tt> method directly. These two equivalent
 * expressions:<ul>
 *
 * <li><tt>pv.blend([[1, 2, 3], ["a", "b", "c"]])</tt>
 * <li><tt>[1, 2, 3].concat(["a", "b", "c"])</tt>
 *
 * </ul>return [1, 2, 3, "a", "b", "c"].
 *
 * @param {array[]} arrays an array of arrays.
 * @returns {array} an array containing all the elements of each array in
 * <tt>arrays</tt>.
 */
pv.blend = function(arrays) {
  return Array.prototype.concat.apply([], arrays);
};

/**
 * Given the specified array of arrays, <style
 * type="text/css">sub{line-height:0}</style> transposes each element
 * array<sub>ij</sub> with array<sub>ji</sub>. If the array has dimensions
 * <i>n</i>&times;<i>m</i>, it will have dimensions <i>m</i>&times;<i>n</i>
 * after this method returns. This method transposes the elements of the array
 * in place, mutating the array, and returning a reference to the array.
 *
 * @param {array[]} arrays an array of arrays.
 * @returns {array[]} the passed-in array, after transposing the elements.
 */
pv.transpose = function(arrays) {
  var n = arrays.length, m = pv.max(arrays, function(d) { return d.length; });

  if (m > n) {
    arrays.length = m;
    for (var i = n; i < m; i++) {
      arrays[i] = new Array(n);
    }
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < m; j++) {
        var t = arrays[i][j];
        arrays[i][j] = arrays[j][i];
        arrays[j][i] = t;
      }
    }
  } else {
    for (var i = 0; i < m; i++) {
      arrays[i].length = n;
    }
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < i; j++) {
        var t = arrays[i][j];
        arrays[i][j] = arrays[j][i];
        arrays[j][i] = t;
      }
    }
  }

  arrays.length = m;
  for (var i = 0; i < m; i++) {
    arrays[i].length = n;
  }

  return arrays;
};

/**
 * Returns a normalized copy of the specified array, such that the sum of the
 * returned elements sum to one. If the specified array is not an array of
 * numbers, an optional accessor function <tt>f</tt> can be specified to map the
 * elements to numbers. For example, if <tt>array</tt> is an array of objects,
 * and each object has a numeric property "foo", the expression
 *
 * <pre>pv.normalize(array, function(d) d.foo)</pre>
 *
 * returns a normalized array on the "foo" property. If an accessor function is
 * not specified, the identity function is used. Accessor functions can refer to
 * <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number[]} an array of numbers that sums to one.
 */
pv.normalize = function(array, f) {
  var norm = pv.map(array, f), sum = pv.sum(norm);
  for (var i = 0; i < norm.length; i++) norm[i] /= sum;
  return norm;
};

/**
 * Returns a permutation of the specified array, using the specified array of
 * indexes. The returned array contains the corresponding element in
 * <tt>array</tt> for each index in <tt>indexes</tt>, in order. For example,
 *
 * <pre>pv.permute(["a", "b", "c"], [1, 2, 0])</pre>
 *
 * returns <tt>["b", "c", "a"]</tt>. It is acceptable for the array of indexes
 * to be a different length from the array of elements, and for indexes to be
 * duplicated or omitted. The optional accessor function <tt>f</tt> can be used
 * to perform a simultaneous mapping of the array elements. Accessor functions
 * can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array.
 * @param {number[]} indexes an array of indexes into <tt>array</tt>.
 * @param {function} [f] an optional accessor function.
 * @returns {array} an array of elements from <tt>array</tt>; a permutation.
 */
pv.permute = function(array, indexes, f) {
  if (!f) f = pv.identity;
  var p = new Array(indexes.length), o = {};
  indexes.forEach(function(j, i) { o.index = j; p[i] = f.call(o, array[j]); });
  return p;
};

/**
 * Returns a map from key to index for the specified <tt>keys</tt> array. For
 * example,
 *
 * <pre>pv.numerate(["a", "b", "c"])</pre>
 *
 * returns <tt>{a: 0, b: 1, c: 2}</tt>. Note that since JavaScript maps only
 * support string keys, <tt>keys</tt> must contain strings, or other values that
 * naturally map to distinct string values. Alternatively, an optional accessor
 * function <tt>f</tt> can be specified to compute the string key for the given
 * element. Accessor functions can refer to <tt>this.index</tt>.
 *
 * @param {array} keys an array, usually of string keys.
 * @param {function} [f] an optional key function.
 * @returns a map from key to index.
 */
pv.numerate = function(keys, f) {
  if (!f) f = pv.identity;
  var map = {}, o = {};
  keys.forEach(function(x, i) { o.index = i; map[f.call(o, x)] = i; });
  return map;
};

/**
 * Returns the unique elements in the specified array, in the order they appear.
 * Note that since JavaScript maps only support string keys, <tt>array</tt> must
 * contain strings, or other values that naturally map to distinct string
 * values. Alternatively, an optional accessor function <tt>f</tt> can be
 * specified to compute the string key for the given element. Accessor functions
 * can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array, usually of string keys.
 * @param {function} [f] an optional key function.
 * @returns {array} the unique values.
 */
pv.uniq = function(array, f) {
  if (!f) f = pv.identity;
  var map = {}, keys = [], o = {}, y;
  array.forEach(function(x, i) {
    o.index = i;
    y = f.call(o, x);
    if (!(y in map)) map[y] = keys.push(y);
  });
  return keys;
};

/**
 * The comparator function for natural order. This can be used in conjunction with
 * the built-in array <tt>sort</tt> method to sort elements by their natural
 * order, ascending. Note that if no comparator function is specified to the
 * built-in <tt>sort</tt> method, the default order is lexicographic, <i>not</i>
 * natural!
 *
 * @see <a
 * href="http://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Global_Objects/Array/sort">Array.sort</a>.
 * @param a an element to compare.
 * @param b an element to compare.
 * @returns {number} negative if a &lt; b; positive if a &gt; b; otherwise 0.
 */
pv.naturalOrder = function(a, b) {
  return (a < b) ? -1 : ((a > b) ? 1 : 0);
};

/**
 * The comparator function for reverse natural order. This can be used in
 * conjunction with the built-in array <tt>sort</tt> method to sort elements by
 * their natural order, descending. Note that if no comparator function is
 * specified to the built-in <tt>sort</tt> method, the default order is
 * lexicographic, <i>not</i> natural!
 *
 * @see #naturalOrder
 * @param a an element to compare.
 * @param b an element to compare.
 * @returns {number} negative if a &lt; b; positive if a &gt; b; otherwise 0.
 */
pv.reverseOrder = function(b, a) {
  return (a < b) ? -1 : ((a > b) ? 1 : 0);
};

/**
 * Searches the specified array of numbers for the specified value using the
 * binary search algorithm. The array must be sorted (as by the <tt>sort</tt>
 * method) prior to making this call. If it is not sorted, the results are
 * undefined. If the array contains multiple elements with the specified value,
 * there is no guarantee which one will be found.
 *
 * <p>The <i>insertion point</i> is defined as the point at which the value
 * would be inserted into the array: the index of the first element greater than
 * the value, or <tt>array.length</tt>, if all elements in the array are less
 * than the specified value. Note that this guarantees that the return value
 * will be nonnegative if and only if the value is found.
 *
 * @param {number[]} array the array to be searched.
 * @param {number} value the value to be searched for.
 * @returns the index of the search value, if it is contained in the array;
 * otherwise, (-(<i>insertion point</i>) - 1).
 * @param {function} [f] an optional key function.
 */
pv.search = function(array, value, f) {
  if (!f) f = pv.identity;
  var low = 0, high = array.length - 1;
  while (low <= high) {
    var mid = (low + high) >> 1, midValue = f(array[mid]);
    if (midValue < value) low = mid + 1;
    else if (midValue > value) high = mid - 1;
    else return mid;
  }
  return -low - 1;
};

pv.search.index = function(array, value, f) {
  var i = pv.search(array, value, f);
  return (i < 0) ? (-i - 1) : i;
};
/**
 * Returns an array of numbers, starting at <tt>start</tt>, incrementing by
 * <tt>step</tt>, until <tt>stop</tt> is reached. The stop value is
 * exclusive. If only a single argument is specified, this value is interpeted
 * as the <i>stop</i> value, with the <i>start</i> value as zero. If only two
 * arguments are specified, the step value is implied to be one.
 *
 * <p>The method is modeled after the built-in <tt>range</tt> method from
 * Python. See the Python documentation for more details.
 *
 * @see <a href="http://docs.python.org/library/functions.html#range">Python range</a>
 * @param {number} [start] the start value.
 * @param {number} stop the stop value.
 * @param {number} [step] the step value.
 * @returns {number[]} an array of numbers.
 */
pv.range = function(start, stop, step) {
  if (arguments.length == 1) {
    stop = start;
    start = 0;
  }
  if (step == undefined) step = 1;
  if ((stop - start) / step == Infinity) throw new Error("range must be finite");
  var array = [], i = 0, j;
  if (step < 0) {
    while ((j = start + step * i++) > stop) {
      array.push(j);
    }
  } else {
    while ((j = start + step * i++) < stop) {
      array.push(j);
    }
  }
  return array;
};

/**
 * Returns a random number in the range [<tt>start</tt>, <tt>stop</tt>) that is
 * a multiple of <tt>step</tt>. More specifically, the returned number is of the
 * form <tt>start</tt> + <i>n</i> * <tt>step</tt>, where <i>n</i> is a
 * nonnegative integer. If <tt>step</tt> is not specified, it defaults to 1,
 * returning a random integer if <tt>start</tt> is also an integer.
 *
 * @param {number} [start] the start value value.
 * @param {number} stop the stop value.
 * @param {number} [step] the step value.
 * @returns {number} a random number between <i>start</i> and <i>stop</i>.
 */
pv.random = function(start, stop, step) {
  if (arguments.length == 1) {
    stop = start;
    start = 0;
  }
  if (step == undefined) step = 1;
  return step
      ? (Math.floor(Math.random() * (stop - start) / step) * step + start)
      : (Math.random() * (stop - start) + start);
};

/**
 * Returns the sum of the specified array. If the specified array is not an
 * array of numbers, an optional accessor function <tt>f</tt> can be specified
 * to map the elements to numbers. See {@link #normalize} for an example.
 * Accessor functions can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the sum of the specified array.
 */
pv.sum = function(array, f) {
  var o = {};
  return array.reduce(f
      ? function(p, d, i) { o.index = i; return p + f.call(o, d); }
      : function(p, d) { return p + d; }, 0);
};

/**
 * Returns the maximum value of the specified array. If the specified array is
 * not an array of numbers, an optional accessor function <tt>f</tt> can be
 * specified to map the elements to numbers. See {@link #normalize} for an
 * example. Accessor functions can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the maximum value of the specified array.
 */
pv.max = function(array, f) {
  if (f == pv.index) return array.length - 1;
  return Math.max.apply(null, f ? pv.map(array, f) : array);
};

/**
 * Returns the index of the maximum value of the specified array. If the
 * specified array is not an array of numbers, an optional accessor function
 * <tt>f</tt> can be specified to map the elements to numbers. See
 * {@link #normalize} for an example. Accessor functions can refer to
 * <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the index of the maximum value of the specified array.
 */
pv.max.index = function(array, f) {
  if (!array.length) return -1;
  if (f == pv.index) return array.length - 1;
  if (!f) f = pv.identity;
  var maxi = 0, maxx = -Infinity, o = {};
  for (var i = 0; i < array.length; i++) {
    o.index = i;
    var x = f.call(o, array[i]);
    if (x > maxx) {
      maxx = x;
      maxi = i;
    }
  }
  return maxi;
}

/**
 * Returns the minimum value of the specified array of numbers. If the specified
 * array is not an array of numbers, an optional accessor function <tt>f</tt>
 * can be specified to map the elements to numbers. See {@link #normalize} for
 * an example. Accessor functions can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the minimum value of the specified array.
 */
pv.min = function(array, f) {
  if (f == pv.index) return 0;
  return Math.min.apply(null, f ? pv.map(array, f) : array);
};

/**
 * Returns the index of the minimum value of the specified array. If the
 * specified array is not an array of numbers, an optional accessor function
 * <tt>f</tt> can be specified to map the elements to numbers. See
 * {@link #normalize} for an example. Accessor functions can refer to
 * <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the index of the minimum value of the specified array.
 */
pv.min.index = function(array, f) {
  if (!array.length) return -1;
  if (f == pv.index) return 0;
  if (!f) f = pv.identity;
  var mini = 0, minx = Infinity, o = {};
  for (var i = 0; i < array.length; i++) {
    o.index = i;
    var x = f.call(o, array[i]);
    if (x < minx) {
      minx = x;
      mini = i;
    }
  }
  return mini;
}

/**
 * Returns the arithmetic mean, or average, of the specified array. If the
 * specified array is not an array of numbers, an optional accessor function
 * <tt>f</tt> can be specified to map the elements to numbers. See
 * {@link #normalize} for an example. Accessor functions can refer to
 * <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the mean of the specified array.
 */
pv.mean = function(array, f) {
  return pv.sum(array, f) / array.length;
};

/**
 * Returns the median of the specified array. If the specified array is not an
 * array of numbers, an optional accessor function <tt>f</tt> can be specified
 * to map the elements to numbers. See {@link #normalize} for an example.
 * Accessor functions can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the median of the specified array.
 */
pv.median = function(array, f) {
  if (f == pv.index) return (array.length - 1) / 2;
  array = pv.map(array, f).sort(pv.naturalOrder);
  if (array.length % 2) return array[Math.floor(array.length / 2)];
  var i = array.length / 2;
  return (array[i - 1] + array[i]) / 2;
};

/**
 * Returns the unweighted variance of the specified array. If the specified
 * array is not an array of numbers, an optional accessor function <tt>f</tt>
 * can be specified to map the elements to numbers. See {@link #normalize} for
 * an example. Accessor functions can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the variance of the specified array.
 */
pv.variance = function(array, f) {
  if (array.length < 1) return NaN;
  if (array.length == 1) return 0;
  var mean = pv.mean(array, f), sum = 0, o = {};
  if (!f) f = pv.identity;
  for (var i = 0; i < array.length; i++) {
    o.index = i;
    var d = f.call(o, array[i]) - mean;
    sum += d * d;
  }
  return sum;
};

/**
 * Returns an unbiased estimation of the standard deviation of a population,
 * given the specified random sample. If the specified array is not an array of
 * numbers, an optional accessor function <tt>f</tt> can be specified to map the
 * elements to numbers. See {@link #normalize} for an example. Accessor
 * functions can refer to <tt>this.index</tt>.
 *
 * @param {array} array an array of objects, or numbers.
 * @param {function} [f] an optional accessor function.
 * @returns {number} the standard deviation of the specified array.
 */
pv.deviation = function(array, f) {
  return Math.sqrt(pv.variance(array, f) / (array.length - 1));
};

/**
 * Returns the logarithm with a given base value.
 *
 * @param {number} x the number for which to compute the logarithm.
 * @param {number} b the base of the logarithm.
 * @returns {number} the logarithm value.
 */
pv.log = function(x, b) {
  return Math.log(x) / Math.log(b);
};

/**
 * Computes a zero-symmetric logarithm. Computes the logarithm of the absolute
 * value of the input, and determines the sign of the output according to the
 * sign of the input value.
 *
 * @param {number} x the number for which to compute the logarithm.
 * @param {number} b the base of the logarithm.
 * @returns {number} the symmetric log value.
 */
pv.logSymmetric = function(x, b) {
  return (x == 0) ? 0 : ((x < 0) ? -pv.log(-x, b) : pv.log(x, b));
};

/**
 * Computes a zero-symmetric logarithm, with adjustment to values between zero
 * and the logarithm base. This adjustment introduces distortion for values less
 * than the base number, but enables simultaneous plotting of log-transformed
 * data involving both positive and negative numbers.
 *
 * @param {number} x the number for which to compute the logarithm.
 * @param {number} b the base of the logarithm.
 * @returns {number} the adjusted, symmetric log value.
 */
pv.logAdjusted = function(x, b) {
  if (!isFinite(x)) return x;
  var negative = x < 0;
  if (x < b) x += (b - x) / b;
  return negative ? -pv.log(x, b) : pv.log(x, b);
};

/**
 * Rounds an input value down according to its logarithm. The method takes the
 * floor of the logarithm of the value and then uses the resulting value as an
 * exponent for the base value.
 *
 * @param {number} x the number for which to compute the logarithm floor.
 * @param {number} b the base of the logarithm.
 * @returns {number} the rounded-by-logarithm value.
 */
pv.logFloor = function(x, b) {
  return (x > 0)
      ? Math.pow(b, Math.floor(pv.log(x, b)))
      : -Math.pow(b, -Math.floor(-pv.log(-x, b)));
};

/**
 * Rounds an input value up according to its logarithm. The method takes the
 * ceiling of the logarithm of the value and then uses the resulting value as an
 * exponent for the base value.
 *
 * @param {number} x the number for which to compute the logarithm ceiling.
 * @param {number} b the base of the logarithm.
 * @returns {number} the rounded-by-logarithm value.
 */
pv.logCeil = function(x, b) {
  return (x > 0)
      ? Math.pow(b, Math.ceil(pv.log(x, b)))
      : -Math.pow(b, -Math.ceil(-pv.log(-x, b)));
};

(function() {
  var radians = Math.PI / 180,
      degrees = 180 / Math.PI;

  /** Returns the number of radians corresponding to the specified degrees. */
  pv.radians = function(degrees) { return radians * degrees; };

  /** Returns the number of degrees corresponding to the specified radians. */
  pv.degrees = function(radians) { return degrees * radians; };
})();
/**
 * Returns all of the property names (keys) of the specified object (a map). The
 * order of the returned array is not defined.
 *
 * @param map an object.
 * @returns {string[]} an array of strings corresponding to the keys.
 * @see #entries
 */
pv.keys = function(map) {
  var array = [];
  for (var key in map) {
    array.push(key);
  }
  return array;
};

/**
 * Returns all of the entries (key-value pairs) of the specified object (a
 * map). The order of the returned array is not defined. Each key-value pair is
 * represented as an object with <tt>key</tt> and <tt>value</tt> attributes,
 * e.g., <tt>{key: "foo", value: 42}</tt>.
 *
 * @param map an object.
 * @returns {array} an array of key-value pairs corresponding to the keys.
 */
pv.entries = function(map) {
  var array = [];
  for (var key in map) {
    array.push({ key: key, value: map[key] });
  }
  return array;
};

/**
 * Returns all of the values (attribute values) of the specified object (a
 * map). The order of the returned array is not defined.
 *
 * @param map an object.
 * @returns {array} an array of objects corresponding to the values.
 * @see #entries
 */
pv.values = function(map) {
  var array = [];
  for (var key in map) {
    array.push(map[key]);
  }
  return array;
};

/**
 * Returns a map constructed from the specified <tt>keys</tt>, using the
 * function <tt>f</tt> to compute the value for each key. The single argument to
 * the value function is the key. The callback is invoked only for indexes of
 * the array which have assigned values; it is not invoked for indexes which
 * have been deleted or which have never been assigned values.
 *
 * <p>For example, this expression creates a map from strings to string length:
 *
 * <pre>pv.dict(["one", "three", "seventeen"], function(s) s.length)</pre>
 *
 * The returned value is <tt>{one: 3, three: 5, seventeen: 9}</tt>. Accessor
 * functions can refer to <tt>this.index</tt>.
 *
 * @param {array} keys an array.
 * @param {function} f a value function.
 * @returns a map from keys to values.
 */
pv.dict = function(keys, f) {
  var m = {}, o = {};
  for (var i = 0; i < keys.length; i++) {
    if (i in keys) {
      var k = keys[i];
      o.index = i;
      m[k] = f.call(o, k);
    }
  }
  return m;
};
/**
 * Returns a {@link pv.Dom} operator for the given map. This is a convenience
 * factory method, equivalent to <tt>new pv.Dom(map)</tt>. To apply the operator
 * and retrieve the root node, call {@link pv.Dom#root}; to retrieve all nodes
 * flattened, use {@link pv.Dom#nodes}.
 *
 * @see pv.Dom
 * @param map a map from which to construct a DOM.
 * @returns {pv.Dom} a DOM operator for the specified map.
 */
pv.dom = function(map) {
  return new pv.Dom(map);
};

/**
 * Constructs a DOM operator for the specified map. This constructor should not
 * be invoked directly; use {@link pv.dom} instead.
 *
 * @class Represets a DOM operator for the specified map. This allows easy
 * transformation of a hierarchical JavaScript object (such as a JSON map) to a
 * W3C Document Object Model hierarchy. For more information on which attributes
 * and methods from the specification are supported, see {@link pv.Dom.Node}.
 *
 * <p>Leaves in the map are determined using an associated <i>leaf</i> function;
 * see {@link #leaf}. By default, leaves are any value whose type is not
 * "object", such as numbers or strings.
 *
 * @param map a map from which to construct a DOM.
 */
pv.Dom = function(map) {
  this.$map = map;
};

/** @private The default leaf function. */
pv.Dom.prototype.$leaf = function(n) {
  return typeof n != "object";
};

/**
 * Sets or gets the leaf function for this DOM operator. The leaf function
 * identifies which values in the map are leaves, and which are internal nodes.
 * By default, objects are considered internal nodes, and primitives (such as
 * numbers and strings) are considered leaves.
 *
 * @param {function} f the new leaf function.
 * @returns the current leaf function, or <tt>this</tt>.
 */
pv.Dom.prototype.leaf = function(f) {
  if (arguments.length) {
    this.$leaf = f;
    return this;
  }
  return this.$leaf;
};

/**
 * Applies the DOM operator, returning the root node.
 *
 * @returns {pv.Dom.Node} the root node.
 * @param {string} [nodeName] optional node name for the root.
 */
pv.Dom.prototype.root = function(nodeName) {
  var leaf = this.$leaf, root = recurse(this.$map);

  /** @private */
  function recurse(map) {
    var n = new pv.Dom.Node();
    for (var k in map) {
      var v = map[k];
      n.appendChild(leaf(v) ? new pv.Dom.Node(v) : recurse(v)).nodeName = k;
    }
    return n;
  }

  root.nodeName = nodeName;
  return root;
};

/**
 * Applies the DOM operator, returning the array of all nodes in preorder
 * traversal.
 *
 * @returns {array} the array of nodes in preorder traversal.
 */
pv.Dom.prototype.nodes = function() {
  return this.root().nodes();
};

/**
 * Constructs a DOM node for the specified value. Instances of this class are
 * not typically created directly; instead they are generated from a JavaScript
 * map using the {@link pv.Dom} operator.
 *
 * @class Represents a <tt>Node</tt> in the W3C Document Object Model.
 */
pv.Dom.Node = function(value) {
  this.nodeValue = value;
  this.childNodes = [];
};

/**
 * The node name. When generated from a map, the node name corresponds to the
 * key at the given level in the map. Note that the root node has no associated
 * key, and thus has an undefined node name (and no <tt>parentNode</tt>).
 *
 * @type string
 * @field pv.Dom.Node.prototype.nodeName
 */

/**
 * The node value. When generated from a map, node value corresponds to the leaf
 * value for leaf nodes, and is undefined for internal nodes.
 *
 * @field pv.Dom.Node.prototype.nodeValue
 */

/**
 * The array of child nodes. This array is empty for leaf nodes. An easy way to
 * check if child nodes exist is to query <tt>firstChild</tt>.
 *
 * @type array
 * @field pv.Dom.Node.prototype.childNodes
 */

/**
 * The parent node, which is null for root nodes.
 *
 * @type pv.Dom.Node
 */
pv.Dom.Node.prototype.parentNode = null;

/**
 * The first child, which is null for leaf nodes.
 *
 * @type pv.Dom.Node
 */
pv.Dom.Node.prototype.firstChild = null;

/**
 * The last child, which is null for leaf nodes.
 *
 * @type pv.Dom.Node
 */
pv.Dom.Node.prototype.lastChild = null;

/**
 * The previous sibling node, which is null for the first child.
 *
 * @type pv.Dom.Node
 */
pv.Dom.Node.prototype.previousSibling = null;

/**
 * The next sibling node, which is null for the last child.
 *
 * @type pv.Dom.Node
 */
pv.Dom.Node.prototype.nextSibling = null;

/**
 * Removes the specified child node from this node.
 *
 * @throws Error if the specified child is not a child of this node.
 * @returns {pv.Dom.Node} the removed child.
 */
pv.Dom.Node.prototype.removeChild = function(n) {
  var i = this.childNodes.indexOf(n);
  if (i == -1) throw new Error("child not found");
  this.childNodes.splice(i, 1);
  if (n.previousSibling) n.previousSibling.nextSibling = n.nextSibling;
  else this.firstChild = n.nextSibling;
  if (n.nextSibling) n.nextSibling.previousSibling = n.previousSibling;
  else this.lastChild = n.previousSibling;
  delete n.nextSibling;
  delete n.previousSibling;
  delete n.parentNode;
  return n;
};

/**
 * Appends the specified child node to this node. If the specified child is
 * already part of the DOM, the child is first removed before being added to
 * this node.
 *
 * @returns {pv.Dom.Node} the appended child.
 */
pv.Dom.Node.prototype.appendChild = function(n) {
  if (n.parentNode) n.parentNode.removeChild(n);
  n.parentNode = this;
  n.previousSibling = this.lastChild;
  if (this.lastChild) this.lastChild.nextSibling = n;
  else this.firstChild = n;
  this.lastChild = n;
  this.childNodes.push(n);
  return n;
};

/**
 * Inserts the specified child <i>n</i> before the given reference child
 * <i>r</i> of this node. If <i>r</i> is null, this method is equivalent to
 * {@link #appendChild}. If <i>n</i> is already part of the DOM, it is first
 * removed before being inserted.
 *
 * @throws Error if <i>r</i> is non-null and not a child of this node.
 * @returns {pv.Dom.Node} the inserted child.
 */
pv.Dom.Node.prototype.insertBefore = function(n, r) {
  if (!r) return this.appendChild(n);
  var i = this.childNodes.indexOf(r);
  if (i == -1) throw new Error("child not found");
  if (n.parentNode) n.parentNode.removeChild(n);
  n.parentNode = this;
  n.nextSibling = r;
  n.previousSibling = r.previousSibling;
  if (r.previousSibling) {
    r.previousSibling.nextSibling = n;
  } else {
    if (r == this.lastChild) this.lastChild = n;
    this.firstChild = n;
  }
  this.childNodes.splice(i, 0, n);
  return n;
};

/**
 * Replaces the specified child <i>r</i> of this node with the node <i>n</i>. If
 * <i>n</i> is already part of the DOM, it is first removed before being added.
 *
 * @throws Error if <i>r</i> is not a child of this node.
 */
pv.Dom.Node.prototype.replaceChild = function(n, r) {
  var i = this.childNodes.indexOf(r);
  if (i == -1) throw new Error("child not found");
  if (n.parentNode) n.parentNode.removeChild(n);
  n.parentNode = this;
  n.nextSibling = r.nextSibling;
  n.previousSibling = r.previousSibling;
  if (r.previousSibling) r.previousSibling.nextSibling = n;
  else this.firstChild = n;
  if (r.nextSibling) r.nextSibling.previousSibling = n;
  else this.lastChild = n;
  this.childNodes[i] = n;
  return r;
};

/**
 * Visits each node in the tree in preorder traversal, applying the specified
 * function <i>f</i>. The arguments to the function are:<ol>
 *
 * <li>The current node.
 * <li>The current depth, starting at 0 for the root node.</ol>
 *
 * @param {function} f a function to apply to each node.
 */
pv.Dom.Node.prototype.visitBefore = function(f) {
  function visit(n, i) {
    f(n, i);
    for (var c = n.firstChild; c; c = c.nextSibling) {
      visit(c, i + 1);
    }
  }
  visit(this, 0);
};

/**
 * Visits each node in the tree in postorder traversal, applying the specified
 * function <i>f</i>. The arguments to the function are:<ol>
 *
 * <li>The current node.
 * <li>The current depth, starting at 0 for the root node.</ol>
 *
 * @param {function} f a function to apply to each node.
 */
pv.Dom.Node.prototype.visitAfter = function(f) {
  function visit(n, i) {
    for (var c = n.firstChild; c; c = c.nextSibling) {
      visit(c, i + 1);
    }
    f(n, i);
  }
  visit(this, 0);
};

/**
 * Sorts child nodes of this node, and all descendent nodes recursively, using
 * the specified comparator function <tt>f</tt>. The comparator function is
 * passed two nodes to compare.
 *
 * <p>Note: during the sort operation, the comparator function should not rely
 * on the tree being well-formed; the values of <tt>previousSibling</tt> and
 * <tt>nextSibling</tt> for the nodes being compared are not defined during the
 * sort operation.
 *
 * @param {function} f a comparator function.
 * @returns this.
 */
pv.Dom.Node.prototype.sort = function(f) {
  if (this.firstChild) {
    this.childNodes.sort(f);
    var p = this.firstChild = this.childNodes[0], c;
    delete p.previousSibling;
    for (var i = 1; i < this.childNodes.length; i++) {
      p.sort(f);
      c = this.childNodes[i];
      c.previousSibling = p;
      p = p.nextSibling = c;
    }
    this.lastChild = p;
    delete p.nextSibling;
    p.sort(f);
  }
  return this;
};

/**
 * Reverses all sibling nodes.
 *
 * @returns this.
 */
pv.Dom.Node.prototype.reverse = function() {
  var childNodes = [];
  this.visitAfter(function(n) {
      while (n.lastChild) childNodes.push(n.removeChild(n.lastChild));
      for (var c; c = childNodes.pop();) n.insertBefore(c, n.firstChild);
    });
  return this;
};

/** Returns all descendants of this node in preorder traversal. */
pv.Dom.Node.prototype.nodes = function() {
  var array = [];

  /** @private */
  function flatten(node) {
    array.push(node);
    node.childNodes.forEach(flatten);
  }

  flatten(this, array);
  return array;
};

/**
 * Toggles the child nodes of this node. If this node is not yet toggled, this
 * method removes all child nodes and appends them to a new <tt>toggled</tt>
 * array attribute on this node. Otherwise, if this node is toggled, this method
 * re-adds all toggled child nodes and deletes the <tt>toggled</tt> attribute.
 *
 * <p>This method has no effect if the node has no child nodes.
 *
 * @param {boolean} [recursive] whether the toggle should apply to descendants.
 */
pv.Dom.Node.prototype.toggle = function(recursive) {
  if (recursive) return this.toggled
      ? this.visitBefore(function(n) { if (n.toggled) n.toggle(); })
      : this.visitAfter(function(n) { if (!n.toggled) n.toggle(); });
  var n = this;
  if (n.toggled) {
    for (var c; c = n.toggled.pop();) n.appendChild(c);
    delete n.toggled;
  } else if (n.lastChild) {
    n.toggled = [];
    while (n.lastChild) n.toggled.push(n.removeChild(n.lastChild));
  }
};

/**
 * Given a flat array of values, returns a simple DOM with each value wrapped by
 * a node that is a child of the root node.
 *
 * @param {array} values.
 * @returns {array} nodes.
 */
pv.nodes = function(values) {
  var root = new pv.Dom.Node();
  for (var i = 0; i < values.length; i++) {
    root.appendChild(new pv.Dom.Node(values[i]));
  }
  return root.nodes();
};
/**
 * Returns a {@link pv.Tree} operator for the specified array. This is a
 * convenience factory method, equivalent to <tt>new pv.Tree(array)</tt>.
 *
 * @see pv.Tree
 * @param {array} array an array from which to construct a tree.
 * @returns {pv.Tree} a tree operator for the specified array.
 */
pv.tree = function(array) {
  return new pv.Tree(array);
};

/**
 * Constructs a tree operator for the specified array. This constructor should
 * not be invoked directly; use {@link pv.tree} instead.
 *
 * @class Represents a tree operator for the specified array. The tree operator
 * allows a hierarchical map to be constructed from an array; it is similar to
 * the {@link pv.Nest} operator, except the hierarchy is derived dynamically
 * from the array elements.
 *
 * <p>For example, given an array of size information for ActionScript classes:
 *
 * <pre>{ name: "flare.flex.FlareVis", size: 4116 },
 * { name: "flare.physics.DragForce", size: 1082 },
 * { name: "flare.physics.GravityForce", size: 1336 }, ...</pre>
 *
 * To facilitate visualization, it may be useful to nest the elements by their
 * package hierarchy:
 *
 * <pre>var tree = pv.tree(classes)
 *     .keys(function(d) d.name.split("."))
 *     .map();</pre>
 *
 * The resulting tree is:
 *
 * <pre>{ flare: {
 *     flex: {
 *       FlareVis: {
 *         name: "flare.flex.FlareVis",
 *         size: 4116 } },
 *     physics: {
 *       DragForce: {
 *         name: "flare.physics.DragForce",
 *         size: 1082 },
 *       GravityForce: {
 *         name: "flare.physics.GravityForce",
 *         size: 1336 } },
 *     ... } }</pre>
 *
 * By specifying a value function,
 *
 * <pre>var tree = pv.tree(classes)
 *     .keys(function(d) d.name.split("."))
 *     .value(function(d) d.size)
 *     .map();</pre>
 *
 * we can further eliminate redundant data:
 *
 * <pre>{ flare: {
 *     flex: {
 *       FlareVis: 4116 },
 *     physics: {
 *       DragForce: 1082,
 *       GravityForce: 1336 },
 *   ... } }</pre>
 *
 * For visualizations with large data sets, performance improvements may be seen
 * by storing the data in a tree format, and then flattening it into an array at
 * runtime with {@link pv.Flatten}.
 *
 * @param {array} array an array from which to construct a tree.
 */
pv.Tree = function(array) {
  this.array = array;
};

/**
 * Assigns a <i>keys</i> function to this operator; required. The keys function
 * returns an array of <tt>string</tt>s for each element in the associated
 * array; these keys determine how the elements are nested in the tree. The
 * returned keys should be unique for each element in the array; otherwise, the
 * behavior of this operator is undefined.
 *
 * @param {function} k the keys function.
 * @returns {pv.Tree} this.
 */
pv.Tree.prototype.keys = function(k) {
  this.k = k;
  return this;
};

/**
 * Assigns a <i>value</i> function to this operator; optional. The value
 * function specifies an optional transformation of the element in the array
 * before it is inserted into the map. If no value function is specified, it is
 * equivalent to using the identity function.
 *
 * @param {function} k the value function.
 * @returns {pv.Tree} this.
 */
pv.Tree.prototype.value = function(v) {
  this.v = v;
  return this;
};

/**
 * Returns a hierarchical map of values. The hierarchy is determined by the keys
 * function; the values in the map are determined by the value function.
 *
 * @returns a hierarchical map of values.
 */
pv.Tree.prototype.map = function() {
  var map = {}, o = {};
  for (var i = 0; i < this.array.length; i++) {
    o.index = i;
    var value = this.array[i], keys = this.k.call(o, value), node = map;
    for (var j = 0; j < keys.length - 1; j++) {
      node = node[keys[j]] || (node[keys[j]] = {});
    }
    node[keys[j]] = this.v ? this.v.call(o, value) : value;
  }
  return map;
};
/**
 * Returns a {@link pv.Nest} operator for the specified array. This is a
 * convenience factory method, equivalent to <tt>new pv.Nest(array)</tt>.
 *
 * @see pv.Nest
 * @param {array} array an array of elements to nest.
 * @returns {pv.Nest} a nest operator for the specified array.
 */
pv.nest = function(array) {
  return new pv.Nest(array);
};

/**
 * Constructs a nest operator for the specified array. This constructor should
 * not be invoked directly; use {@link pv.nest} instead.
 *
 * @class Represents a {@link Nest} operator for the specified array. Nesting
 * allows elements in an array to be grouped into a hierarchical tree
 * structure. The levels in the tree are specified by <i>key</i> functions. The
 * leaf nodes of the tree can be sorted by value, while the internal nodes can
 * be sorted by key. Finally, the tree can be returned either has a
 * multidimensional array via {@link #entries}, or as a hierarchical map via
 * {@link #map}. The {@link #rollup} routine similarly returns a map, collapsing
 * the elements in each leaf node using a summary function.
 *
 * <p>For example, consider the following tabular data structure of Barley
 * yields, from various sites in Minnesota during 1931-2:
 *
 * <pre>{ yield: 27.00, variety: "Manchuria", year: 1931, site: "University Farm" },
 * { yield: 48.87, variety: "Manchuria", year: 1931, site: "Waseca" },
 * { yield: 27.43, variety: "Manchuria", year: 1931, site: "Morris" }, ...</pre>
 *
 * To facilitate visualization, it may be useful to nest the elements first by
 * year, and then by variety, as follows:
 *
 * <pre>var nest = pv.nest(yields)
 *     .key(function(d) d.year)
 *     .key(function(d) d.variety)
 *     .entries();</pre>
 *
 * This returns a nested array. Each element of the outer array is a key-values
 * pair, listing the values for each distinct key:
 *
 * <pre>{ key: 1931, values: [
 *   { key: "Manchuria", values: [
 *       { yield: 27.00, variety: "Manchuria", year: 1931, site: "University Farm" },
 *       { yield: 48.87, variety: "Manchuria", year: 1931, site: "Waseca" },
 *       { yield: 27.43, variety: "Manchuria", year: 1931, site: "Morris" },
 *       ...
 *     ] },
 *   { key: "Glabron", values: [
 *       { yield: 43.07, variety: "Glabron", year: 1931, site: "University Farm" },
 *       { yield: 55.20, variety: "Glabron", year: 1931, site: "Waseca" },
 *       ...
 *     ] },
 *   ] },
 * { key: 1932, values: ... }</pre>
 *
 * Further details, including sorting and rollup, is provided below on the
 * corresponding methods.
 *
 * @param {array} array an array of elements to nest.
 */
pv.Nest = function(array) {
  this.array = array;
  this.keys = [];
};

/**
 * Nests using the specified key function. Multiple keys may be added to the
 * nest; the array elements will be nested in the order keys are specified.
 *
 * @param {function} key a key function; must return a string or suitable map
 * key.
 * @returns {pv.Nest} this.
 */
pv.Nest.prototype.key = function(key) {
  this.keys.push(key);
  return this;
};

/**
 * Sorts the previously-added keys. The natural sort order is used by default
 * (see {@link pv.naturalOrder}); if an alternative order is desired,
 * <tt>order</tt> should be a comparator function. If this method is not called
 * (i.e., keys are <i>unsorted</i>), keys will appear in the order they appear
 * in the underlying elements array. For example,
 *
 * <pre>pv.nest(yields)
 *     .key(function(d) d.year)
 *     .key(function(d) d.variety)
 *     .sortKeys()
 *     .entries()</pre>
 *
 * groups yield data by year, then variety, and sorts the variety groups
 * lexicographically (since the variety attribute is a string).
 *
 * <p>Key sort order is only used in conjunction with {@link #entries}, which
 * returns an array of key-values pairs. If the nest is used to construct a
 * {@link #map} instead, keys are unsorted.
 *
 * @param {function} [order] an optional comparator function.
 * @returns {pv.Nest} this.
 */
pv.Nest.prototype.sortKeys = function(order) {
  this.keys[this.keys.length - 1].order = order || pv.naturalOrder;
  return this;
};

/**
 * Sorts the leaf values. The natural sort order is used by default (see
 * {@link pv.naturalOrder}); if an alternative order is desired, <tt>order</tt>
 * should be a comparator function. If this method is not called (i.e., values
 * are <i>unsorted</i>), values will appear in the order they appear in the
 * underlying elements array. For example,
 *
 * <pre>pv.nest(yields)
 *     .key(function(d) d.year)
 *     .key(function(d) d.variety)
 *     .sortValues(function(a, b) a.yield - b.yield)
 *     .entries()</pre>
 *
 * groups yield data by year, then variety, and sorts the values for each
 * variety group by yield.
 *
 * <p>Value sort order, unlike keys, applies to both {@link #entries} and
 * {@link #map}. It has no effect on {@link #rollup}.
 *
 * @param {function} [order] an optional comparator function.
 * @returns {pv.Nest} this.
 */
pv.Nest.prototype.sortValues = function(order) {
  this.order = order || pv.naturalOrder;
  return this;
};

/**
 * Returns a hierarchical map of values. Each key adds one level to the
 * hierarchy. With only a single key, the returned map will have a key for each
 * distinct value of the key function; the correspond value with be an array of
 * elements with that key value. If a second key is added, this will be a nested
 * map. For example:
 *
 * <pre>pv.nest(yields)
 *     .key(function(d) d.variety)
 *     .key(function(d) d.site)
 *     .map()</pre>
 *
 * returns a map <tt>m</tt> such that <tt>m[variety][site]</tt> is an array, a subset of
 * <tt>yields</tt>, with each element having the given variety and site.
 *
 * @returns a hierarchical map of values.
 */
pv.Nest.prototype.map = function() {
  var map = {}, values = [];

  /* Build the map. */
  for (var i, j = 0; j < this.array.length; j++) {
    var x = this.array[j];
    var m = map;
    for (i = 0; i < this.keys.length - 1; i++) {
      var k = this.keys[i](x);
      if (!m[k]) m[k] = {};
      m = m[k];
    }
    k = this.keys[i](x);
    if (!m[k]) {
      var a = [];
      values.push(a);
      m[k] = a;
    }
    m[k].push(x);
  }

  /* Sort each leaf array. */
  if (this.order) {
    for (var i = 0; i < values.length; i++) {
      values[i].sort(this.order);
    }
  }

  return map;
};

/**
 * Returns a hierarchical nested array. This method is similar to
 * {@link pv.entries}, but works recursively on the entire hierarchy. Rather
 * than returning a map like {@link #map}, this method returns a nested
 * array. Each element of the array has a <tt>key</tt> and <tt>values</tt>
 * field. For leaf nodes, the <tt>values</tt> array will be a subset of the
 * underlying elements array; for non-leaf nodes, the <tt>values</tt> array will
 * contain more key-values pairs.
 *
 * <p>For an example usage, see the {@link Nest} constructor.
 *
 * @returns a hierarchical nested array.
 */
pv.Nest.prototype.entries = function() {

  /** Recursively extracts the entries for the given map. */
  function entries(map) {
    var array = [];
    for (var k in map) {
      var v = map[k];
      array.push({ key: k, values: (v instanceof Array) ? v : entries(v) });
    };
    return array;
  }

  /** Recursively sorts the values for the given key-values array. */
  function sort(array, i) {
    var o = this.keys[i].order;
    if (o) array.sort(function(a, b) { return o(a.key, b.key); });
    if (++i < this.keys.length) {
      for (var j = 0; j < array.length; j++) {
        sort.call(this, array[j].values, i);
      }
    }
    return array;
  }

  return sort.call(this, entries(this.map()), 0);
};

/**
 * Returns a rollup map. The behavior of this method is the same as
 * {@link #map}, except that the leaf values are replaced with the return value
 * of the specified rollup function <tt>f</tt>. For example,
 *
 * <pre>pv.nest(yields)
 *      .key(function(d) d.site)
 *      .rollup(function(v) pv.median(v, function(d) d.yield))</pre>
 *
 * first groups yield data by site, and then returns a map from site to median
 * yield for the given site.
 *
 * @see #map
 * @param {function} f a rollup function.
 * @returns a hierarchical map, with the leaf values computed by <tt>f</tt>.
 */
pv.Nest.prototype.rollup = function(f) {

  /** Recursively descends to the leaf nodes (arrays) and does rollup. */
  function rollup(map) {
    for (var key in map) {
      var value = map[key];
      if (value instanceof Array) {
        map[key] = f(value);
      } else {
        rollup(value);
      }
    }
    return map;
  }

  return rollup(this.map());
};
/**
 * Returns a {@link pv.Flatten} operator for the specified map. This is a
 * convenience factory method, equivalent to <tt>new pv.Flatten(map)</tt>.
 *
 * @see pv.Flatten
 * @param map a map to flatten.
 * @returns {pv.Flatten} a flatten operator for the specified map.
 */
pv.flatten = function(map) {
  return new pv.Flatten(map);
};

/**
 * Constructs a flatten operator for the specified map. This constructor should
 * not be invoked directly; use {@link pv.flatten} instead.
 *
 * @class Represents a flatten operator for the specified array. Flattening
 * allows hierarchical maps to be flattened into an array. The levels in the
 * input tree are specified by <i>key</i> functions.
 *
 * <p>For example, consider the following hierarchical data structure of Barley
 * yields, from various sites in Minnesota during 1931-2:
 *
 * <pre>{ 1931: {
 *     Manchuria: {
 *       "University Farm": 27.00,
 *       "Waseca": 48.87,
 *       "Morris": 27.43,
 *       ... },
 *     Glabron: {
 *       "University Farm": 43.07,
 *       "Waseca": 55.20,
 *       ... } },
 *   1932: {
 *     ... } }</pre>
 *
 * To facilitate visualization, it may be useful to flatten the tree into a
 * tabular array:
 *
 * <pre>var array = pv.flatten(yields)
 *     .key("year")
 *     .key("variety")
 *     .key("site")
 *     .key("yield")
 *     .array();</pre>
 *
 * This returns an array of object elements. Each element in the array has
 * attributes corresponding to this flatten operator's keys:
 *
 * <pre>{ site: "University Farm", variety: "Manchuria", year: 1931, yield: 27 },
 * { site: "Waseca", variety: "Manchuria", year: 1931, yield: 48.87 },
 * { site: "Morris", variety: "Manchuria", year: 1931, yield: 27.43 },
 * { site: "University Farm", variety: "Glabron", year: 1931, yield: 43.07 },
 * { site: "Waseca", variety: "Glabron", year: 1931, yield: 55.2 }, ...</pre>
 *
 * <p>The flatten operator is roughly the inverse of the {@link pv.Nest} and
 * {@link pv.Tree} operators.
 *
 * @param map a map to flatten.
 */
pv.Flatten = function(map) {
  this.map = map;
  this.keys = [];
};

/**
 * Flattens using the specified key function. Multiple keys may be added to the
 * flatten; the tiers of the underlying tree must correspond to the specified
 * keys, in order. The order of the returned array is undefined; however, you
 * can easily sort it.
 *
 * @param {string} key the key name.
 * @param {function} [f] an optional value map function.
 * @returns {pv.Nest} this.
 */
pv.Flatten.prototype.key = function(key, f) {
  this.keys.push({name: key, value: f});
  delete this.$leaf;
  return this;
};

/**
 * Flattens using the specified leaf function. This is an alternative to
 * specifying an explicit set of keys; the tiers of the underlying tree will be
 * determined dynamically by recursing on the values, and the resulting keys
 * will be stored in the entries <tt>keys</tt> attribute. The leaf function must
 * return true for leaves, and false for internal nodes.
 *
 * @param {function} f a leaf function.
 * @returns {pv.Nest} this.
 */
pv.Flatten.prototype.leaf = function(f) {
  this.keys.length = 0;
  this.$leaf = f;
  return this;
};

/**
 * Returns the flattened array. Each entry in the array is an object; each
 * object has attributes corresponding to this flatten operator's keys.
 *
 * @returns an array of elements from the flattened map.
 */
pv.Flatten.prototype.array = function() {
  var entries = [], stack = [], keys = this.keys, leaf = this.$leaf;

  /* Recursively visit using the leaf function. */
  if (leaf) {
    function recurse(value, i) {
      if (leaf(value)) {
        entries.push({keys: stack.slice(), value: value});
      } else {
        for (var key in value) {
          stack.push(key);
          recurse(value[key], i + 1);
          stack.pop();
        }
      }
    }
    recurse(this.map, 0);
    return entries;
  }

  /* Recursively visits the specified value. */
  function visit(value, i) {
    if (i < keys.length - 1) {
      for (var key in value) {
        stack.push(key);
        visit(value[key], i + 1);
        stack.pop();
      }
    } else {
      entries.push(stack.concat(value));
    }
  }

  visit(this.map, 0);
  return entries.map(function(stack) {
      var m = {};
      for (var i = 0; i < keys.length; i++) {
        var k = keys[i], v = stack[i];
        m[k.name] = k.value ? k.value.call(null, v) : v;
      }
      return m;
    });
};
/**
 * Returns a {@link pv.Vector} for the specified <i>x</i> and <i>y</i>
 * coordinate. This is a convenience factory method, equivalent to <tt>new
 * pv.Vector(x, y)</tt>.
 *
 * @see pv.Vector
 * @param {number} x the <i>x</i> coordinate.
 * @param {number} y the <i>y</i> coordinate.
 * @returns {pv.Vector} a vector for the specified coordinates.
 */
pv.vector = function(x, y) {
  return new pv.Vector(x, y);
};

/**
 * Constructs a {@link pv.Vector} for the specified <i>x</i> and <i>y</i>
 * coordinate. This constructor should not be invoked directly; use
 * {@link pv.vector} instead.
 *
 * @class Represents a two-dimensional vector; a 2-tuple <i>&#x27e8;x,
 * y&#x27e9;</i>. The intent of this class is to simplify vector math. Note that
 * in performance-sensitive cases it may be more efficient to represent 2D
 * vectors as simple objects with <tt>x</tt> and <tt>y</tt> attributes, rather
 * than using instances of this class.
 *
 * @param {number} x the <i>x</i> coordinate.
 * @param {number} y the <i>y</i> coordinate.
 */
pv.Vector = function(x, y) {
  this.x = x;
  this.y = y;
};

/**
 * Returns a vector perpendicular to this vector: <i>&#x27e8;-y, x&#x27e9;</i>.
 *
 * @returns {pv.Vector} a perpendicular vector.
 */
pv.Vector.prototype.perp = function() {
  return new pv.Vector(-this.y, this.x);
};

/**
 * Returns a normalized copy of this vector: a vector with the same direction,
 * but unit length. If this vector has zero length this method returns a copy of
 * this vector.
 *
 * @returns {pv.Vector} a unit vector.
 */
pv.Vector.prototype.norm = function() {
  var l = this.length();
  return this.times(l ? (1 / l) : 1);
};

/**
 * Returns the magnitude of this vector, defined as <i>sqrt(x * x + y * y)</i>.
 *
 * @returns {number} a length.
 */
pv.Vector.prototype.length = function() {
  return Math.sqrt(this.x * this.x + this.y * this.y);
};

/**
 * Returns a scaled copy of this vector: <i>&#x27e8;x * k, y * k&#x27e9;</i>.
 * To perform the equivalent divide operation, use <i>1 / k</i>.
 *
 * @param {number} k the scale factor.
 * @returns {pv.Vector} a scaled vector.
 */
pv.Vector.prototype.times = function(k) {
  return new pv.Vector(this.x * k, this.y * k);
};

/**
 * Returns this vector plus the vector <i>v</i>: <i>&#x27e8;x + v.x, y +
 * v.y&#x27e9;</i>. If only one argument is specified, it is interpreted as the
 * vector <i>v</i>.
 *
 * @param {number} x the <i>x</i> coordinate to add.
 * @param {number} y the <i>y</i> coordinate to add.
 * @returns {pv.Vector} a new vector.
 */
pv.Vector.prototype.plus = function(x, y) {
  return (arguments.length == 1)
      ? new pv.Vector(this.x + x.x, this.y + x.y)
      : new pv.Vector(this.x + x, this.y + y);
};

/**
 * Returns this vector minus the vector <i>v</i>: <i>&#x27e8;x - v.x, y -
 * v.y&#x27e9;</i>. If only one argument is specified, it is interpreted as the
 * vector <i>v</i>.
 *
 * @param {number} x the <i>x</i> coordinate to subtract.
 * @param {number} y the <i>y</i> coordinate to subtract.
 * @returns {pv.Vector} a new vector.
 */
pv.Vector.prototype.minus = function(x, y) {
  return (arguments.length == 1)
      ? new pv.Vector(this.x - x.x, this.y - x.y)
      : new pv.Vector(this.x - x, this.y - y);
};

/**
 * Returns the dot product of this vector and the vector <i>v</i>: <i>x * v.x +
 * y * v.y</i>. If only one argument is specified, it is interpreted as the
 * vector <i>v</i>.
 *
 * @param {number} x the <i>x</i> coordinate to dot.
 * @param {number} y the <i>y</i> coordinate to dot.
 * @returns {number} a dot product.
 */
pv.Vector.prototype.dot = function(x, y) {
  return (arguments.length == 1)
      ? this.x * x.x + this.y * x.y
      : this.x * x + this.y * y;
};
/**
 * Returns a new identity transform.
 *
 * @class Represents a transformation matrix. The transformation matrix is
 * limited to expressing translate and uniform scale transforms only; shearing,
 * rotation, general affine, and other transforms are not supported.
 *
 * <p>The methods on this class treat the transform as immutable, returning a
 * copy of the transformation matrix with the specified transform applied. Note,
 * alternatively, that the matrix fields can be get and set directly.
 */
pv.Transform = function() {};
pv.Transform.prototype = {k: 1, x: 0, y: 0};

/**
 * The scale magnitude; defaults to 1.
 *
 * @type number
 * @name pv.Transform.prototype.k
 */

/**
 * The x-offset; defaults to 0.
 *
 * @type number
 * @name pv.Transform.prototype.x
 */

/**
 * The y-offset; defaults to 0.
 *
 * @type number
 * @name pv.Transform.prototype.y
 */

/**
 * @private The identity transform.
 *
 * @type pv.Transform
 */
pv.Transform.identity = new pv.Transform();

// k 0 x   1 0 a   k 0 ka+x
// 0 k y * 0 1 b = 0 k kb+y
// 0 0 1   0 0 1   0 0 1

/**
 * Returns a translated copy of this transformation matrix.
 *
 * @param {number} x the x-offset.
 * @param {number} y the y-offset.
 * @returns {pv.Transform} the translated transformation matrix.
 */
pv.Transform.prototype.translate = function(x, y) {
  var v = new pv.Transform();
  v.k = this.k;
  v.x = this.k * x + this.x;
  v.y = this.k * y + this.y;
  return v;
};

// k 0 x   d 0 0   kd  0 x
// 0 k y * 0 d 0 =  0 kd y
// 0 0 1   0 0 1    0  0 1

/**
 * Returns a scaled copy of this transformation matrix.
 *
 * @param {number} k
 * @returns {pv.Transform} the scaled transformation matrix.
 */
pv.Transform.prototype.scale = function(k) {
  var v = new pv.Transform();
  v.k = this.k * k;
  v.x = this.x;
  v.y = this.y;
  return v;
};

/**
 * Returns the inverse of this transformation matrix.
 *
 * @returns {pv.Transform} the inverted transformation matrix.
 */
pv.Transform.prototype.invert = function() {
  var v = new pv.Transform(), k = 1 / this.k;
  v.k = k;
  v.x = -this.x * k;
  v.y = -this.y * k;
  return v;
};

// k 0 x   d 0 a   kd  0 ka+x
// 0 k y * 0 d b =  0 kd kb+y
// 0 0 1   0 0 1    0  0    1

/**
 * Returns this matrix post-multiplied by the specified matrix <i>m</i>.
 *
 * @param {pv.Transform} m
 * @returns {pv.Transform} the post-multiplied transformation matrix.
 */
pv.Transform.prototype.times = function(m) {
  var v = new pv.Transform();
  v.k = this.k * m.k;
  v.x = this.k * m.x + this.x;
  v.y = this.k * m.y + this.y;
  return v;
};
/**
 * Abstract; see the various scale implementations.
 *
 * @class Represents a scale; a function that performs a transformation from
 * data domain to visual range. For quantitative and quantile scales, the domain
 * is expressed as numbers; for ordinal scales, the domain is expressed as
 * strings (or equivalently objects with unique string representations). The
 * "visual range" may correspond to pixel space, colors, font sizes, and the
 * like.
 *
 * <p>Note that scales are functions, and thus can be used as properties
 * directly, assuming that the data associated with a mark is a number. While
 * this is convenient for single-use scales, frequently it is desirable to
 * define scales globally:
 *
 * <pre>var y = pv.Scale.linear(0, 100).range(0, 640);</pre>
 *
 * The <tt>y</tt> scale can now be equivalently referenced within a property:
 *
 * <pre>    .height(function(d) y(d))</pre>
 *
 * Alternatively, if the data are not simple numbers, the appropriate value can
 * be passed to the <tt>y</tt> scale (e.g., <tt>d.foo</tt>). The {@link #by}
 * method similarly allows the data to be mapped to a numeric value before
 * performing the linear transformation.
 *
 * @see pv.Scale.quantitative
 * @see pv.Scale.quantile
 * @see pv.Scale.ordinal
 * @extends function
 */
pv.Scale = function() {};

/**
 * @private Returns a function that interpolators from the start value to the
 * end value, given a parameter <i>t</i> in [0, 1].
 *
 * @param start the start value.
 * @param end the end value.
 */
pv.Scale.interpolator = function(start, end) {
  if (typeof start == "number") {
    return function(t) {
      return t * (end - start) + start;
    };
  }

  /* For now, assume color. */
  start = pv.color(start).rgb();
  end = pv.color(end).rgb();
  return function(t) {
    var a = start.a * (1 - t) + end.a * t;
    if (a < 1e-5) a = 0; // avoid scientific notation
    return (start.a == 0) ? pv.rgb(end.r, end.g, end.b, a)
        : ((end.a == 0) ? pv.rgb(start.r, start.g, start.b, a)
        : pv.rgb(
            Math.round(start.r * (1 - t) + end.r * t),
            Math.round(start.g * (1 - t) + end.g * t),
            Math.round(start.b * (1 - t) + end.b * t), a));
  };
};

/**
 * Returns a view of this scale by the specified accessor function <tt>f</tt>.
 * Given a scale <tt>y</tt>, <tt>y.by(function(d) d.foo)</tt> is equivalent to
 * <tt>function(d) y(d.foo)</tt>.
 *
 * <p>This method is provided for convenience, such that scales can be
 * succinctly defined inline. For example, given an array of data elements that
 * have a <tt>score</tt> attribute with the domain [0, 1], the height property
 * could be specified as:
 *
 * <pre>    .height(pv.Scale.linear().range(0, 480).by(function(d) d.score))</pre>
 *
 * This is equivalent to:
 *
 * <pre>    .height(function(d) d.score * 480)</pre>
 *
 * This method should be used judiciously; it is typically more clear to invoke
 * the scale directly, passing in the value to be scaled.
 *
 * @function
 * @name pv.Scale.prototype.by
 * @param {function} f an accessor function.
 * @returns {pv.Scale} a view of this scale by the specified accessor function.
 */
/**
 * Returns a default quantitative, linear, scale for the specified domain. The
 * arguments to this constructor are optional, and equivalent to calling
 * {@link #domain}. The default domain and range are [0,1].
 *
 * <p>This constructor is typically not used directly; see one of the
 * quantitative scale implementations instead.
 *
 * @class Represents an abstract quantitative scale; a function that performs a
 * numeric transformation. This class is typically not used directly; see one of
 * the quantitative scale implementations (linear, log, root, etc.)
 * instead. <style type="text/css">sub{line-height:0}</style> A quantitative
 * scale represents a 1-dimensional transformation from a numeric domain of
 * input data [<i>d<sub>0</sub></i>, <i>d<sub>1</sub></i>] to a numeric range of
 * pixels [<i>r<sub>0</sub></i>, <i>r<sub>1</sub></i>]. In addition to
 * readability, scales offer several useful features:
 *
 * <p>1. The range can be expressed in colors, rather than pixels. For example:
 *
 * <pre>    .fillStyle(pv.Scale.linear(0, 100).range("red", "green"))</pre>
 *
 * will fill the marks "red" on an input value of 0, "green" on an input value
 * of 100, and some color in-between for intermediate values.
 *
 * <p>2. The domain and range can be subdivided for a non-uniform
 * transformation. For example, you may want a diverging color scale that is
 * increasingly red for negative values, and increasingly green for positive
 * values:
 *
 * <pre>    .fillStyle(pv.Scale.linear(-1, 0, 1).range("red", "white", "green"))</pre>
 *
 * The domain can be specified as a series of <i>n</i> monotonically-increasing
 * values; the range must also be specified as <i>n</i> values, resulting in
 * <i>n - 1</i> contiguous linear scales.
 *
 * <p>3. Quantitative scales can be inverted for interaction. The
 * {@link #invert} method takes a value in the output range, and returns the
 * corresponding value in the input domain. This is frequently used to convert
 * the mouse location (see {@link pv.Mark#mouse}) to a value in the input
 * domain. Note that inversion is only supported for numeric ranges, and not
 * colors.
 *
 * <p>4. A scale can be queried for reasonable "tick" values. The {@link #ticks}
 * method provides a convenient way to get a series of evenly-spaced rounded
 * values in the input domain. Frequently these are used in conjunction with
 * {@link pv.Rule} to display tick marks or grid lines.
 *
 * <p>5. A scale can be "niced" to extend the domain to suitable rounded
 * numbers. If the minimum and maximum of the domain are messy because they are
 * derived from data, you can use {@link #nice} to round these values down and
 * up to even numbers.
 *
 * @param {number...} domain... optional domain values.
 * @see pv.Scale.linear
 * @see pv.Scale.log
 * @see pv.Scale.root
 * @extends pv.Scale
 */
pv.Scale.quantitative = function() {
  var d = [0, 1], // default domain
      l = [0, 1], // default transformed domain
      r = [0, 1], // default range
      i = [pv.identity], // default interpolators
      type = Number, // default type
      n = false, // whether the domain is negative
      f = pv.identity, // default forward transform
      g = pv.identity, // default inverse transform
      tickFormat = String; // default tick formatting function

  /** @private */
  function newDate(x) {
    return new Date(x);
  }

  /** @private */
  function scale(x) {
    var j = pv.search(d, x);
    if (j < 0) j = -j - 2;
    j = Math.max(0, Math.min(i.length - 1, j));
    return i[j]((f(x) - l[j]) / (l[j + 1] - l[j]));
  }

  /** @private */
  scale.transform = function(forward, inverse) {
    /** @ignore */ f = function(x) { return n ? -forward(-x) : forward(x); };
    /** @ignore */ g = function(y) { return n ? -inverse(-y) : inverse(y); };
    l = d.map(f);
    return this;
  };

  /**
   * Sets or gets the input domain. This method can be invoked several ways:
   *
   * <p>1. <tt>domain(min, ..., max)</tt>
   *
   * <p>Specifying the domain as a series of numbers is the most explicit and
   * recommended approach. Most commonly, two numbers are specified: the minimum
   * and maximum value. However, for a diverging scale, or other subdivided
   * non-uniform scales, multiple values can be specified. Values can be derived
   * from data using {@link pv.min} and {@link pv.max}. For example:
   *
   * <pre>    .domain(0, pv.max(array))</pre>
   *
   * An alternative method for deriving minimum and maximum values from data
   * follows.
   *
   * <p>2. <tt>domain(array, minf, maxf)</tt>
   *
   * <p>When both the minimum and maximum value are derived from data, the
   * arguments to the <tt>domain</tt> method can be specified as the array of
   * data, followed by zero, one or two accessor functions. For example, if the
   * array of data is just an array of numbers:
   *
   * <pre>    .domain(array)</pre>
   *
   * On the other hand, if the array elements are objects representing stock
   * values per day, and the domain should consider the stock's daily low and
   * daily high:
   *
   * <pre>    .domain(array, function(d) d.low, function(d) d.high)</pre>
   *
   * The first method of setting the domain is preferred because it is more
   * explicit; setting the domain using this second method should be used only
   * if brevity is required.
   *
   * <p>3. <tt>domain()</tt>
   *
   * <p>Invoking the <tt>domain</tt> method with no arguments returns the
   * current domain as an array of numbers.
   *
   * @function
   * @name pv.Scale.quantitative.prototype.domain
   * @param {number...} domain... domain values.
   * @returns {pv.Scale.quantitative} <tt>this</tt>, or the current domain.
   */
  scale.domain = function(array, min, max) {
    if (arguments.length) {
      var o; // the object we use to infer the domain type
      if (array instanceof Array) {
        if (arguments.length < 2) min = pv.identity;
        if (arguments.length < 3) max = min;
        o = array.length && min(array[0]);
        d = array.length ? [pv.min(array, min), pv.max(array, max)] : [];
      } else {
        o = array;
        d = Array.prototype.slice.call(arguments).map(Number);
      }
      if (!d.length) d = [-Infinity, Infinity];
      else if (d.length == 1) d = [d[0], d[0]];
      n = (d[0] || d[d.length - 1]) < 0;
      l = d.map(f);
      type = (o instanceof Date) ? newDate : Number;
      return this;
    }
    return d.map(type);
  };

  /**
   * Sets or gets the output range. This method can be invoked several ways:
   *
   * <p>1. <tt>range(min, ..., max)</tt>
   *
   * <p>The range may be specified as a series of numbers or colors. Most
   * commonly, two numbers are specified: the minimum and maximum pixel values.
   * For a color scale, values may be specified as {@link pv.Color}s or
   * equivalent strings. For a diverging scale, or other subdivided non-uniform
   * scales, multiple values can be specified. For example:
   *
   * <pre>    .range("red", "white", "green")</pre>
   *
   * <p>Currently, only numbers and colors are supported as range values. The
   * number of range values must exactly match the number of domain values, or
   * the behavior of the scale is undefined.
   *
   * <p>2. <tt>range()</tt>
   *
   * <p>Invoking the <tt>range</tt> method with no arguments returns the current
   * range as an array of numbers or colors.
   *
   * @function
   * @name pv.Scale.quantitative.prototype.range
   * @param {...} range... range values.
   * @returns {pv.Scale.quantitative} <tt>this</tt>, or the current range.
   */
  scale.range = function() {
    if (arguments.length) {
      r = Array.prototype.slice.call(arguments);
      if (!r.length) r = [-Infinity, Infinity];
      else if (r.length == 1) r = [r[0], r[0]];
      i = [];
      for (var j = 0; j < r.length - 1; j++) {
        i.push(pv.Scale.interpolator(r[j], r[j + 1]));
      }
      return this;
    }
    return r;
  };

  /**
   * Inverts the specified value in the output range, returning the
   * corresponding value in the input domain. This is frequently used to convert
   * the mouse location (see {@link pv.Mark#mouse}) to a value in the input
   * domain. Inversion is only supported for numeric ranges, and not colors.
   *
   * <p>Note that this method does not do any rounding or bounds checking. If
   * the input domain is discrete (e.g., an array index), the returned value
   * should be rounded. If the specified <tt>y</tt> value is outside the range,
   * the returned value may be equivalently outside the input domain.
   *
   * @function
   * @name pv.Scale.quantitative.prototype.invert
   * @param {number} y a value in the output range (a pixel location).
   * @returns {number} a value in the input domain.
   */
  scale.invert = function(y) {
    var j = pv.search(r, y);
    if (j < 0) j = -j - 2;
    j = Math.max(0, Math.min(i.length - 1, j));
    return type(g(l[j] + (y - r[j]) / (r[j + 1] - r[j]) * (l[j + 1] - l[j])));
  };

  /**
   * Returns an array of evenly-spaced, suitably-rounded values in the input
   * domain. This method attempts to return between 5 and 10 tick values. These
   * values are frequently used in conjunction with {@link pv.Rule} to display
   * tick marks or grid lines.
   *
   * @function
   * @name pv.Scale.quantitative.prototype.ticks
   * @param {number} [m] optional number of desired ticks.
   * @returns {number[]} an array input domain values to use as ticks.
   */
  scale.ticks = function(m) {
    var start = d[0],
        end = d[d.length - 1],
        reverse = end < start,
        min = reverse ? end : start,
        max = reverse ? start : end,
        span = max - min;

    /* Special case: empty, invalid or infinite span. */
    if (!span || !isFinite(span)) {
      if (type == newDate) tickFormat = pv.Format.date("%x");
      return [type(min)];
    }

    /* Special case: dates. */
    if (type == newDate) {
      /* Floor the date d given the precision p. */
      function floor(d, p) {
        switch (p) {
          case 31536e6: d.setMonth(0);
          case 2592e6: d.setDate(1);
          case 6048e5: if (p == 6048e5) d.setDate(d.getDate() - d.getDay());
          case 864e5: d.setHours(0);
          case 36e5: d.setMinutes(0);
          case 6e4: d.setSeconds(0);
          case 1e3: d.setMilliseconds(0);
        }
      }

      var precision, format, increment, step = 1;
      if (span >= 3 * 31536e6) {
        precision = 31536e6;
        format = "%Y";
        /** @ignore */ increment = function(d) { d.setFullYear(d.getFullYear() + step); };
      } else if (span >= 3 * 2592e6) {
        precision = 2592e6;
        format = "%m/%Y";
        /** @ignore */ increment = function(d) { d.setMonth(d.getMonth() + step); };
      } else if (span >= 3 * 6048e5) {
        precision = 6048e5;
        format = "%m/%d";
        /** @ignore */ increment = function(d) { d.setDate(d.getDate() + 7 * step); };
      } else if (span >= 3 * 864e5) {
        precision = 864e5;
        format = "%m/%d";
        /** @ignore */ increment = function(d) { d.setDate(d.getDate() + step); };
      } else if (span >= 3 * 36e5) {
        precision = 36e5;
        format = "%I:%M %p";
        /** @ignore */ increment = function(d) { d.setHours(d.getHours() + step); };
      } else if (span >= 3 * 6e4) {
        precision = 6e4;
        format = "%I:%M %p";
        /** @ignore */ increment = function(d) { d.setMinutes(d.getMinutes() + step); };
      } else if (span >= 3 * 1e3) {
        precision = 1e3;
        format = "%I:%M:%S";
        /** @ignore */ increment = function(d) { d.setSeconds(d.getSeconds() + step); };
      } else {
        precision = 1;
        format = "%S.%Qs";
        /** @ignore */ increment = function(d) { d.setTime(d.getTime() + step); };
      }
      tickFormat = pv.Format.date(format);

      var date = new Date(min), dates = [];
      floor(date, precision);

      /* If we'd generate too many ticks, skip some!. */
      var n = span / precision;
      if (n > 10) {
        switch (precision) {
          case 36e5: {
            step = (n > 20) ? 6 : 3;
            date.setHours(Math.floor(date.getHours() / step) * step);
            break;
          }
          case 2592e6: {
            step = 3; // seasons
            date.setMonth(Math.floor(date.getMonth() / step) * step);
            break;
          }
          case 6e4: {
            step = (n > 30) ? 15 : ((n > 15) ? 10 : 5);
            date.setMinutes(Math.floor(date.getMinutes() / step) * step);
            break;
          }
          case 1e3: {
            step = (n > 90) ? 15 : ((n > 60) ? 10 : 5);
            date.setSeconds(Math.floor(date.getSeconds() / step) * step);
            break;
          }
          case 1: {
            step = (n > 1000) ? 250 : ((n > 200) ? 100 : ((n > 100) ? 50 : ((n > 50) ? 25 : 5)));
            date.setMilliseconds(Math.floor(date.getMilliseconds() / step) * step);
            break;
          }
          default: {
            step = pv.logCeil(n / 15, 10);
            if (n / step < 2) step /= 5;
            else if (n / step < 5) step /= 2;
            date.setFullYear(Math.floor(date.getFullYear() / step) * step);
            break;
          }
        }
      }

      while (true) {
        increment(date);
        if (date > max) break;
        dates.push(new Date(date));
      }
      return reverse ? dates.reverse() : dates;
    }

    /* Normal case: numbers. */
    if (!arguments.length) m = 10;
    var step = pv.logFloor(span / m, 10),
        err = m / (span / step);
    if (err <= .15) step *= 10;
    else if (err <= .35) step *= 5;
    else if (err <= .75) step *= 2;
    var start = Math.ceil(min / step) * step,
        end = Math.floor(max / step) * step;
    tickFormat = pv.Format.number()
        .fractionDigits(Math.max(0, -Math.floor(pv.log(step, 10) + .01)));
    var ticks = pv.range(start, end + step, step);
    return reverse ? ticks.reverse() : ticks;
  };

  /**
   * Formats the specified tick value using the appropriate precision, based on
   * the step interval between tick marks. If {@link #ticks} has not been called,
   * the argument is converted to a string, but no formatting is applied.
   *
   * @function
   * @name pv.Scale.quantitative.prototype.tickFormat
   * @param {number} t a tick value.
   * @returns {string} a formatted tick value.
   */
  scale.tickFormat = function (t) { return tickFormat(t); };

  /**
   * "Nices" this scale, extending the bounds of the input domain to
   * evenly-rounded values. Nicing is useful if the domain is computed
   * dynamically from data, and may be irregular. For example, given a domain of
   * [0.20147987687960267, 0.996679553296417], a call to <tt>nice()</tt> might
   * extend the domain to [0.2, 1].
   *
   * <p>This method must be invoked each time after setting the domain.
   *
   * @function
   * @name pv.Scale.quantitative.prototype.nice
   * @returns {pv.Scale.quantitative} <tt>this</tt>.
   */
  scale.nice = function() {
    if (d.length != 2) return this; // TODO support non-uniform domains
    var start = d[0],
        end = d[d.length - 1],
        reverse = end < start,
        min = reverse ? end : start,
        max = reverse ? start : end,
        span = max - min;

    /* Special case: empty, invalid or infinite span. */
    if (!span || !isFinite(span)) return this;

    var step = Math.pow(10, Math.round(Math.log(span) / Math.log(10)) - 1);
    d = [Math.floor(min / step) * step, Math.ceil(max / step) * step];
    if (reverse) d.reverse();
    l = d.map(f);
    return this;
  };

  /**
   * Returns a view of this scale by the specified accessor function <tt>f</tt>.
   * Given a scale <tt>y</tt>, <tt>y.by(function(d) d.foo)</tt> is equivalent to
   * <tt>function(d) y(d.foo)</tt>.
   *
   * <p>This method is provided for convenience, such that scales can be
   * succinctly defined inline. For example, given an array of data elements
   * that have a <tt>score</tt> attribute with the domain [0, 1], the height
   * property could be specified as:
   *
   * <pre>    .height(pv.Scale.linear().range(0, 480).by(function(d) d.score))</pre>
   *
   * This is equivalent to:
   *
   * <pre>    .height(function(d) d.score * 480)</pre>
   *
   * This method should be used judiciously; it is typically more clear to
   * invoke the scale directly, passing in the value to be scaled.
   *
   * @function
   * @name pv.Scale.quantitative.prototype.by
   * @param {function} f an accessor function.
   * @returns {pv.Scale.quantitative} a view of this scale by the specified
   * accessor function.
   */
  scale.by = function(f) {
    function by() { return scale(f.apply(this, arguments)); }
    for (var method in scale) by[method] = scale[method];
    return by;
  };

  scale.domain.apply(scale, arguments);
  return scale;
};
/**
 * Returns a linear scale for the specified domain. The arguments to this
 * constructor are optional, and equivalent to calling {@link #domain}.
 * The default domain and range are [0,1].
 *
 * @class Represents a linear scale; a function that performs a linear
 * transformation. <style type="text/css">sub{line-height:0}</style> Most
 * commonly, a linear scale represents a 1-dimensional linear transformation
 * from a numeric domain of input data [<i>d<sub>0</sub></i>,
 * <i>d<sub>1</sub></i>] to a numeric range of pixels [<i>r<sub>0</sub></i>,
 * <i>r<sub>1</sub></i>]. The equation for such a scale is:
 *
 * <blockquote><i>f(x) = (x - d<sub>0</sub>) / (d<sub>1</sub> - d<sub>0</sub>) *
 * (r<sub>1</sub> - r<sub>0</sub>) + r<sub>0</sub></i></blockquote>
 *
 * For example, a linear scale from the domain [0, 100] to range [0, 640]:
 *
 * <blockquote><i>f(x) = (x - 0) / (100 - 0) * (640 - 0) + 0</i><br>
 * <i>f(x) = x / 100 * 640</i><br>
 * <i>f(x) = x * 6.4</i><br>
 * </blockquote>
 *
 * Thus, saying
 *
 * <pre>    .height(function(d) d * 6.4)</pre>
 *
 * is identical to
 *
 * <pre>    .height(pv.Scale.linear(0, 100).range(0, 640))</pre>
 *
 * Note that the scale is itself a function, and thus can be used as a property
 * directly, assuming that the data associated with a mark is a number. While
 * this is convenient for single-use scales, frequently it is desirable to
 * define scales globally:
 *
 * <pre>var y = pv.Scale.linear(0, 100).range(0, 640);</pre>
 *
 * The <tt>y</tt> scale can now be equivalently referenced within a property:
 *
 * <pre>    .height(function(d) y(d))</pre>
 *
 * Alternatively, if the data are not simple numbers, the appropriate value can
 * be passed to the <tt>y</tt> scale (e.g., <tt>d.foo</tt>). The {@link #by}
 * method similarly allows the data to be mapped to a numeric value before
 * performing the linear transformation.
 *
 * @param {number...} domain... optional domain values.
 * @extends pv.Scale.quantitative
 */
pv.Scale.linear = function() {
  var scale = pv.Scale.quantitative();
  scale.domain.apply(scale, arguments);
  return scale;
};
/**
 * Returns a log scale for the specified domain. The arguments to this
 * constructor are optional, and equivalent to calling {@link #domain}.
 * The default domain is [1,10] and the default range is [0,1].
 *
 * @class Represents a log scale. <style
 * type="text/css">sub{line-height:0}</style> Most commonly, a log scale
 * represents a 1-dimensional log transformation from a numeric domain of input
 * data [<i>d<sub>0</sub></i>, <i>d<sub>1</sub></i>] to a numeric range of
 * pixels [<i>r<sub>0</sub></i>, <i>r<sub>1</sub></i>]. The equation for such a
 * scale is:
 *
 * <blockquote><i>f(x) = (log(x) - log(d<sub>0</sub>)) / (log(d<sub>1</sub>) -
 * log(d<sub>0</sub>)) * (r<sub>1</sub> - r<sub>0</sub>) +
 * r<sub>0</sub></i></blockquote>
 *
 * where <i>log(x)</i> represents the zero-symmetric logarthim of <i>x</i> using
 * the scale's associated base (default: 10, see {@link pv.logSymmetric}). For
 * example, a log scale from the domain [1, 100] to range [0, 640]:
 *
 * <blockquote><i>f(x) = (log(x) - log(1)) / (log(100) - log(1)) * (640 - 0) + 0</i><br>
 * <i>f(x) = log(x) / 2 * 640</i><br>
 * <i>f(x) = log(x) * 320</i><br>
 * </blockquote>
 *
 * Thus, saying
 *
 * <pre>    .height(function(d) Math.log(d) * 138.974)</pre>
 *
 * is equivalent to
 *
 * <pre>    .height(pv.Scale.log(1, 100).range(0, 640))</pre>
 *
 * Note that the scale is itself a function, and thus can be used as a property
 * directly, assuming that the data associated with a mark is a number. While
 * this is convenient for single-use scales, frequently it is desirable to
 * define scales globally:
 *
 * <pre>var y = pv.Scale.log(1, 100).range(0, 640);</pre>
 *
 * The <tt>y</tt> scale can now be equivalently referenced within a property:
 *
 * <pre>    .height(function(d) y(d))</pre>
 *
 * Alternatively, if the data are not simple numbers, the appropriate value can
 * be passed to the <tt>y</tt> scale (e.g., <tt>d.foo</tt>). The {@link #by}
 * method similarly allows the data to be mapped to a numeric value before
 * performing the log transformation.
 *
 * @param {number...} domain... optional domain values.
 * @extends pv.Scale.quantitative
 */
pv.Scale.log = function() {
  var scale = pv.Scale.quantitative(1, 10),
      b, // logarithm base
      p, // cached Math.log(b)
      /** @ignore */ log = function(x) { return Math.log(x) / p; },
      /** @ignore */ pow = function(y) { return Math.pow(b, y); };

  /**
   * Returns an array of evenly-spaced, suitably-rounded values in the input
   * domain. These values are frequently used in conjunction with
   * {@link pv.Rule} to display tick marks or grid lines.
   *
   * @function
   * @name pv.Scale.log.prototype.ticks
   * @returns {number[]} an array input domain values to use as ticks.
   */
  scale.ticks = function() {
    // TODO support non-uniform domains
    var d = scale.domain(),
        n = d[0] < 0,
        i = Math.floor(n ? -log(-d[0]) : log(d[0])),
        j = Math.ceil(n ? -log(-d[1]) : log(d[1])),
        ticks = [];
    if (n) {
      ticks.push(-pow(-i));
      for (; i++ < j;) for (var k = b - 1; k > 0; k--) ticks.push(-pow(-i) * k);
    } else {
      for (; i < j; i++) for (var k = 1; k < b; k++) ticks.push(pow(i) * k);
      ticks.push(pow(i));
    }
    for (i = 0; ticks[i] < d[0]; i++); // strip small values
    for (j = ticks.length; ticks[j - 1] > d[1]; j--); // strip big values
    return ticks.slice(i, j);
  };

  /**
   * Formats the specified tick value using the appropriate precision, assuming
   * base 10.
   *
   * @function
   * @name pv.Scale.log.prototype.tickFormat
   * @param {number} t a tick value.
   * @returns {string} a formatted tick value.
   */
  scale.tickFormat = function(t) {
    return t.toPrecision(1);
  };

  /**
   * "Nices" this scale, extending the bounds of the input domain to
   * evenly-rounded values. This method uses {@link pv.logFloor} and
   * {@link pv.logCeil}. Nicing is useful if the domain is computed dynamically
   * from data, and may be irregular. For example, given a domain of
   * [0.20147987687960267, 0.996679553296417], a call to <tt>nice()</tt> might
   * extend the domain to [0.1, 1].
   *
   * <p>This method must be invoked each time after setting the domain (and
   * base).
   *
   * @function
   * @name pv.Scale.log.prototype.nice
   * @returns {pv.Scale.log} <tt>this</tt>.
   */
  scale.nice = function() {
    // TODO support non-uniform domains
    var d = scale.domain();
    return scale.domain(pv.logFloor(d[0], b), pv.logCeil(d[1], b));
  };

  /**
   * Sets or gets the logarithm base. Defaults to 10.
   *
   * @function
   * @name pv.Scale.log.prototype.base
   * @param {number} [v] the new base.
   * @returns {pv.Scale.log} <tt>this</tt>, or the current base.
   */
  scale.base = function(v) {
    if (arguments.length) {
      b = Number(v);
      p = Math.log(b);
      scale.transform(log, pow); // update transformed domain
      return this;
    }
    return b;
  };

  scale.domain.apply(scale, arguments);
  return scale.base(10);
};
/**
 * Returns a root scale for the specified domain. The arguments to this
 * constructor are optional, and equivalent to calling {@link #domain}.
 * The default domain and range are [0,1].
 *
 * @class Represents a root scale; a function that performs a power
 * transformation. <style type="text/css">sub{line-height:0}</style> Most
 * commonly, a root scale represents a 1-dimensional root transformation from a
 * numeric domain of input data [<i>d<sub>0</sub></i>, <i>d<sub>1</sub></i>] to
 * a numeric range of pixels [<i>r<sub>0</sub></i>, <i>r<sub>1</sub></i>].
 *
 * <p>Note that the scale is itself a function, and thus can be used as a
 * property directly, assuming that the data associated with a mark is a
 * number. While this is convenient for single-use scales, frequently it is
 * desirable to define scales globally:
 *
 * <pre>var y = pv.Scale.root(0, 100).range(0, 640);</pre>
 *
 * The <tt>y</tt> scale can now be equivalently referenced within a property:
 *
 * <pre>    .height(function(d) y(d))</pre>
 *
 * Alternatively, if the data are not simple numbers, the appropriate value can
 * be passed to the <tt>y</tt> scale (e.g., <tt>d.foo</tt>). The {@link #by}
 * method similarly allows the data to be mapped to a numeric value before
 * performing the root transformation.
 *
 * @param {number...} domain... optional domain values.
 * @extends pv.Scale.quantitative
 */
pv.Scale.root = function() {
  var scale = pv.Scale.quantitative();

  /**
   * Sets or gets the exponent; defaults to 2.
   *
   * @function
   * @name pv.Scale.root.prototype.power
   * @param {number} [v] the new exponent.
   * @returns {pv.Scale.root} <tt>this</tt>, or the current base.
   */
  scale.power = function(v) {
    if (arguments.length) {
      var b = Number(v), p = 1 / b;
      scale.transform(
        function(x) { return Math.pow(x, p); },
        function(y) { return Math.pow(y, b); });
      return this;
    }
    return b;
  };

  scale.domain.apply(scale, arguments);
  return scale.power(2);
};
/**
 * Returns an ordinal scale for the specified domain. The arguments to this
 * constructor are optional, and equivalent to calling {@link #domain}.
 *
 * @class Represents an ordinal scale. <style
 * type="text/css">sub{line-height:0}</style> An ordinal scale represents a
 * pairwise mapping from <i>n</i> discrete values in the input domain to
 * <i>n</i> discrete values in the output range. For example, an ordinal scale
 * might map a domain of species ["setosa", "versicolor", "virginica"] to colors
 * ["red", "green", "blue"]. Thus, saying
 *
 * <pre>    .fillStyle(function(d) {
 *         switch (d.species) {
 *           case "setosa": return "red";
 *           case "versicolor": return "green";
 *           case "virginica": return "blue";
 *         }
 *       })</pre>
 *
 * is equivalent to
 *
 * <pre>    .fillStyle(pv.Scale.ordinal("setosa", "versicolor", "virginica")
 *         .range("red", "green", "blue")
 *         .by(function(d) d.species))</pre>
 *
 * If the mapping from species to color does not need to be specified
 * explicitly, the domain can be omitted. In this case it will be inferred
 * lazily from the data:
 *
 * <pre>    .fillStyle(pv.colors("red", "green", "blue")
 *         .by(function(d) d.species))</pre>
 *
 * When the domain is inferred, the first time the scale is invoked, the first
 * element from the range will be returned. Subsequent calls with unique values
 * will return subsequent elements from the range. If the inferred domain grows
 * larger than the range, range values will be reused. However, it is strongly
 * recommended that the domain and the range contain the same number of
 * elements.
 *
 * <p>A range can be discretized from a continuous interval (e.g., for pixel
 * positioning) by using {@link #split}, {@link #splitFlush} or
 * {@link #splitBanded} after the domain has been set. For example, if
 * <tt>states</tt> is an array of the fifty U.S. state names, the state name can
 * be encoded in the left position:
 *
 * <pre>    .left(pv.Scale.ordinal(states)
 *         .split(0, 640)
 *         .by(function(d) d.state))</pre>
 *
 * <p>N.B.: ordinal scales are not invertible (at least not yet), since the
 * domain and range and discontinuous. A workaround is to use a linear scale.
 *
 * @param {...} domain... optional domain values.
 * @extends pv.Scale
 * @see pv.colors
 */
pv.Scale.ordinal = function() {
  var d = [], i = {}, r = [], band = 0;

  /** @private */
  function scale(x) {
    if (!(x in i)) i[x] = d.push(x) - 1;
    return r[i[x] % r.length];
  }

  /**
   * Sets or gets the input domain. This method can be invoked several ways:
   *
   * <p>1. <tt>domain(values...)</tt>
   *
   * <p>Specifying the domain as a series of values is the most explicit and
   * recommended approach. However, if the domain values are derived from data,
   * you may find the second method more appropriate.
   *
   * <p>2. <tt>domain(array, f)</tt>
   *
   * <p>Rather than enumerating the domain values as explicit arguments to this
   * method, you can specify a single argument of an array. In addition, you can
   * specify an optional accessor function to extract the domain values from the
   * array.
   *
   * <p>3. <tt>domain()</tt>
   *
   * <p>Invoking the <tt>domain</tt> method with no arguments returns the
   * current domain as an array.
   *
   * @function
   * @name pv.Scale.ordinal.prototype.domain
   * @param {...} domain... domain values.
   * @returns {pv.Scale.ordinal} <tt>this</tt>, or the current domain.
   */
  scale.domain = function(array, f) {
    if (arguments.length) {
      array = (array instanceof Array)
          ? ((arguments.length > 1) ? pv.map(array, f) : array)
          : Array.prototype.slice.call(arguments);

      /* Filter the specified ordinals to their unique values. */
      d = [];
      var seen = {};
      for (var j = 0; j < array.length; j++) {
        var o = array[j];
        if (!(o in seen)) {
          seen[o] = true;
          d.push(o);
        }
      }

      i = pv.numerate(d);
      return this;
    }
    return d;
  };

  /**
   * Sets or gets the output range. This method can be invoked several ways:
   *
   * <p>1. <tt>range(values...)</tt>
   *
   * <p>Specifying the range as a series of values is the most explicit and
   * recommended approach. However, if the range values are derived from data,
   * you may find the second method more appropriate.
   *
   * <p>2. <tt>range(array, f)</tt>
   *
   * <p>Rather than enumerating the range values as explicit arguments to this
   * method, you can specify a single argument of an array. In addition, you can
   * specify an optional accessor function to extract the range values from the
   * array.
   *
   * <p>3. <tt>range()</tt>
   *
   * <p>Invoking the <tt>range</tt> method with no arguments returns the
   * current range as an array.
   *
   * @function
   * @name pv.Scale.ordinal.prototype.range
   * @param {...} range... range values.
   * @returns {pv.Scale.ordinal} <tt>this</tt>, or the current range.
   */
  scale.range = function(array, f) {
    if (arguments.length) {
      r = (array instanceof Array)
          ? ((arguments.length > 1) ? pv.map(array, f) : array)
          : Array.prototype.slice.call(arguments);
      if (typeof r[0] == "string") r = r.map(pv.color);
      return this;
    }
    return r;
  };

  /**
   * Sets the range from the given continuous interval. The interval
   * [<i>min</i>, <i>max</i>] is subdivided into <i>n</i> equispaced points,
   * where <i>n</i> is the number of (unique) values in the domain. The first
   * and last point are offset from the edge of the range by half the distance
   * between points.
   *
   * <p>This method must be called <i>after</i> the domain is set.
   *
   * @function
   * @name pv.Scale.ordinal.prototype.split
   * @param {number} min minimum value of the output range.
   * @param {number} max maximum value of the output range.
   * @returns {pv.Scale.ordinal} <tt>this</tt>.
   * @see #splitFlush
   * @see #splitBanded
   */
  scale.split = function(min, max) {
    var step = (max - min) / this.domain().length;
    r = pv.range(min + step / 2, max, step);
    return this;
  };

  /**
   * Sets the range from the given continuous interval. The interval
   * [<i>min</i>, <i>max</i>] is subdivided into <i>n</i> equispaced points,
   * where <i>n</i> is the number of (unique) values in the domain. The first
   * and last point are exactly on the edge of the range.
   *
   * <p>This method must be called <i>after</i> the domain is set.
   *
   * @function
   * @name pv.Scale.ordinal.prototype.splitFlush
   * @param {number} min minimum value of the output range.
   * @param {number} max maximum value of the output range.
   * @returns {pv.Scale.ordinal} <tt>this</tt>.
   * @see #split
   */
  scale.splitFlush = function(min, max) {
    var n = this.domain().length, step = (max - min) / (n - 1);
    r = (n == 1) ? [(min + max) / 2]
        : pv.range(min, max + step / 2, step);
    return this;
  };

  /**
   * Sets the range from the given continuous interval. The interval
   * [<i>min</i>, <i>max</i>] is subdivided into <i>n</i> equispaced bands,
   * where <i>n</i> is the number of (unique) values in the domain. The first
   * and last band are offset from the edge of the range by the distance between
   * bands.
   *
   * <p>The band width argument, <tt>band</tt>, is typically in the range [0, 1]
   * and defaults to 1. This fraction corresponds to the amount of space in the
   * range to allocate to the bands, as opposed to padding. A value of 0.5 means
   * that the band width will be equal to the padding width. The computed
   * absolute band width can be retrieved from the range as
   * <tt>scale.range().band</tt>.
   *
   * <p>If the band width argument is negative, this method will allocate bands
   * of a <i>fixed</i> width <tt>-band</tt>, rather than a relative fraction of
   * the available space.
   *
   * <p>Tip: to inset the bands by a fixed amount <tt>p</tt>, specify a minimum
   * value of <tt>min + p</tt> (or simply <tt>p</tt>, if <tt>min</tt> is
   * 0). Then set the mark width to <tt>scale.range().band - p</tt>.
   *
   * <p>This method must be called <i>after</i> the domain is set.
   *
   * @function
   * @name pv.Scale.ordinal.prototype.splitBanded
   * @param {number} min minimum value of the output range.
   * @param {number} max maximum value of the output range.
   * @param {number} [band] the fractional band width in [0, 1]; defaults to 1.
   * @returns {pv.Scale.ordinal} <tt>this</tt>.
   * @see #split
   */
  scale.splitBanded = function(min, max, band) {
    if (arguments.length < 3) band = 1;
    if (band < 0) {
      var n = this.domain().length,
          total = -band * n,
          remaining = max - min - total,
          padding = remaining / (n + 1);
      r = pv.range(min + padding, max, padding - band);
      r.band = -band;
    } else {
      var step = (max - min) / (this.domain().length + (1 - band));
      r = pv.range(min + step * (1 - band), max, step);
      r.band = step * band;
    }
    return this;
  };

  /**
   * Returns a view of this scale by the specified accessor function <tt>f</tt>.
   * Given a scale <tt>y</tt>, <tt>y.by(function(d) d.foo)</tt> is equivalent to
   * <tt>function(d) y(d.foo)</tt>. This method should be used judiciously; it
   * is typically more clear to invoke the scale directly, passing in the value
   * to be scaled.
   *
   * @function
   * @name pv.Scale.ordinal.prototype.by
   * @param {function} f an accessor function.
   * @returns {pv.Scale.ordinal} a view of this scale by the specified accessor
   * function.
   */
  scale.by = function(f) {
    function by() { return scale(f.apply(this, arguments)); }
    for (var method in scale) by[method] = scale[method];
    return by;
  };

  scale.domain.apply(scale, arguments);
  return scale;
};
/**
 * Constructs a default quantile scale. The arguments to this constructor are
 * optional, and equivalent to calling {@link #domain}. The default domain is
 * the empty set, and the default range is [0,1].
 *
 * @class Represents a quantile scale; a function that maps from a value within
 * a sortable domain to a quantized numeric range. Typically, the domain is a
 * set of numbers, but any sortable value (such as strings) can be used as the
 * domain of a quantile scale. The range defaults to [0,1], with 0 corresponding
 * to the smallest value in the domain, 1 the largest, .5 the median, etc.
 *
 * <p>By default, the number of quantiles in the range corresponds to the number
 * of values in the domain. The {@link #quantiles} method can be used to specify
 * an explicit number of quantiles; for example, <tt>quantiles(4)</tt> produces
 * a standard quartile scale. A quartile scale's range is a set of four discrete
 * values, such as [0, 1/3, 2/3, 1]. Calling the {@link #range} method will
 * scale these discrete values accordingly, similar to {@link
 * pv.Scale.ordinal#splitFlush}.
 *
 * <p>For example, given the strings ["c", "a", "b"], a default quantile scale:
 *
 * <pre>pv.Scale.quantile("c", "a", "b")</pre>
 *
 * will return 0 for "a", .5 for "b", and 1 for "c".
 *
 * @extends pv.Scale
 */
pv.Scale.quantile = function() {
  var n = -1, // number of quantiles
      j = -1, // max quantile index
      q = [], // quantile boundaries
      d = [], // domain
      y = pv.Scale.linear(); // range

  /** @private */
  function scale(x) {
    return y(Math.max(0, Math.min(j, pv.search.index(q, x) - 1)) / j);
  }

  /**
   * Sets or gets the quantile boundaries. By default, each element in the
   * domain is in its own quantile. If the argument to this method is a number,
   * it specifies the number of equal-sized quantiles by which to divide the
   * domain.
   *
   * <p>If no arguments are specified, this method returns the quantile
   * boundaries; the first element is always the minimum value of the domain,
   * and the last element is the maximum value of the domain. Thus, the length
   * of the returned array is always one greater than the number of quantiles.
   *
   * @function
   * @name pv.Scale.quantile.prototype.quantiles
   * @param {number} x the number of quantiles.
   */
  scale.quantiles = function(x) {
    if (arguments.length) {
      n = Number(x);
      if (n < 0) {
        q = [d[0]].concat(d);
        j = d.length - 1;
      } else {
        q = [];
        q[0] = d[0];
        for (var i = 1; i <= n; i++) {
          q[i] = d[~~(i * (d.length - 1) / n)];
        }
        j = n - 1;
      }
      return this;
    }
    return q;
  };

  /**
   * Sets or gets the input domain. This method can be invoked several ways:
   *
   * <p>1. <tt>domain(values...)</tt>
   *
   * <p>Specifying the domain as a series of values is the most explicit and
   * recommended approach. However, if the domain values are derived from data,
   * you may find the second method more appropriate.
   *
   * <p>2. <tt>domain(array, f)</tt>
   *
   * <p>Rather than enumerating the domain values as explicit arguments to this
   * method, you can specify a single argument of an array. In addition, you can
   * specify an optional accessor function to extract the domain values from the
   * array.
   *
   * <p>3. <tt>domain()</tt>
   *
   * <p>Invoking the <tt>domain</tt> method with no arguments returns the
   * current domain as an array.
   *
   * @function
   * @name pv.Scale.quantile.prototype.domain
   * @param {...} domain... domain values.
   * @returns {pv.Scale.quantile} <tt>this</tt>, or the current domain.
   */
  scale.domain = function(array, f) {
    if (arguments.length) {
      d = (array instanceof Array)
          ? pv.map(array, f)
          : Array.prototype.slice.call(arguments);
      d.sort(pv.naturalOrder);
      scale.quantiles(n); // recompute quantiles
      return this;
    }
    return d;
  };

  /**
   * Sets or gets the output range. This method can be invoked several ways:
   *
   * <p>1. <tt>range(min, ..., max)</tt>
   *
   * <p>The range may be specified as a series of numbers or colors. Most
   * commonly, two numbers are specified: the minimum and maximum pixel values.
   * For a color scale, values may be specified as {@link pv.Color}s or
   * equivalent strings. For a diverging scale, or other subdivided non-uniform
   * scales, multiple values can be specified. For example:
   *
   * <pre>    .range("red", "white", "green")</pre>
   *
   * <p>Currently, only numbers and colors are supported as range values. The
   * number of range values must exactly match the number of domain values, or
   * the behavior of the scale is undefined.
   *
   * <p>2. <tt>range()</tt>
   *
   * <p>Invoking the <tt>range</tt> method with no arguments returns the current
   * range as an array of numbers or colors.
   *
   * @function
   * @name pv.Scale.quantile.prototype.range
   * @param {...} range... range values.
   * @returns {pv.Scale.quantile} <tt>this</tt>, or the current range.
   */
  scale.range = function() {
    if (arguments.length) {
      y.range.apply(y, arguments);
      return this;
    }
    return y.range();
  };

  /**
   * Returns a view of this scale by the specified accessor function <tt>f</tt>.
   * Given a scale <tt>y</tt>, <tt>y.by(function(d) d.foo)</tt> is equivalent to
   * <tt>function(d) y(d.foo)</tt>.
   *
   * <p>This method is provided for convenience, such that scales can be
   * succinctly defined inline. For example, given an array of data elements
   * that have a <tt>score</tt> attribute with the domain [0, 1], the height
   * property could be specified as:
   *
   * <pre>.height(pv.Scale.linear().range(0, 480).by(function(d) d.score))</pre>
   *
   * This is equivalent to:
   *
   * <pre>.height(function(d) d.score * 480)</pre>
   *
   * This method should be used judiciously; it is typically more clear to
   * invoke the scale directly, passing in the value to be scaled.
   *
   * @function
   * @name pv.Scale.quantile.prototype.by
   * @param {function} f an accessor function.
   * @returns {pv.Scale.quantile} a view of this scale by the specified
   * accessor function.
   */
  scale.by = function(f) {
    function by() { return scale(f.apply(this, arguments)); }
    for (var method in scale) by[method] = scale[method];
    return by;
  };

  scale.domain.apply(scale, arguments);
  return scale;
};
/**
 * Returns a histogram operator for the specified data, with an optional
 * accessor function. If the data specified is not an array of numbers, an
 * accessor function must be specified to map the data to numeric values.
 *
 * @class Represents a histogram operator.
 *
 * @param {array} data an array of numbers or objects.
 * @param {function} [f] an optional accessor function.
 */
pv.histogram = function(data, f) {
  var frequency = true;
  return {

    /**
     * Returns the computed histogram bins. An optional array of numbers,
     * <tt>ticks</tt>, may be specified as the break points. If the ticks are
     * not specified, default ticks will be computed using a linear scale on the
     * data domain.
     *
     * <p>The returned array contains {@link pv.histogram.Bin}s. The <tt>x</tt>
     * attribute corresponds to the bin's start value (inclusive), while the
     * <tt>dx</tt> attribute stores the bin size (end - start). The <tt>y</tt>
     * attribute stores either the frequency count or probability, depending on
     * how the histogram operator has been configured.
     *
     * <p>The {@link pv.histogram.Bin} objects are themselves arrays, containing
     * the data elements present in each bin, i.e., the elements in the
     * <tt>data</tt> array (prior to invoking the accessor function, if any).
     * For example, if the data represented countries, and the accessor function
     * returned the GDP of each country, the returned bins would be arrays of
     * countries (not GDPs).
     *
     * @function
     * @name pv.histogram.prototype.bins
     * @param {array} [ticks]
     * @returns {array}
     */ /** @private */
    bins: function(ticks) {
      var x = pv.map(data, f), bins = [];

      /* Initialize default ticks. */
      if (!arguments.length) ticks = pv.Scale.linear(x).ticks();

      /* Initialize the bins. */
      for (var i = 0; i < ticks.length - 1; i++) {
        var bin = bins[i] = [];
        bin.x = ticks[i];
        bin.dx = ticks[i + 1] - ticks[i];
        bin.y = 0;
      }

      /* Count the number of samples per bin. */
      for (var i = 0; i < x.length; i++) {
        var j = pv.search.index(ticks, x[i]) - 1,
            bin = bins[Math.max(0, Math.min(bins.length - 1, j))];
        bin.y++;
        bin.push(data[i]);
      }

      /* Convert frequencies to probabilities. */
      if (!frequency) for (var i = 0; i < bins.length; i++) {
        bins[i].y /= x.length;
      }

      return bins;
    },

    /**
     * Sets or gets whether this histogram operator returns frequencies or
     * probabilities.
     *
     * @function
     * @name pv.histogram.prototype.frequency
     * @param {boolean} [x]
     * @returns {pv.histogram} this.
     */ /** @private */
    frequency: function(x) {
      if (arguments.length) {
        frequency = Boolean(x);
        return this;
      }
      return frequency;
    }
  };
};

/**
 * @class Represents a bin returned by the {@link pv.histogram} operator. Bins
 * are themselves arrays containing the data elements present in the given bin
 * (prior to the accessor function being invoked to convert the data object to a
 * numeric value). These bin arrays have additional attributes with meta
 * information about the bin.
 *
 * @name pv.histogram.Bin
 * @extends array
 * @see pv.histogram
 */

/**
 * The start value of the bin's range.
 *
 * @type number
 * @name pv.histogram.Bin.prototype.x
 */

/**
 * The magnitude value of the bin's range; end - start.
 *
 * @type number
 * @name pv.histogram.Bin.prototype.dx
 */

/**
 * The frequency or probability of the bin, depending on how the histogram
 * operator was configured.
 *
 * @type number
 * @name pv.histogram.Bin.prototype.y
 */
/**
 * Returns the {@link pv.Color} for the specified color format string. Colors
 * may have an associated opacity, or alpha channel. Color formats are specified
 * by CSS Color Modular Level 3, using either in RGB or HSL color space. For
 * example:<ul>
 *
 * <li>#f00 // #rgb
 * <li>#ff0000 // #rrggbb
 * <li>rgb(255, 0, 0)
 * <li>rgb(100%, 0%, 0%)
 * <li>hsl(0, 100%, 50%)
 * <li>rgba(0, 0, 255, 0.5)
 * <li>hsla(120, 100%, 50%, 1)
 *
 * </ul>The SVG 1.0 color keywords names are also supported, such as "aliceblue"
 * and "yellowgreen". The "transparent" keyword is supported for fully-
 * transparent black.
 *
 * <p>If the <tt>format</tt> argument is already an instance of <tt>Color</tt>,
 * the argument is returned with no further processing.
 *
 * @param {string} format the color specification string, such as "#f00".
 * @returns {pv.Color} the corresponding <tt>Color</tt>.
 * @see <a href="http://www.w3.org/TR/SVG/types.html#ColorKeywords">SVG color
 * keywords</a>
 * @see <a href="http://www.w3.org/TR/css3-color/">CSS3 color module</a>
 */
pv.color = function(format) {
  if (format.rgb) return format.rgb();

  /* Handle hsl, rgb. */
  var m1 = /([a-z]+)\((.*)\)/i.exec(format);
  if (m1) {
    var m2 = m1[2].split(","), a = 1;
    switch (m1[1]) {
      case "hsla":
      case "rgba": {
        a = parseFloat(m2[3]);
        if (!a) return pv.Color.transparent;
        break;
      }
    }
    switch (m1[1]) {
      case "hsla":
      case "hsl": {
        var h = parseFloat(m2[0]), // degrees
            s = parseFloat(m2[1]) / 100, // percentage
            l = parseFloat(m2[2]) / 100; // percentage
        return (new pv.Color.Hsl(h, s, l, a)).rgb();
      }
      case "rgba":
      case "rgb": {
        function parse(c) { // either integer or percentage
          var f = parseFloat(c);
          return (c[c.length - 1] == '%') ? Math.round(f * 2.55) : f;
        }
        var r = parse(m2[0]), g = parse(m2[1]), b = parse(m2[2]);
        return pv.rgb(r, g, b, a);
      }
    }
  }

  /* Named colors. */
  var named = pv.Color.names[format];
  if (named) return named;

  /* Hexadecimal colors: #rgb and #rrggbb. */
  if (format.charAt(0) == "#") {
    var r, g, b;
    if (format.length == 4) {
      r = format.charAt(1); r += r;
      g = format.charAt(2); g += g;
      b = format.charAt(3); b += b;
    } else if (format.length == 7) {
      r = format.substring(1, 3);
      g = format.substring(3, 5);
      b = format.substring(5, 7);
    }
    return pv.rgb(parseInt(r, 16), parseInt(g, 16), parseInt(b, 16), 1);
  }

  /* Otherwise, pass-through unsupported colors. */
  return new pv.Color(format, 1);
};

/**
 * Constructs a color with the specified color format string and opacity. This
 * constructor should not be invoked directly; use {@link pv.color} instead.
 *
 * @class Represents an abstract (possibly translucent) color. The color is
 * divided into two parts: the <tt>color</tt> attribute, an opaque color format
 * string, and the <tt>opacity</tt> attribute, a float in [0, 1]. The color
 * space is dependent on the implementing class; all colors support the
 * {@link #rgb} method to convert to RGB color space for interpolation.
 *
 * <p>See also the <a href="../../api/Color.html">Color guide</a>.
 *
 * @param {string} color an opaque color format string, such as "#f00".
 * @param {number} opacity the opacity, in [0,1].
 * @see pv.color
 */
pv.Color = function(color, opacity) {
  /**
   * An opaque color format string, such as "#f00".
   *
   * @type string
   * @see <a href="http://www.w3.org/TR/SVG/types.html#ColorKeywords">SVG color
   * keywords</a>
   * @see <a href="http://www.w3.org/TR/css3-color/">CSS3 color module</a>
   */
  this.color = color;

  /**
   * The opacity, a float in [0, 1].
   *
   * @type number
   */
  this.opacity = opacity;
};

/**
 * Returns a new color that is a brighter version of this color. The behavior of
 * this method may vary slightly depending on the underlying color space.
 * Although brighter and darker are inverse operations, the results of a series
 * of invocations of these two methods might be inconsistent because of rounding
 * errors.
 *
 * @param [k] {number} an optional scale factor; defaults to 1.
 * @see #darker
 * @returns {pv.Color} a brighter color.
 */
pv.Color.prototype.brighter = function(k) {
  return this.rgb().brighter(k);
};

/**
 * Returns a new color that is a brighter version of this color. The behavior of
 * this method may vary slightly depending on the underlying color space.
 * Although brighter and darker are inverse operations, the results of a series
 * of invocations of these two methods might be inconsistent because of rounding
 * errors.
 *
 * @param [k] {number} an optional scale factor; defaults to 1.
 * @see #brighter
 * @returns {pv.Color} a darker color.
 */
pv.Color.prototype.darker = function(k) {
  return this.rgb().darker(k);
};

/**
 * Constructs a new RGB color with the specified channel values.
 *
 * @param {number} r the red channel, an integer in [0,255].
 * @param {number} g the green channel, an integer in [0,255].
 * @param {number} b the blue channel, an integer in [0,255].
 * @param {number} [a] the alpha channel, a float in [0,1].
 * @returns pv.Color.Rgb
 */
pv.rgb = function(r, g, b, a) {
  return new pv.Color.Rgb(r, g, b, (arguments.length == 4) ? a : 1);
};

/**
 * Constructs a new RGB color with the specified channel values.
 *
 * @class Represents a color in RGB space.
 *
 * @param {number} r the red channel, an integer in [0,255].
 * @param {number} g the green channel, an integer in [0,255].
 * @param {number} b the blue channel, an integer in [0,255].
 * @param {number} a the alpha channel, a float in [0,1].
 * @extends pv.Color
 */
pv.Color.Rgb = function(r, g, b, a) {
  pv.Color.call(this, a ? ("rgb(" + r + "," + g + "," + b + ")") : "none", a);

  /**
   * The red channel, an integer in [0, 255].
   *
   * @type number
   */
  this.r = r;

  /**
   * The green channel, an integer in [0, 255].
   *
   * @type number
   */
  this.g = g;

  /**
   * The blue channel, an integer in [0, 255].
   *
   * @type number
   */
  this.b = b;

  /**
   * The alpha channel, a float in [0, 1].
   *
   * @type number
   */
  this.a = a;
};
pv.Color.Rgb.prototype = pv.extend(pv.Color);

/**
 * Constructs a new RGB color with the same green, blue and alpha channels as
 * this color, with the specified red channel.
 *
 * @param {number} r the red channel, an integer in [0,255].
 */
pv.Color.Rgb.prototype.red = function(r) {
  return pv.rgb(r, this.g, this.b, this.a);
};

/**
 * Constructs a new RGB color with the same red, blue and alpha channels as this
 * color, with the specified green channel.
 *
 * @param {number} g the green channel, an integer in [0,255].
 */
pv.Color.Rgb.prototype.green = function(g) {
  return pv.rgb(this.r, g, this.b, this.a);
};

/**
 * Constructs a new RGB color with the same red, green and alpha channels as
 * this color, with the specified blue channel.
 *
 * @param {number} b the blue channel, an integer in [0,255].
 */
pv.Color.Rgb.prototype.blue = function(b) {
  return pv.rgb(this.r, this.g, b, this.a);
};

/**
 * Constructs a new RGB color with the same red, green and blue channels as this
 * color, with the specified alpha channel.
 *
 * @param {number} a the alpha channel, a float in [0,1].
 */
pv.Color.Rgb.prototype.alpha = function(a) {
  return pv.rgb(this.r, this.g, this.b, a);
};

/**
 * Returns the RGB color equivalent to this color. This method is abstract and
 * must be implemented by subclasses.
 *
 * @returns {pv.Color.Rgb} an RGB color.
 * @function
 * @name pv.Color.prototype.rgb
 */

/**
 * Returns this.
 *
 * @returns {pv.Color.Rgb} this.
 */
pv.Color.Rgb.prototype.rgb = function() { return this; };

/**
 * Returns a new color that is a brighter version of this color. This method
 * applies an arbitrary scale factor to each of the three RGB components of this
 * color to create a brighter version of this color. Although brighter and
 * darker are inverse operations, the results of a series of invocations of
 * these two methods might be inconsistent because of rounding errors.
 *
 * @param [k] {number} an optional scale factor; defaults to 1.
 * @see #darker
 * @returns {pv.Color.Rgb} a brighter color.
 */
pv.Color.Rgb.prototype.brighter = function(k) {
  k = Math.pow(0.7, arguments.length ? k : 1);
  var r = this.r, g = this.g, b = this.b, i = 30;
  if (!r && !g && !b) return pv.rgb(i, i, i, this.a);
  if (r && (r < i)) r = i;
  if (g && (g < i)) g = i;
  if (b && (b < i)) b = i;
  return pv.rgb(
      Math.min(255, Math.floor(r / k)),
      Math.min(255, Math.floor(g / k)),
      Math.min(255, Math.floor(b / k)),
      this.a);
};

/**
 * Returns a new color that is a darker version of this color. This method
 * applies an arbitrary scale factor to each of the three RGB components of this
 * color to create a darker version of this color. Although brighter and darker
 * are inverse operations, the results of a series of invocations of these two
 * methods might be inconsistent because of rounding errors.
 *
 * @param [k] {number} an optional scale factor; defaults to 1.
 * @see #brighter
 * @returns {pv.Color.Rgb} a darker color.
 */
pv.Color.Rgb.prototype.darker = function(k) {
  k = Math.pow(0.7, arguments.length ? k : 1);
  return pv.rgb(
      Math.max(0, Math.floor(k * this.r)),
      Math.max(0, Math.floor(k * this.g)),
      Math.max(0, Math.floor(k * this.b)),
      this.a);
};

/**
 * Constructs a new HSL color with the specified values.
 *
 * @param {number} h the hue, an integer in [0, 360].
 * @param {number} s the saturation, a float in [0, 1].
 * @param {number} l the lightness, a float in [0, 1].
 * @param {number} [a] the opacity, a float in [0, 1].
 * @returns pv.Color.Hsl
 */
pv.hsl = function(h, s, l, a) {
  return new pv.Color.Hsl(h, s, l,  (arguments.length == 4) ? a : 1);
};

/**
 * Constructs a new HSL color with the specified values.
 *
 * @class Represents a color in HSL space.
 *
 * @param {number} h the hue, an integer in [0, 360].
 * @param {number} s the saturation, a float in [0, 1].
 * @param {number} l the lightness, a float in [0, 1].
 * @param {number} a the opacity, a float in [0, 1].
 * @extends pv.Color
 */
pv.Color.Hsl = function(h, s, l, a) {
  pv.Color.call(this, "hsl(" + h + "," + (s * 100) + "%," + (l * 100) + "%)", a);

  /**
   * The hue, an integer in [0, 360].
   *
   * @type number
   */
  this.h = h;

  /**
   * The saturation, a float in [0, 1].
   *
   * @type number
   */
  this.s = s;

  /**
   * The lightness, a float in [0, 1].
   *
   * @type number
   */
  this.l = l;

  /**
   * The opacity, a float in [0, 1].
   *
   * @type number
   */
  this.a = a;
};
pv.Color.Hsl.prototype = pv.extend(pv.Color);

/**
 * Constructs a new HSL color with the same saturation, lightness and alpha as
 * this color, and the specified hue.
 *
 * @param {number} h the hue, an integer in [0, 360].
 */
pv.Color.Hsl.prototype.hue = function(h) {
  return pv.hsl(h, this.s, this.l, this.a);
};

/**
 * Constructs a new HSL color with the same hue, lightness and alpha as this
 * color, and the specified saturation.
 *
 * @param {number} s the saturation, a float in [0, 1].
 */
pv.Color.Hsl.prototype.saturation = function(s) {
  return pv.hsl(this.h, s, this.l, this.a);
};

/**
 * Constructs a new HSL color with the same hue, saturation and alpha as this
 * color, and the specified lightness.
 *
 * @param {number} l the lightness, a float in [0, 1].
 */
pv.Color.Hsl.prototype.lightness = function(l) {
  return pv.hsl(this.h, this.s, l, this.a);
};

/**
 * Constructs a new HSL color with the same hue, saturation and lightness as
 * this color, and the specified alpha.
 *
 * @param {number} a the opacity, a float in [0, 1].
 */
pv.Color.Hsl.prototype.alpha = function(a) {
  return pv.hsl(this.h, this.s, this.l, a);
};

/**
 * Returns the RGB color equivalent to this HSL color.
 *
 * @returns {pv.Color.Rgb} an RGB color.
 */
pv.Color.Hsl.prototype.rgb = function() {
  var h = this.h, s = this.s, l = this.l;

  /* Some simple corrections for h, s and l. */
  h = h % 360; if (h < 0) h += 360;
  s = Math.max(0, Math.min(s, 1));
  l = Math.max(0, Math.min(l, 1));

  /* From FvD 13.37, CSS Color Module Level 3 */
  var m2 = (l <= .5) ? (l * (1 + s)) : (l + s - l * s);
  var m1 = 2 * l - m2;
  function v(h) {
    if (h > 360) h -= 360;
    else if (h < 0) h += 360;
    if (h < 60) return m1 + (m2 - m1) * h / 60;
    if (h < 180) return m2;
    if (h < 240) return m1 + (m2 - m1) * (240 - h) / 60;
    return m1;
  }
  function vv(h) {
    return Math.round(v(h) * 255);
  }

  return pv.rgb(vv(h + 120), vv(h), vv(h - 120), this.a);
};

/**
 * @private SVG color keywords, per CSS Color Module Level 3.
 *
 * @see <a href="http://www.w3.org/TR/SVG/types.html#ColorKeywords">SVG color
 * keywords</a>
 */
pv.Color.names = {
  aliceblue: "#f0f8ff",
  antiquewhite: "#faebd7",
  aqua: "#00ffff",
  aquamarine: "#7fffd4",
  azure: "#f0ffff",
  beige: "#f5f5dc",
  bisque: "#ffe4c4",
  black: "#000000",
  blanchedalmond: "#ffebcd",
  blue: "#0000ff",
  blueviolet: "#8a2be2",
  brown: "#a52a2a",
  burlywood: "#deb887",
  cadetblue: "#5f9ea0",
  chartreuse: "#7fff00",
  chocolate: "#d2691e",
  coral: "#ff7f50",
  cornflowerblue: "#6495ed",
  cornsilk: "#fff8dc",
  crimson: "#dc143c",
  cyan: "#00ffff",
  darkblue: "#00008b",
  darkcyan: "#008b8b",
  darkgoldenrod: "#b8860b",
  darkgray: "#a9a9a9",
  darkgreen: "#006400",
  darkgrey: "#a9a9a9",
  darkkhaki: "#bdb76b",
  darkmagenta: "#8b008b",
  darkolivegreen: "#556b2f",
  darkorange: "#ff8c00",
  darkorchid: "#9932cc",
  darkred: "#8b0000",
  darksalmon: "#e9967a",
  darkseagreen: "#8fbc8f",
  darkslateblue: "#483d8b",
  darkslategray: "#2f4f4f",
  darkslategrey: "#2f4f4f",
  darkturquoise: "#00ced1",
  darkviolet: "#9400d3",
  deeppink: "#ff1493",
  deepskyblue: "#00bfff",
  dimgray: "#696969",
  dimgrey: "#696969",
  dodgerblue: "#1e90ff",
  firebrick: "#b22222",
  floralwhite: "#fffaf0",
  forestgreen: "#228b22",
  fuchsia: "#ff00ff",
  gainsboro: "#dcdcdc",
  ghostwhite: "#f8f8ff",
  gold: "#ffd700",
  goldenrod: "#daa520",
  gray: "#808080",
  green: "#008000",
  greenyellow: "#adff2f",
  grey: "#808080",
  honeydew: "#f0fff0",
  hotpink: "#ff69b4",
  indianred: "#cd5c5c",
  indigo: "#4b0082",
  ivory: "#fffff0",
  khaki: "#f0e68c",
  lavender: "#e6e6fa",
  lavenderblush: "#fff0f5",
  lawngreen: "#7cfc00",
  lemonchiffon: "#fffacd",
  lightblue: "#add8e6",
  lightcoral: "#f08080",
  lightcyan: "#e0ffff",
  lightgoldenrodyellow: "#fafad2",
  lightgray: "#d3d3d3",
  lightgreen: "#90ee90",
  lightgrey: "#d3d3d3",
  lightpink: "#ffb6c1",
  lightsalmon: "#ffa07a",
  lightseagreen: "#20b2aa",
  lightskyblue: "#87cefa",
  lightslategray: "#778899",
  lightslategrey: "#778899",
  lightsteelblue: "#b0c4de",
  lightyellow: "#ffffe0",
  lime: "#00ff00",
  limegreen: "#32cd32",
  linen: "#faf0e6",
  magenta: "#ff00ff",
  maroon: "#800000",
  mediumaquamarine: "#66cdaa",
  mediumblue: "#0000cd",
  mediumorchid: "#ba55d3",
  mediumpurple: "#9370db",
  mediumseagreen: "#3cb371",
  mediumslateblue: "#7b68ee",
  mediumspringgreen: "#00fa9a",
  mediumturquoise: "#48d1cc",
  mediumvioletred: "#c71585",
  midnightblue: "#191970",
  mintcream: "#f5fffa",
  mistyrose: "#ffe4e1",
  moccasin: "#ffe4b5",
  navajowhite: "#ffdead",
  navy: "#000080",
  oldlace: "#fdf5e6",
  olive: "#808000",
  olivedrab: "#6b8e23",
  orange: "#ffa500",
  orangered: "#ff4500",
  orchid: "#da70d6",
  palegoldenrod: "#eee8aa",
  palegreen: "#98fb98",
  paleturquoise: "#afeeee",
  palevioletred: "#db7093",
  papayawhip: "#ffefd5",
  peachpuff: "#ffdab9",
  peru: "#cd853f",
  pink: "#ffc0cb",
  plum: "#dda0dd",
  powderblue: "#b0e0e6",
  purple: "#800080",
  red: "#ff0000",
  rosybrown: "#bc8f8f",
  royalblue: "#4169e1",
  saddlebrown: "#8b4513",
  salmon: "#fa8072",
  sandybrown: "#f4a460",
  seagreen: "#2e8b57",
  seashell: "#fff5ee",
  sienna: "#a0522d",
  silver: "#c0c0c0",
  skyblue: "#87ceeb",
  slateblue: "#6a5acd",
  slategray: "#708090",
  slategrey: "#708090",
  snow: "#fffafa",
  springgreen: "#00ff7f",
  steelblue: "#4682b4",
  tan: "#d2b48c",
  teal: "#008080",
  thistle: "#d8bfd8",
  tomato: "#ff6347",
  turquoise: "#40e0d0",
  violet: "#ee82ee",
  wheat: "#f5deb3",
  white: "#ffffff",
  whitesmoke: "#f5f5f5",
  yellow: "#ffff00",
  yellowgreen: "#9acd32",
  transparent: pv.Color.transparent = pv.rgb(0, 0, 0, 0)
};

/* Initialized named colors. */
(function() {
  var names = pv.Color.names;
  for (var name in names) names[name] = pv.color(names[name]);
})();
/**
 * Returns a new categorical color encoding using the specified colors.  The
 * arguments to this method are an array of colors; see {@link pv.color}. For
 * example, to create a categorical color encoding using the <tt>species</tt>
 * attribute:
 *
 * <pre>pv.colors("red", "green", "blue").by(function(d) d.species)</pre>
 *
 * The result of this expression can be used as a fill- or stroke-style
 * property. This assumes that the data's <tt>species</tt> attribute is a
 * string.
 *
 * @param {string} colors... categorical colors.
 * @see pv.Scale.ordinal
 * @returns {pv.Scale.ordinal} an ordinal color scale.
 */
pv.colors = function() {
  var scale = pv.Scale.ordinal();
  scale.range.apply(scale, arguments);
  return scale;
};

/**
 * A collection of standard color palettes for categorical encoding.
 *
 * @namespace A collection of standard color palettes for categorical encoding.
 */
pv.Colors = {};

/**
 * Returns a new 10-color scheme. The arguments to this constructor are
 * optional, and equivalent to calling {@link pv.Scale.OrdinalScale#domain}. The
 * following colors are used:
 *
 * <div style="background:#1f77b4;">#1f77b4</div>
 * <div style="background:#ff7f0e;">#ff7f0e</div>
 * <div style="background:#2ca02c;">#2ca02c</div>
 * <div style="background:#d62728;">#d62728</div>
 * <div style="background:#9467bd;">#9467bd</div>
 * <div style="background:#8c564b;">#8c564b</div>
 * <div style="background:#e377c2;">#e377c2</div>
 * <div style="background:#7f7f7f;">#7f7f7f</div>
 * <div style="background:#bcbd22;">#bcbd22</div>
 * <div style="background:#17becf;">#17becf</div>
 *
 * @param {number...} domain... domain values.
 * @returns {pv.Scale.ordinal} a new ordinal color scale.
 * @see pv.color
 */
pv.Colors.category10 = function() {
  var scale = pv.colors(
      "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
      "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf");
  scale.domain.apply(scale, arguments);
  return scale;
};

/**
 * Returns a new 20-color scheme. The arguments to this constructor are
 * optional, and equivalent to calling {@link pv.Scale.OrdinalScale#domain}. The
 * following colors are used:
 *
 * <div style="background:#1f77b4;">#1f77b4</div>
 * <div style="background:#aec7e8;">#aec7e8</div>
 * <div style="background:#ff7f0e;">#ff7f0e</div>
 * <div style="background:#ffbb78;">#ffbb78</div>
 * <div style="background:#2ca02c;">#2ca02c</div>
 * <div style="background:#98df8a;">#98df8a</div>
 * <div style="background:#d62728;">#d62728</div>
 * <div style="background:#ff9896;">#ff9896</div>
 * <div style="background:#9467bd;">#9467bd</div>
 * <div style="background:#c5b0d5;">#c5b0d5</div>
 * <div style="background:#8c564b;">#8c564b</div>
 * <div style="background:#c49c94;">#c49c94</div>
 * <div style="background:#e377c2;">#e377c2</div>
 * <div style="background:#f7b6d2;">#f7b6d2</div>
 * <div style="background:#7f7f7f;">#7f7f7f</div>
 * <div style="background:#c7c7c7;">#c7c7c7</div>
 * <div style="background:#bcbd22;">#bcbd22</div>
 * <div style="background:#dbdb8d;">#dbdb8d</div>
 * <div style="background:#17becf;">#17becf</div>
 * <div style="background:#9edae5;">#9edae5</div>
 *
 * @param {number...} domain... domain values.
 * @returns {pv.Scale.ordinal} a new ordinal color scale.
 * @see pv.color
*/
pv.Colors.category20 = function() {
  var scale = pv.colors(
      "#1f77b4", "#aec7e8", "#ff7f0e", "#ffbb78", "#2ca02c",
      "#98df8a", "#d62728", "#ff9896", "#9467bd", "#c5b0d5",
      "#8c564b", "#c49c94", "#e377c2", "#f7b6d2", "#7f7f7f",
      "#c7c7c7", "#bcbd22", "#dbdb8d", "#17becf", "#9edae5");
  scale.domain.apply(scale, arguments);
  return scale;
};

/**
 * Returns a new alternative 19-color scheme. The arguments to this constructor
 * are optional, and equivalent to calling
 * {@link pv.Scale.OrdinalScale#domain}. The following colors are used:
 *
 * <div style="background:#9c9ede;">#9c9ede</div>
 * <div style="background:#7375b5;">#7375b5</div>
 * <div style="background:#4a5584;">#4a5584</div>
 * <div style="background:#cedb9c;">#cedb9c</div>
 * <div style="background:#b5cf6b;">#b5cf6b</div>
 * <div style="background:#8ca252;">#8ca252</div>
 * <div style="background:#637939;">#637939</div>
 * <div style="background:#e7cb94;">#e7cb94</div>
 * <div style="background:#e7ba52;">#e7ba52</div>
 * <div style="background:#bd9e39;">#bd9e39</div>
 * <div style="background:#8c6d31;">#8c6d31</div>
 * <div style="background:#e7969c;">#e7969c</div>
 * <div style="background:#d6616b;">#d6616b</div>
 * <div style="background:#ad494a;">#ad494a</div>
 * <div style="background:#843c39;">#843c39</div>
 * <div style="background:#de9ed6;">#de9ed6</div>
 * <div style="background:#ce6dbd;">#ce6dbd</div>
 * <div style="background:#a55194;">#a55194</div>
 * <div style="background:#7b4173;">#7b4173</div>
 *
 * @param {number...} domain... domain values.
 * @returns {pv.Scale.ordinal} a new ordinal color scale.
 * @see pv.color
 */
pv.Colors.category19 = function() {
  var scale = pv.colors(
      "#9c9ede", "#7375b5", "#4a5584", "#cedb9c", "#b5cf6b",
      "#8ca252", "#637939", "#e7cb94", "#e7ba52", "#bd9e39",
      "#8c6d31", "#e7969c", "#d6616b", "#ad494a", "#843c39",
      "#de9ed6", "#ce6dbd", "#a55194", "#7b4173");
  scale.domain.apply(scale, arguments);
  return scale;
};
/**
 * Returns a linear color ramp from the specified <tt>start</tt> color to the
 * specified <tt>end</tt> color. The color arguments may be specified either as
 * <tt>string</tt>s or as {@link pv.Color}s. This is equivalent to:
 *
 * <pre>    pv.Scale.linear().domain(0, 1).range(...)</pre>
 *
 * @param {string} start the start color; may be a <tt>pv.Color</tt>.
 * @param {string} end the end color; may be a <tt>pv.Color</tt>.
 * @returns {Function} a color ramp from <tt>start</tt> to <tt>end</tt>.
 * @see pv.Scale.linear
 */
pv.ramp = function(start, end) {
  var scale = pv.Scale.linear();
  scale.range.apply(scale, arguments);
  return scale;
};
