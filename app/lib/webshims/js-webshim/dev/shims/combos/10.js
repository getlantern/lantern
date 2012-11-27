// vim: ts=4 sts=4 sw=4 expandtab
// -- kriskowal Kris Kowal Copyright (C) 2009-2011 MIT License
// -- tlrobinson Tom Robinson Copyright (C) 2009-2010 MIT License (Narwhal Project)
// -- dantman Daniel Friesen Copyright (C) 2010 XXX TODO License or CLA
// -- fschaefer Florian Schäfer Copyright (C) 2010 MIT License
// -- Gozala Irakli Gozalishvili Copyright (C) 2010 MIT License
// -- kitcambridge Kit Cambridge Copyright (C) 2011 MIT License
// -- kossnocorp Sasha Koss XXX TODO License or CLA
// -- bryanforbes Bryan Forbes XXX TODO License or CLA
// -- killdream Quildreen Motta Copyright (C) 2011 MIT Licence
// -- michaelficarra Michael Ficarra Copyright (C) 2011 3-clause BSD License
// -- sharkbrainguy Gerard Paapu Copyright (C) 2011 MIT License
// -- bbqsrc Brendan Molloy XXX TODO License or CLA
// -- iwyg XXX TODO License or CLA
// -- DomenicDenicola Domenic Denicola XXX TODO License or CLA
// -- xavierm02 Montillet Xavier XXX TODO License or CLA
// -- Raynos Raynos XXX TODO License or CLA
// -- samsonjs Sami Samhuri XXX TODO License or CLA
// -- rwldrn Rick Waldron Copyright (C) 2011 MIT License
// -- lexer Alexey Zakharov XXX TODO License or CLA

/*!
    Copyright (c) 2009, 280 North Inc. http://280north.com/
    MIT License. http://github.com/280north/narwhal/blob/master/README.md
*/

(function (undefined) {

/**
 * Brings an environment as close to ECMAScript 5 compliance
 * as is possible with the facilities of erstwhile engines.
 *
 * ES5 Draft
 * http://www.ecma-international.org/publications/files/drafts/tc39-2009-050.pdf
 *
 * NOTE: this is a draft, and as such, the URL is subject to change.  If the
 * link is broken, check in the parent directory for the latest TC39 PDF.
 * http://www.ecma-international.org/publications/files/drafts/
 *
 * Previous ES5 Draft
 * http://www.ecma-international.org/publications/files/drafts/tc39-2009-025.pdf
 * This is a broken link to the previous draft of ES5 on which most of the
 * numbered specification references and quotes herein were taken.  Updating
 * these references and quotes to reflect the new document would be a welcome
 * volunteer project.
 *
 * @module
 */

/*whatsupdoc*/

// Shortcut to an often accessed properties, in order to avoid multiple
// dereference that costs universally.
// _Please note: Shortcuts are defined after `Function.prototype.bind` as we
// us it in defining shortcuts.
var call = Function.prototype.call;
var prototypeOfArray = Array.prototype;
var prototypeOfObject = Object.prototype;
var slice = prototypeOfArray.slice;
var owns;
var toString;

// ES-5 15.3.4.5
// http://www.ecma-international.org/publications/files/drafts/tc39-2009-025.pdf

if (!Function.prototype.bind) {
    Function.prototype.bind = function (that) { // .length is 1
        // 1. Let Target be the this value.
        var target = this;
        // 2. If IsCallable(Target) is false, throw a TypeError exception.
        if (typeof target != "function")
            throw new TypeError(); // TODO message
        // 3. Let A be a new (possibly empty) internal list of all of the
        //   argument values provided after thisArg (arg1, arg2 etc), in order.
        // XXX slicedArgs will stand in for "A" if used
        var args = slice.call(arguments, 1); // for normal call
        // 4. Let F be a new native ECMAScript object.
        // 9. Set the [[Prototype]] internal property of F to the standard
        //   built-in Function prototype object as specified in 15.3.3.1.
        // 10. Set the [[Call]] internal property of F as described in
        //   15.3.4.5.1.
        // 11. Set the [[Construct]] internal property of F as described in
        //   15.3.4.5.2.
        // 12. Set the [[HasInstance]] internal property of F as described in
        //   15.3.4.5.3.
        // 13. The [[Scope]] internal property of F is unused and need not
        //   exist.
        var bound = function () {

            if (this instanceof bound) {
                // 15.3.4.5.2 [[Construct]]
                // When the [[Construct]] internal method of a function object,
                // F that was created using the bind function is called with a
                // list of arguments ExtraArgs the following steps are taken:
                // 1. Let target be the value of F's [[TargetFunction]]
                //   internal property.
                // 2. If target has no [[Construct]] internal method, a
                //   TypeError exception is thrown.
                // 3. Let boundArgs be the value of F's [[BoundArgs]] internal
                //   property.
                // 4. Let args be a new list containing the same values as the
                //   list boundArgs in the same order followed by the same
                //   values as the list ExtraArgs in the same order.

                var F = function(){};
                F.prototype = target.prototype;
                var self = new F;

                var result = target.apply(
                    self,
                    args.concat(slice.call(arguments))
                );
                if (result !== null && Object(result) === result)
                    return result;
                return self;

            } else {
                // 15.3.4.5.1 [[Call]]
                // When the [[Call]] internal method of a function object, F,
                // which was created using the bind function is called with a
                // this value and a list of arguments ExtraArgs the following
                // steps are taken:
                // 1. Let boundArgs be the value of F's [[BoundArgs]] internal
                //   property.
                // 2. Let boundThis be the value of F's [[BoundThis]] internal
                //   property.
                // 3. Let target be the value of F's [[TargetFunction]] internal
                //   property.
                // 4. Let args be a new list containing the same values as the list
                //   boundArgs in the same order followed by the same values as
                //   the list ExtraArgs in the same order. 5.  Return the
                //   result of calling the [[Call]] internal method of target
                //   providing boundThis as the this value and providing args
                //   as the arguments.

                // equiv: target.call(this, ...boundArgs, ...args)
                return target.apply(
                    that,
                    args.concat(slice.call(arguments))
                );

            }

        };
        // XXX bound.length is never writable, so don't even try
        //
        // 16. The length own property of F is given attributes as specified in
        //   15.3.5.1.
        // TODO
        // 17. Set the [[Extensible]] internal property of F to true.
        // TODO
        // 18. Call the [[DefineOwnProperty]] internal method of F with
        //   arguments "caller", PropertyDescriptor {[[Value]]: null,
        //   [[Writable]]: false, [[Enumerable]]: false, [[Configurable]]:
        //   false}, and false.
        // TODO
        // 19. Call the [[DefineOwnProperty]] internal method of F with
        //   arguments "arguments", PropertyDescriptor {[[Value]]: null,
        //   [[Writable]]: false, [[Enumerable]]: false, [[Configurable]]:
        //   false}, and false.
        // TODO
        // NOTE Function objects created using Function.prototype.bind do not
        // have a prototype property.
        // XXX can't delete it in pure-js.
        return bound;
    };
}

toString = call.bind(prototypeOfObject.toString);
owns = call.bind(prototypeOfObject.hasOwnProperty);


//
// Array
// =====
//

// ES5 15.4.3.2
if (!Array.isArray) {
    Array.isArray = function (obj) {
        return toString(obj) == "[object Array]";
    };
}

// The IsCallable() check in the Array functions
// has been replaced with a strict check on the
// internal class of the object to trap cases where
// the provided function was actually a regular
// expression literal, which in V8 and
// JavaScriptCore is a typeof "function".  Only in
// V8 are regular expression literals permitted as
// reduce parameters, so it is desirable in the
// general case for the shim to match the more
// strict and common behavior of rejecting regular
// expressions.

// ES5 15.4.4.18
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/array/foreach
if (!Array.prototype.forEach) {
    Array.prototype.forEach = function (fun /*, thisp*/) {
        var self = toObject(this),
            thisp = arguments[1],
            i = 0,
            length = self.length >>> 0;

        // If no callback function or if callback is not a callable function
        if (toString(fun) != "[object Function]") {
            throw new TypeError(); // TODO message
        }

        while (i < length) {
            if (i in self) {
                // Invoke the callback function with call, passing arguments:
                // context, property value, property key, thisArg object context
                fun.call(thisp, self[i], i, self);
            }
            i++;
        }
    };
}

// ES5 15.4.4.19
// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/map
if (!Array.prototype.map) {
    Array.prototype.map = function (fun /*, thisp*/) {
        var self = toObject(this),
            length = self.length >>> 0,
            result = Array(length),
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (toString(fun) != "[object Function]") {
            throw new TypeError(); // TODO message
        }

        for (var i = 0; i < length; i++) {
            if (i in self)
                result[i] = fun.call(thisp, self[i], i, self);
        }
        return result;
    };
}

// ES5 15.4.4.20
if (!Array.prototype.filter) {
    Array.prototype.filter = function (fun /*, thisp */) {
        var self = toObject(this),
            length = self.length >>> 0,
            result = [],
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (toString(fun) != "[object Function]") {
            throw new TypeError(); // TODO message
        }

        for (var i = 0; i < length; i++) {
            if (i in self && fun.call(thisp, self[i], i, self))
                result.push(self[i]);
        }
        return result;
    };
}

// ES5 15.4.4.16
if (!Array.prototype.every) {
    Array.prototype.every = function (fun /*, thisp */) {
        var self = toObject(this),
            length = self.length >>> 0,
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (toString(fun) != "[object Function]") {
            throw new TypeError(); // TODO message
        }

        for (var i = 0; i < length; i++) {
            if (i in self && !fun.call(thisp, self[i], i, self))
                return false;
        }
        return true;
    };
}

// ES5 15.4.4.17
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/some
if (!Array.prototype.some) {
    Array.prototype.some = function (fun /*, thisp */) {
        var self = toObject(this),
            length = self.length >>> 0,
            thisp = arguments[1];

        // If no callback function or if callback is not a callable function
        if (toString(fun) != "[object Function]") {
            throw new TypeError(); // TODO message
        }

        for (var i = 0; i < length; i++) {
            if (i in self && fun.call(thisp, self[i], i, self))
                return true;
        }
        return false;
    };
}

// ES5 15.4.4.21
// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/reduce
if (!Array.prototype.reduce) {
    Array.prototype.reduce = function (fun /*, initial*/) {
        var self = toObject(this),
            length = self.length >>> 0;

        // If no callback function or if callback is not a callable function
        if (toString(fun) != "[object Function]") {
            throw new TypeError(); // TODO message
        }

        // no value to return if no initial value and an empty array
        if (!length && arguments.length == 1)
            throw new TypeError(); // TODO message

        var i = 0;
        var result;
        if (arguments.length >= 2) {
            result = arguments[1];
        } else {
            do {
                if (i in self) {
                    result = self[i++];
                    break;
                }

                // if array contains no values, no initial value to return
                if (++i >= length)
                    throw new TypeError(); // TODO message
            } while (true);
        }

        for (; i < length; i++) {
            if (i in self)
                result = fun.call(void 0, result, self[i], i, self);
        }

        return result;
    };
}

// ES5 15.4.4.22
// https://developer.mozilla.org/en/Core_JavaScript_1.5_Reference/Objects/Array/reduceRight
if (!Array.prototype.reduceRight) {
    Array.prototype.reduceRight = function (fun /*, initial*/) {
        var self = toObject(this),
            length = self.length >>> 0;

        // If no callback function or if callback is not a callable function
        if (toString(fun) != "[object Function]") {
            throw new TypeError(); // TODO message
        }

        // no value to return if no initial value, empty array
        if (!length && arguments.length == 1)
            throw new TypeError(); // TODO message

        var result, i = length - 1;
        if (arguments.length >= 2) {
            result = arguments[1];
        } else {
            do {
                if (i in self) {
                    result = self[i--];
                    break;
                }

                // if array contains no values, no initial value to return
                if (--i < 0)
                    throw new TypeError(); // TODO message
            } while (true);
        }

        do {
            if (i in this)
                result = fun.call(void 0, result, self[i], i, self);
        } while (i--);

        return result;
    };
}

// ES5 15.4.4.14
// https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/Array/indexOf
if (!Array.prototype.indexOf) {
    Array.prototype.indexOf = function (sought /*, fromIndex */ ) {
        var self = toObject(this),
            length = self.length >>> 0;

        if (!length)
            return -1;

        var i = 0;
        if (arguments.length > 1)
            i = toInteger(arguments[1]);

        // handle negative indices
        i = i >= 0 ? i : length - Math.abs(i);
        for (; i < length; i++) {
            if (i in self && self[i] === sought) {
                return i;
            }
        }
        return -1;
    };
}

// ES5 15.4.4.15
if (!Array.prototype.lastIndexOf) {
    Array.prototype.lastIndexOf = function (sought /*, fromIndex */) {
        var self = toObject(this),
            length = self.length >>> 0;

        if (!length)
            return -1;
        var i = length - 1;
        if (arguments.length > 1)
            i = toInteger(arguments[1]);
        // handle negative indices
        i = i >= 0 ? i : length - Math.abs(i);
        for (; i >= 0; i--) {
            if (i in self && sought === self[i])
                return i;
        }
        return -1;
    };
}

//
// Array
// =====
//

// ES5 15.4.4.12
// http://es5.github.com/#x15.4.4.12
// Default value for second param
// [bugfix, ielt9, old browsers]
// IE < 9 bug: [1,2].splice(0).join("") == "" but should be "12"
if([1,2].splice(0).length != 2) {
    var _origArraySplice = Array.prototype.splice;

    Array.prototype.splice = function(start, deleteCount) {
        if(!arguments.length)return [];

        return _origArraySplice.apply(this, [
                start === void 0 ? 0 : start,
                deleteCount === void 0 ? (this.length - start) : deleteCount
            ].concat(slice.call(arguments, 2)))
    };
}

//
// Object
// ======
//


// ES5 15.2.3.14
// http://whattheheadsaid.com/2010/10/a-safer-object-keys-compatibility-implementation
if (!Object.keys) {

    var hasDontEnumBug = true,
        dontEnums = [
            "toString",
            "toLocaleString",
            "valueOf",
            "hasOwnProperty",
            "isPrototypeOf",
            "propertyIsEnumerable",
            "constructor"
        ],
        dontEnumsLength = dontEnums.length;

    for (var key in {"toString": null})
        hasDontEnumBug = false;

    Object.keys = function keys(object) {

        if ((typeof object != "object" && typeof object != "function") || object === null)
            throw new TypeError("Object.keys called on a non-object");

        var keys = [];
        for (var name in object) {
            if (owns(object, name)) {
                keys.push(name);
            }
        }

        if (hasDontEnumBug) {
            for (var i = 0, ii = dontEnumsLength; i < ii; i++) {
                var dontEnum = dontEnums[i];
                if (owns(object, dontEnum)) {
                    keys.push(dontEnum);
                }
            }
        }

        return keys;
    };

}

//
// Date
// ====
//

// ES5 15.9.5.43
// Format a Date object as a string according to a simplified subset of the ISO 8601
// standard as defined in 15.9.1.15.
if (!Date.prototype.toISOString) {
    Date.prototype.toISOString = function toISOString() {
        var result, length, value;
        if (!isFinite(this))
            throw new RangeError;

        // the date time string format is specified in 15.9.1.15.
        result = [this.getUTCFullYear(), this.getUTCMonth() + 1, this.getUTCDate(),
            this.getUTCHours(), this.getUTCMinutes(), this.getUTCSeconds()];

        length = result.length;
        while (length--) {
            value = result[length];
            // pad months, days, hours, minutes, and seconds to have two digits.
            if (value < 10)
                result[length] = "0" + value;
        }
        // pad milliseconds to have three digits.
        return result.slice(0, 3).join("-") + "T" + result.slice(3).join(":") + "." +
            ("000" + this.getUTCMilliseconds()).slice(-3) + "Z";
    }
}

// ES5 15.9.4.4
if (!Date.now) {
    Date.now = function now() {
        return new Date().getTime();
    };
}

// ES5 15.9.5.44
if (!Date.prototype.toJSON) {
    Date.prototype.toJSON = function toJSON(key) {
        // This function provides a String representation of a Date object for
        // use by JSON.stringify (15.12.3). When the toJSON method is called
        // with argument key, the following steps are taken:

        // 1.  Let O be the result of calling ToObject, giving it the this
        // value as its argument.
        // 2. Let tv be ToPrimitive(O, hint Number).
        // 3. If tv is a Number and is not finite, return null.
        // XXX
        // 4. Let toISO be the result of calling the [[Get]] internal method of
        // O with argument "toISOString".
        // 5. If IsCallable(toISO) is false, throw a TypeError exception.
        if (typeof this.toISOString != "function")
            throw new TypeError(); // TODO message
        // 6. Return the result of calling the [[Call]] internal method of
        // toISO with O as the this value and an empty argument list.
        return this.toISOString();

        // NOTE 1 The argument is ignored.

        // NOTE 2 The toJSON function is intentionally generic; it does not
        // require that its this value be a Date object. Therefore, it can be
        // transferred to other kinds of objects for use as a method. However,
        // it does require that any such object have a toISOString method. An
        // object is free to use the argument key to filter its
        // stringification.
    };
}


//
// String
// ======
//

// ES5 15.5.4.20
var ws = "\x09\x0A\x0B\x0C\x0D\x20\xA0\u1680\u180E\u2000\u2001\u2002\u2003" +
    "\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u202F\u205F\u3000\u2028" +
    "\u2029\uFEFF";
if (!String.prototype.trim || ws.trim()) {
    // http://blog.stevenlevithan.com/archives/faster-trim-javascript
    // http://perfectionkills.com/whitespace-deviations/
    ws = "[" + ws + "]";
    var trimBeginRegexp = new RegExp("^" + ws + ws + "*"),
        trimEndRegexp = new RegExp(ws + ws + "*$");
    String.prototype.trim = function trim() {
        return String(this).replace(trimBeginRegexp, "").replace(trimEndRegexp, "");
    };
}

// ES5 15.5.4.14
// http://es5.github.com/#x15.5.4.14
// [bugfix, chrome]
// If separator is undefined, then the result array contains just one String, which is the this value (converted to a String). If limit is not undefined, then the output array is truncated so that it contains no more than limit elements.
// "0".split(undefined, 0) -> []
if("0".split(void 0, 0).length) {
    var oldSplit = String.prototype.split;
    String.prototype.split = function(separator, limit) {
        if(separator === void 0 && limit === 0)return [];
        return oldSplit.apply(this, arguments);
    }
}

// ECMA-262, 3rd B.2.3
// Note an ECMAScript standart, although ECMAScript 3rd Edition has a non-normative section suggesting uniform semantics
// and it should be normalized across all browsers
// [bugfix, IE lt 9] IE < 9 substr() with negative value not working in IE
if("".substr && "0b".substr(-1) !== "b") {
    var oldSubstr = String.prototype.substr;
    /**
* Get the substring of a string
* @param {integer} start where to start the substring
* @param {integer} length how many characters to return
* @return {string}
*/
    String.prototype.substr = function(start, length) {
        return oldSubstr.call(this, start < 0 ? (start = this.length + start) < 0 ? 0 : start : start, length);
    }
}

//
// Util
// ======
//

// http://jsperf.com/to-integer
var toInteger = function (n) {
    n = +n;
    if (n !== n) // isNaN
        n = -1;
    else if (n !== 0 && n !== (1/0) && n !== -(1/0))
        n = (n > 0 || -1) * Math.floor(Math.abs(n));
    return n;
};

var prepareString = "a"[0] != "a",
    // ES5 9.9
    toObject = function (o) {
        if (o == null) { // this matches both null and undefined
            throw new TypeError(); // TODO message
        }
        // If the implementation doesn't support by-index access of
        // string characters (ex. IE < 7), split the string
        if (prepareString && typeof o == "string" && o) {
            return o.split("");
        }
        return Object(o);
    };

})();



(function($, shims){
	var defineProperty = 'defineProperty';
	var advancedObjectProperties = !!(Object.create && Object.defineProperties && Object.getOwnPropertyDescriptor);
	//safari5 has defineProperty-interface, but it can't be used on dom-object
	//only do this test in non-IE browsers, because this hurts dhtml-behavior in some IE8 versions
	if (advancedObjectProperties && !$.browser.msie && Object[defineProperty] && Object.prototype.__defineGetter__) {
		(function(){
			try {
				var foo = document.createElement('foo');
				Object[defineProperty](foo, 'bar', {
					get: function(){
						return true;
					}
				});
				advancedObjectProperties = !!foo.bar;
			} 
			catch (e) {
				advancedObjectProperties = false;
			}
			foo = null;
		})();
	}
	
	Modernizr.objectAccessor = !!((advancedObjectProperties || (Object.prototype.__defineGetter__ && Object.prototype.__lookupSetter__)) && (!$.browser.opera || shims.browserVersion >= 11));
	Modernizr.advancedObjectProperties = advancedObjectProperties;
	
if((!advancedObjectProperties || !Object.create || !Object.defineProperties || !Object.getOwnPropertyDescriptor  || !Object.defineProperty)){
	var call = Function.prototype.call;
	var prototypeOfObject = Object.prototype;
	var owns = call.bind(prototypeOfObject.hasOwnProperty);
	
	shims.objectCreate = function(proto, props, opts, no__proto__){
		var o;
		var f = function(){};
		
		f.prototype = proto;
		o = new f();
		
		if(!no__proto__ && !('__proto__' in o) && !Modernizr.objectAccessor){
			o.__proto__ = proto;
		}
		
		if(props){
			shims.defineProperties(o, props);
		}
		
		if(opts){
			o.options = jQuery.extend(true, {}, o.options || {}, opts);
			opts = o.options;
		}
		
		if(o._create && jQuery.isFunction(o._create)){
			o._create(opts);
		}
		return o;
	};
	
	shims.defineProperties = function(object, props){
		for (var name in props) {
			if (owns(props, name)) {
				shims.defineProperty(object, name, props[name]);
			}
		}
		return object;
	};
	
	var descProps = ['configurable', 'enumerable', 'writable'];
	shims.defineProperty = function(proto, property, descriptor){
		if(typeof descriptor != "object" || descriptor === null){return proto;}
		
		if(owns(descriptor, "value")){
			proto[property] = descriptor.value;
			return proto;
		}
		
		if(proto.__defineGetter__){
            if (typeof descriptor.get == "function") {
				proto.__defineGetter__(property, descriptor.get);
			}
            if (typeof descriptor.set == "function"){
                proto.__defineSetter__(property, descriptor.set);
			}
        }
		return proto;
	};
	
	shims.getPrototypeOf = function (object) {
        return Object.getPrototypeOf && Object.getPrototypeOf(object) || object.__proto__ || object.constructor && object.constructor.prototype;
    };
	
	//based on http://www.refactory.org/s/object_getownpropertydescriptor/view/latest 
	shims.getOwnPropertyDescriptor = function(obj, prop){
		if (typeof obj !== "object" && typeof obj !== "function" || obj === null){
            throw new TypeError("Object.getOwnPropertyDescriptor called on a non-object");
		}
		var descriptor;
		if(Object.defineProperty && Object.getOwnPropertyDescriptor){
			try{
				descriptor = Object.getOwnPropertyDescriptor(obj, prop);
				return descriptor;
			} catch(e){}
		}
        descriptor = {
            configurable: true,
            enumerable: true,
            writable: true,
            value: undefined
        };
		var getter = obj.__lookupGetter__ && obj.__lookupGetter__(prop), 
			setter = obj.__lookupSetter__ && obj.__lookupSetter__(prop)
		;
        
        if (!getter && !setter) { // not an accessor so return prop
        	if(!owns(obj, prop)){
				return;
			}
            descriptor.value = obj[prop];
            return descriptor;
        }
        
        // there is an accessor, remove descriptor.writable; populate descriptor.get and descriptor.set
        delete descriptor.writable;
        delete descriptor.value;
        descriptor.get = descriptor.set = undefined;
        
        if(getter){
			descriptor.get = getter;
		}
        
        if(setter){
            descriptor.set = setter;
		}
        
        return descriptor;
    };

}
})(jQuery, jQuery.webshims);



//DOM-Extension helper
jQuery.webshims.register('dom-extend', function($, webshims, window, document, undefined){
	"use strict";
	//shortcus
	var modules = webshims.modules;
	var listReg = /\s*,\s*/;
		
	//proxying attribute
	var olds = {};
	var havePolyfill = {};
	var extendedProps = {};
	var extendQ = {};
	var modifyProps = {};
	
	var oldVal = $.fn.val;
	var singleVal = function(elem, name, val, pass, _argless){
		return (_argless) ? oldVal.call($(elem)) : oldVal.call($(elem), val);
	};
	$.fn.val = function(val){
		var elem = this[0];
		if(arguments.length && val == null){
			val = '';
		}
		if(!arguments.length){
			if(!elem || elem.nodeType !== 1){return oldVal.call(this);}
			return $.prop(elem, 'value', val, 'val', true);
		}
		if($.isArray(val)){
			return oldVal.apply(this, arguments);
		}
		var isFunction = $.isFunction(val);
		return this.each(function(i){
			elem = this;
			if(elem.nodeType === 1){
				if(isFunction){
					var genVal = val.call( elem, i, $.prop(elem, 'value', undefined, 'val', true));
					if(genVal == null){
						genVal = '';
					}
					$.prop(elem, 'value', genVal, 'val') ;
				} else {
					$.prop(elem, 'value', val, 'val');
				}
			}
		});
	};
	
	var dataID = '_webshimsLib'+ (Math.round(Math.random() * 1000));
	var elementData = function(elem, key, val){
		elem = elem.jquery ? elem[0] : elem;
		if(!elem){return val || {};}
		var data = $.data(elem, dataID);
		if(val !== undefined){
			if(!data){
				data = $.data(elem, dataID, {});
			}
			if(key){
				data[key] = val;
			}
		}
		
		return key ? data && data[key] : data;
	};


	[{name: 'getNativeElement', prop: 'nativeElement'}, {name: 'getShadowElement', prop: 'shadowElement'}, {name: 'getShadowFocusElement', prop: 'shadowFocusElement'}].forEach(function(data){
		$.fn[data.name] = function(){
			return this.map(function(){
				var shadowData = elementData(this, 'shadowData');
				return shadowData && shadowData[data.prop] || this;
			});
		};
	});
	
	
	['removeAttr', 'prop', 'attr'].forEach(function(type){
		olds[type] = $[type];
		$[type] = function(elem, name, value, pass, _argless){
			var isVal = (pass == 'val');
			var oldMethod = !isVal ? olds[type] : singleVal;
			if( !elem || !havePolyfill[name] || elem.nodeType !== 1 || (!isVal && pass && type == 'attr' && $.attrFn[name]) ){
				return oldMethod(elem, name, value, pass, _argless);
			}
			
			var nodeName = (elem.nodeName || '').toLowerCase();
			var desc = extendedProps[nodeName];
			var curType = (type == 'attr' && (value === false || value === null)) ? 'removeAttr' : type;
			var propMethod;
			var oldValMethod;
			var ret;
			
			
			if(!desc){
				desc = extendedProps['*'];
			}
			if(desc){
				desc = desc[name];
			}
			
			if(desc){
				propMethod = desc[curType];
			}
			
			if(propMethod){
				if(name == 'value'){
					oldValMethod = propMethod.isVal;
					propMethod.isVal = isVal;
				}
				if(curType === 'removeAttr'){
					return propMethod.value.call(elem);	
				} else if(value === undefined){
					return (propMethod.get) ? 
						propMethod.get.call(elem) : 
						propMethod.value
					;
				} else if(propMethod.set) {
					if(type == 'attr' && value === true){
						value = name;
					}
					
					ret = propMethod.set.call(elem, value);
				}
				if(name == 'value'){
					propMethod.isVal = oldValMethod;
				}
			} else {
				ret = oldMethod(elem, name, value, pass, _argless);
			}
			if((value !== undefined || curType === 'removeAttr') && modifyProps[nodeName] && modifyProps[nodeName][name]){
				
				var boolValue;
				if(curType == 'removeAttr'){
					boolValue = false;
				} else if(curType == 'prop'){
					boolValue = !!(value);
				} else {
					boolValue = true;
				}
				
				modifyProps[nodeName][name].forEach(function(fn){
					if(!fn.only || (fn.only = 'prop' && type == 'prop') || (fn.only == 'attr' && type != 'prop')){
						fn.call(elem, value, boolValue, (isVal) ? 'val' : curType, type);
					}
				});
			}
			return ret;
		};
		
		extendQ[type] = function(nodeName, prop, desc){
			
			if(!extendedProps[nodeName]){
				extendedProps[nodeName] = {};
			}
			if(!extendedProps[nodeName][prop]){
				extendedProps[nodeName][prop] = {};
			}
			var oldDesc = extendedProps[nodeName][prop][type];
			var getSup = function(propType, descriptor, oDesc){
				if(descriptor && descriptor[propType]){
					return descriptor[propType];
				}
				if(oDesc && oDesc[propType]){
					return oDesc[propType];
				}
				if(type == 'prop' && prop == 'value'){
					return function(value){
						var elem = this;
						return (desc.isVal) ? 
							singleVal(elem, prop, value, false, (arguments.length === 0)) : 
							olds[type](elem, prop, value)
						;
					};
				}
				if(type == 'prop' && propType == 'value' && desc.value.apply){
					return  function(value){
						var sup = olds[type](this, prop);
						if(sup && sup.apply){
							sup = sup.apply(this, arguments);
						} 
						return sup;
					};
				}
				return function(value){
					return olds[type](this, prop, value);
				};
			};
			extendedProps[nodeName][prop][type] = desc;
			if(desc.value === undefined){
				if(!desc.set){
					desc.set = desc.writeable ? 
						getSup('set', desc, oldDesc) : 
						(webshims.cfg.useStrict && prop == 'prop') ? 
							function(){throw(prop +' is readonly on '+ nodeName);} : 
							$.noop
					;
				}
				if(!desc.get){
					desc.get = getSup('get', desc, oldDesc);
				}
				
			}
			
			['value', 'get', 'set'].forEach(function(descProp){
				if(desc[descProp]){
					desc['_sup'+descProp] = getSup(descProp, oldDesc);
				}
			});
		};
		
	});
	
	//see also: https://github.com/lojjic/PIE/issues/40 | https://prototype.lighthouseapp.com/projects/8886/tickets/1107-ie8-fatal-crash-when-prototypejs-is-loaded-with-rounded-cornershtc
	var isExtendNativeSave = (!$.browser.msie || parseInt($.browser.version, 10) > 8);
	var extendNativeValue = (function(){
		var UNKNOWN = webshims.getPrototypeOf(document.createElement('foobar'));
		var has = Object.prototype.hasOwnProperty;
		return function(nodeName, prop, desc){
			var elem = document.createElement(nodeName);
			var elemProto = webshims.getPrototypeOf(elem);
			if( isExtendNativeSave && elemProto && UNKNOWN !== elemProto && ( !elem[prop] || !has.call(elem, prop) ) ){
				var sup = elem[prop];
				desc._supvalue = function(){
					if(sup && sup.apply){
						return sup.apply(this, arguments);
					}
					return sup;
				};
				elemProto[prop] = desc.value;
			} else {
				desc._supvalue = function(){
					var data = elementData(this, 'propValue');
					if(data && data[prop] && data[prop].apply){
						return data[prop].apply(this, arguments);
					}
					return data && data[prop];
				};
				initProp.extendValue(nodeName, prop, desc.value);
			}
			desc.value._supvalue = desc._supvalue;
		};
	})();
		
	var initProp = (function(){
		
		var initProps = {};
		
		webshims.addReady(function(context, contextElem){
			var nodeNameCache = {};
			var getElementsByName = function(name){
				if(!nodeNameCache[name]){
					nodeNameCache[name] = $(context.getElementsByTagName(name));
					if(contextElem[0] && $.nodeName(contextElem[0], name)){
						nodeNameCache[name] = nodeNameCache[name].add(contextElem);
					}
				}
			};
			
			
			$.each(initProps, function(name, fns){
				getElementsByName(name);
				if(!fns || !fns.forEach){
					webshims.warn('Error: with '+ name +'-property. methods: '+ fns);
					return;
				}
				fns.forEach(function(fn){
					nodeNameCache[name].each(fn);
				});
			});
			nodeNameCache = null;
		});
		
		var tempCache;
		var emptyQ = $([]);
		var createNodeNameInit = function(nodeName, fn){
			if(!initProps[nodeName]){
				initProps[nodeName] = [fn];
			} else {
				initProps[nodeName].push(fn);
			}
			if($.isDOMReady){
				(tempCache || $( document.getElementsByTagName(nodeName) )).each(fn);
			}
		};
		
		var elementExtends = {};
		return {
			createTmpCache: function(nodeName){
				if($.isDOMReady){
					tempCache = tempCache || $( document.getElementsByTagName(nodeName) );
				}
				return tempCache || emptyQ;
			},
			flushTmpCache: function(){
				tempCache = null;
			},
			content: function(nodeName, prop){
				createNodeNameInit(nodeName, function(){
					var val =  $.attr(this, prop);
					if(val != null){
						$.attr(this, prop, val);
					}
				});
			},
			createElement: function(nodeName, fn){
				createNodeNameInit(nodeName, fn);
			},
			extendValue: function(nodeName, prop, value){
				createNodeNameInit(nodeName, function(){
					$(this).each(function(){
						var data = elementData(this, 'propValue', {});
						data[prop] = this[prop];
						this[prop] = value;
					});
				});
			}
		};
	})();
		
	var createPropDefault = function(descs, removeType){
		if(descs.defaultValue === undefined){
			descs.defaultValue = '';
		}
		if(!descs.removeAttr){
			descs.removeAttr = {
				value: function(){
					descs[removeType || 'prop'].set.call(this, descs.defaultValue);
					descs.removeAttr._supvalue.call(this);
				}
			};
		}
		if(!descs.attr){
			descs.attr = {};
		}
	};
	
	$.extend(webshims, {

		getID: (function(){
			var ID = new Date().getTime();
			return function(elem){
				elem = $(elem);
				var id = elem.attr('id');
				if(!id){
					ID++;
					id = 'ID-'+ ID;
					elem.attr('id', id);
				}
				return id;
			};
		})(),
		extendUNDEFProp: function(obj, props){
			$.each(props, function(name, prop){
				if( !(name in obj) ){
					obj[name] = prop;
				}
			});
		},
		//http://www.w3.org/TR/html5/common-dom-interfaces.html#reflect
		createPropDefault: createPropDefault,
		data: elementData,
		moveToFirstEvent: function(elem, eventType, bindType){
			var events = ($._data(elem, 'events') || {})[eventType];
			var fn;
			
			if(events && events.length > 1){
				fn = events.pop();
				if(!bindType){
					bindType = 'bind';
				}
				if(bindType == 'bind' && events.delegateCount){
					events.splice( events.delegateCount, 0, fn);
				} else {
					events.unshift( fn );
				}
				
				
			}
			elem = null;
		},
		addShadowDom: (function(){
			var resizeTimer;
			var lastHeight;
			var lastWidth;
			
			var docObserve = {
				init: false,
				runs: 0,
				test: function(){
					var height = docObserve.getHeight();
					var width = docObserve.getWidth();
					
					if(height != docObserve.height || width != docObserve.width){
						docObserve.height = height;
						docObserve.width = width;
						docObserve.handler({type: 'docresize'});
						docObserve.runs++;
						if(docObserve.runs < 9){
							setTimeout(docObserve.test, 90);
						}
					} else {
						docObserve.runs = 0;
					}
				},
				handler: function(e){
					clearTimeout(resizeTimer);
					resizeTimer = setTimeout(function(){
						if(e.type == 'resize'){
							var width = $(window).width();
							var height = $(window).width();
							if(height == lastHeight && width == lastWidth){
								return;
							}
							lastHeight = height;
							lastWidth = width;
							
							docObserve.height = docObserve.getHeight();
							docObserve.width = docObserve.getWidth();
							
						}
						$.event.trigger('updateshadowdom');
					}, (e.type == 'resize') ? 50 : 9);
				},
				_create: function(){
					$.each({ Height: "getHeight", Width: "getWidth" }, function(name, type){
						var body = document.body;
						var doc = document.documentElement;
						docObserve[type] = function(){
							return Math.max(
								body[ "scroll" + name ], doc[ "scroll" + name ],
								body[ "offset" + name ], doc[ "offset" + name ],
								doc[ "client" + name ]
							);
						};
					});
				},
				start: function(){
					if(!this.init && document.body){
						this.init = true;
						this._create();
						this.height = docObserve.getHeight();
						this.width = docObserve.getWidth();
						setInterval(this.test, 600);
						$(this.test);
						webshims.ready('WINDOWLOAD', this.test);
						$(window).bind('resize', this.handler);
						(function(){
							var oldAnimate = $.fn.animate;
							var animationTimer;
							
							$.fn.animate = function(){
								clearTimeout(animationTimer);
								animationTimer = setTimeout(function(){
									docObserve.test();
								}, 99);
								
								return oldAnimate.apply(this, arguments);
							};
						})();
					}
				}
			};
			
			
			$.event.customEvent.updateshadowdom = true;
			webshims.docObserve = function(){
				webshims.ready('DOM', function(){
					docObserve.start();
				});
			};
			return function(nativeElem, shadowElem, opts){
				opts = opts || {};
				if(nativeElem.jquery){
					nativeElem = nativeElem[0];
				}
				if(shadowElem.jquery){
					shadowElem = shadowElem[0];
				}
				var nativeData = $.data(nativeElem, dataID) || $.data(nativeElem, dataID, {});
				var shadowData = $.data(shadowElem, dataID) || $.data(shadowElem, dataID, {});
				var shadowFocusElementData = {};
				if(!opts.shadowFocusElement){
					opts.shadowFocusElement = shadowElem;
				} else if(opts.shadowFocusElement){
					if(opts.shadowFocusElement.jquery){
						opts.shadowFocusElement = opts.shadowFocusElement[0];
					}
					shadowFocusElementData = $.data(opts.shadowFocusElement, dataID) || $.data(opts.shadowFocusElement, dataID, shadowFocusElementData);
				}
				
				nativeData.hasShadow = shadowElem;
				shadowFocusElementData.nativeElement = shadowData.nativeElement = nativeElem;
				shadowFocusElementData.shadowData = shadowData.shadowData = nativeData.shadowData = {
					nativeElement: nativeElem,
					shadowElement: shadowElem,
					shadowFocusElement: opts.shadowFocusElement
				};
				if(opts.shadowChilds){
					opts.shadowChilds.each(function(){
						elementData(this, 'shadowData', shadowData.shadowData);
					});
				}
				
				if(opts.data){
					shadowFocusElementData.shadowData.data = shadowData.shadowData.data = nativeData.shadowData.data = opts.data;
				}
				opts = null;
				webshims.docObserve();
			};
		})(),
		propTypes: {
			standard: function(descs, name){
				createPropDefault(descs);
				if(descs.prop){return;}
				descs.prop = {
					set: function(val){
						descs.attr.set.call(this, ''+val);
					},
					get: function(){
						return descs.attr.get.call(this) || descs.defaultValue;
					}
				};
				
			},
			"boolean": function(descs, name){
				
				createPropDefault(descs);
				if(descs.prop){return;}
				descs.prop = {
					set: function(val){
						if(val){
							descs.attr.set.call(this, "");
						} else {
							descs.removeAttr.value.call(this);
						}
					},
					get: function(){
						return descs.attr.get.call(this) != null;
					}
				};
			},
			"src": (function(){
				var anchor = document.createElement('a');
				anchor.style.display = "none";
				return function(descs, name){
					
					createPropDefault(descs);
					if(descs.prop){return;}
					descs.prop = {
						set: function(val){
							descs.attr.set.call(this, val);
						},
						get: function(){
							var href = this.getAttribute(name);
							var ret;
							if(href == null){return '';}
							
							anchor.setAttribute('href', href+'' );
							
							if(!$.support.hrefNormalized){
								try {
									$(anchor).insertAfter(this);
									ret = anchor.getAttribute('href', 4);
								} catch(er){
									ret = anchor.getAttribute('href', 4);
								}
								$(anchor).detach();
							}
							return ret || anchor.href;
						}
					};
				};
			})(),
			enumarated: function(descs, name){
					
					createPropDefault(descs);
					if(descs.prop){return;}
					descs.prop = {
						set: function(val){
							descs.attr.set.call(this, val);
						},
						get: function(){
							var val = (descs.attr.get.call(this) || '').toLowerCase();
							if(!val || descs.limitedTo.indexOf(val) == -1){
								val = descs.defaultValue;
							}
							return val;
						}
					};
				}
			
//			,unsignedLong: $.noop
//			,"doubble": $.noop
//			,"long": $.noop
//			,tokenlist: $.noop
//			,settableTokenlist: $.noop
		},
		reflectProperties: function(nodeNames, props){
			if(typeof props == 'string'){
				props = props.split(listReg);
			}
			props.forEach(function(prop){
				webshims.defineNodeNamesProperty(nodeNames, prop, {
					prop: {
						set: function(val){
							$.attr(this, prop, val);
						},
						get: function(){
							return $.attr(this, prop) || '';
						}
					}
				});
			});
		},
		defineNodeNameProperty: function(nodeName, prop, descs){
			havePolyfill[prop] = true;
						
			if(descs.reflect){
				webshims.propTypes[descs.propType || 'standard'](descs, prop);
			}
			
			['prop', 'attr', 'removeAttr'].forEach(function(type){
				var desc = descs[type];
				if(desc){
					if(type === 'prop'){
						desc = $.extend({writeable: true}, desc);
					} else {
						desc = $.extend({}, desc, {writeable: true});
					}
						
					extendQ[type](nodeName, prop, desc);
					if(nodeName != '*' && webshims.cfg.extendNative && type == 'prop' && desc.value && $.isFunction(desc.value)){
						extendNativeValue(nodeName, prop, desc);
					}
					descs[type] = desc;
				}
			});
			if(descs.initAttr){
				initProp.content(nodeName, prop);
			}
			return descs;
		},
		
		defineNodeNameProperties: function(name, descs, propType, _noTmpCache){
			var olddesc;
			for(var prop in descs){
				if(!_noTmpCache && descs[prop].initAttr){
					initProp.createTmpCache(name);
				}
				if(propType){
					if(descs[prop][propType]){
						//webshims.log('override: '+ name +'['+prop +'] for '+ propType);
					} else {
						descs[prop][propType] = {};
						['value', 'set', 'get'].forEach(function(copyProp){
							if(copyProp in descs[prop]){
								descs[prop][propType][copyProp] = descs[prop][copyProp];
								delete descs[prop][copyProp];
							}
						});
					}
				}
				descs[prop] = webshims.defineNodeNameProperty(name, prop, descs[prop]);
			}
			if(!_noTmpCache){
				initProp.flushTmpCache();
			}
			return descs;
		},
		
		createElement: function(nodeName, create, descs){
			var ret;
			if($.isFunction(create)){
				create = {
					after: create
				};
			}
			initProp.createTmpCache(nodeName);
			if(create.before){
				initProp.createElement(nodeName, create.before);
			}
			if(descs){
				ret = webshims.defineNodeNameProperties(nodeName, descs, false, true);
			}
			if(create.after){
				initProp.createElement(nodeName, create.after);
			}
			initProp.flushTmpCache();
			return ret;
		},
		onNodeNamesPropertyModify: function(nodeNames, props, desc, only){
			if(typeof nodeNames == 'string'){
				nodeNames = nodeNames.split(listReg);
			}
			if($.isFunction(desc)){
				desc = {set: desc};
			}
			
			nodeNames.forEach(function(name){
				if(!modifyProps[name]){
					modifyProps[name] = {};
				}
				if(typeof props == 'string'){
					props = props.split(listReg);
				}
				if(desc.initAttr){
					initProp.createTmpCache(name);
				}
				props.forEach(function(prop){
					if(!modifyProps[name][prop]){
						modifyProps[name][prop] = [];
						havePolyfill[prop] = true;
					}
					if(desc.set){
						if(only){
							desc.set.only =  only;
						}
						modifyProps[name][prop].push(desc.set);
					}
					
					if(desc.initAttr){
						initProp.content(name, prop);
					}
				});
				initProp.flushTmpCache();
				
			});
		},
		defineNodeNamesBooleanProperty: function(elementNames, prop, descs){
			if(!descs){
				descs = {};
			}
			if($.isFunction(descs)){
				descs.set = descs;
			}
			webshims.defineNodeNamesProperty(elementNames, prop, {
				attr: {
					set: function(val){
						this.setAttribute(prop, val);
						if(descs.set){
							descs.set.call(this, true);
						}
					},
					get: function(){
						var ret = this.getAttribute(prop);
						return (ret == null) ? undefined : prop;
					}
				},
				removeAttr: {
					value: function(){
						this.removeAttribute(prop);
						if(descs.set){
							descs.set.call(this, false);
						}
					}
				},
				reflect: true,
				propType: 'boolean',
				initAttr: descs.initAttr || false
			});
		},
		contentAttr: function(elem, name, val){
			if(!elem.nodeName){return;}
			var attr;
			if(val === undefined){
				attr = (elem.attributes[name] || {});
				val = attr.specified ? attr.value : null;
				return (val == null) ? undefined : val;
			}
			
			if(typeof val == 'boolean'){
				if(!val){
					elem.removeAttribute(name);
				} else {
					elem.setAttribute(name, name);
				}
			} else {
				elem.setAttribute(name, val);
			}
		},
		
//		set current Lang:
//			- webshims.activeLang(lang:string);
//		get current lang
//			- webshims.activeLang();
//		get current lang
//			webshims.activeLang({
//				register: moduleName:string,
//				callback: callback:function
//			});
//		get/set including removeLang
//			- webshims.activeLang({
//				module: moduleName:string,
//				callback: callback:function,
//				langObj: languageObj:array/object
//			});
		activeLang: (function(){
			var callbacks = [];
			var registeredCallbacks = {};
			var currentLang;
			var shortLang;
			var notLocal = /:\/\/|^\.*\//;
			var loadRemoteLang = function(data, lang, options){
				var langSrc;
				if(lang && options && $.inArray(lang, options.availabeLangs || []) !== -1){
					data.loading = true;
					langSrc = options.langSrc;
					if(!notLocal.test(langSrc)){
						langSrc = webshims.cfg.basePath+langSrc;
					}
					webshims.loader.loadScript(langSrc+lang+'.js', function(){
						if(data.langObj[lang]){
							data.loading = false;
							callLang(data, true);
						} else {
							$(function(){
								if(data.langObj[lang]){
									callLang(data, true);
								}
								data.loading = false;
							});
						}
					});
					return true;
				}
				return false;
			};
			var callRegister = function(module){
				if(registeredCallbacks[module]){
					registeredCallbacks[module].forEach(function(data){
						data.callback();
					});
				}
			};
			var callLang = function(data, _noLoop){
				if(data.activeLang != currentLang && data.activeLang !== shortLang){
					var options = modules[data.module].options;
					if( data.langObj[currentLang] || (shortLang && data.langObj[shortLang]) ){
						data.activeLang = currentLang;
						data.callback(data.langObj[currentLang] || data.langObj[shortLang], currentLang);
						callRegister(data.module);
					} else if( !_noLoop &&
						!loadRemoteLang(data, currentLang, options) && 
						!loadRemoteLang(data, shortLang, options) && 
						data.langObj[''] && data.activeLang !== '' ) {
						data.activeLang = '';
						data.callback(data.langObj[''], currentLang);
						callRegister(data.module);
					}
				}
			};
			
			
			var activeLang = function(lang){
				
				if(typeof lang == 'string' && lang !== currentLang){
					currentLang = lang;
					shortLang = currentLang.split('-')[0];
					if(currentLang == shortLang){
						shortLang = false;
					}
					$.each(callbacks, function(i, data){
						callLang(data);
					});
				} else if(typeof lang == 'object'){
					
					if(lang.register){
						if(!registeredCallbacks[lang.register]){
							registeredCallbacks[lang.register] = [];
						}
						registeredCallbacks[lang.register].push(lang);
						lang.callback();
					} else {
						if(!lang.activeLang){
							lang.activeLang = '';
						}
						callbacks.push(lang);
						callLang(lang);
					}
				}
				return currentLang;
			};
			
			return activeLang;
		})()
	});
	
	$.each({
		defineNodeNamesProperty: 'defineNodeNameProperty',
		defineNodeNamesProperties: 'defineNodeNameProperties',
		createElements: 'createElement'
	}, function(name, baseMethod){
		webshims[name] = function(names, a, b, c){
			if(typeof names == 'string'){
				names = names.split(listReg);
			}
			var retDesc = {};
			names.forEach(function(nodeName){
				retDesc[nodeName] = webshims[baseMethod](nodeName, a, b, c);
			});
			return retDesc;
		};
	});
	
	webshims.isReady('webshimLocalization', true);
});
//html5a11y
(function($, document){
	var browserVersion = $.webshims.browserVersion;
	if($.browser.mozilla && browserVersion > 5){return;}
	if (!$.browser.msie || (browserVersion < 12 && browserVersion > 7)) {
		var elemMappings = {
			article: "article",
			aside: "complementary",
			section: "region",
			nav: "navigation",
			address: "contentinfo"
		};
		var addRole = function(elem, role){
			var hasRole = elem.getAttribute('role');
			if (!hasRole) {
				elem.setAttribute('role', role);
			}
		};
		
		$.webshims.addReady(function(context, contextElem){
			$.each(elemMappings, function(name, role){
				var elems = $(name, context).add(contextElem.filter(name));
				for (var i = 0, len = elems.length; i < len; i++) {
					addRole(elems[i], role);
				}
			});
			if (context === document) {
				var header = document.getElementsByTagName('header')[0];
				var footers = document.getElementsByTagName('footer');
				var footerLen = footers.length;
				if (header && !$(header).closest('section, article')[0]) {
					addRole(header, 'banner');
				}
				if (!footerLen) {
					return;
				}
				var footer = footers[footerLen - 1];
				if (!$(footer).closest('section, article')[0]) {
					addRole(footer, 'contentinfo');
				}
			}
		});
	}
})(jQuery, document);

(function($, Modernizr, webshims){
	"use strict";
	var hasNative = Modernizr.audio && Modernizr.video;
	var supportsLoop = false;
	var bugs = webshims.bugs;
	
	var loadSwf = function(){
		webshims.ready(swfType, function(){
			if(!webshims.mediaelement.createSWF){
				webshims.mediaelement.loadSwf = true;
				webshims.reTest([swfType], hasNative);
			}
		});
	};
	var options = webshims.cfg.mediaelement;
	var swfType = options && options.player == 'jwplayer' ? 'mediaelement-swf' : 'mediaelement-jaris';
	var hasSwf;
	if(!options){
		webshims.error("mediaelement wasn't implemented but loaded");
		return;
	}
	if(hasNative){
		var videoElem = document.createElement('video');
		Modernizr.videoBuffered = ('buffered' in videoElem);
		supportsLoop = ('loop' in videoElem);
		
		webshims.capturingEvents(['play', 'playing', 'waiting', 'paused', 'ended', 'durationchange', 'loadedmetadata', 'canplay', 'volumechange']);
		
		if(!Modernizr.videoBuffered){
			webshims.addPolyfill('mediaelement-native-fix', {
				f: 'mediaelement',
				test: Modernizr.videoBuffered,
				d: ['dom-support']
			});
			
			webshims.reTest('mediaelement-native-fix');
		}
	}
	
	if(hasNative && !options.preferFlash){
		var switchOptions = function(e){
			var parent = e.target.parentNode;
			if(!options.preferFlash && ($(e.target).is('audio, video') || (parent && $('source:last', parent)[0] == e.target)) ){
				webshims.ready('DOM mediaelement', function(){
					if(hasSwf){
						loadSwf();
					}
					webshims.ready('WINDOWLOAD '+swfType, function(){
						setTimeout(function(){
							if(hasSwf && !options.preferFlash && webshims.mediaelement.createSWF && !$(e.target).closest('audio, video').is('.nonnative-api-active')){
								options.preferFlash = true;
								document.removeEventListener('error', switchOptions, true);
								$('audio, video').mediaLoad();
								webshims.info("switching mediaelements option to 'preferFlash', due to an error with native player: "+e.target.src);
							} else if(!hasSwf){
								document.removeEventListener('error', switchOptions, true);
							}
						}, 20);
					});
				});
			}
		};
		document.addEventListener('error', switchOptions, true);
		$('audio, video').each(function(){
			if(this.error){
				switchOptions({target: this});
			}
		});
	}
	
	
	if(Modernizr.track && !bugs.track){
		(function(){
			
			if(!bugs.track){
				bugs.track = typeof $('<track />')[0].readyState != 'number';
			}
			
			if(!bugs.track){
				try {
					new TextTrackCue(2, 3, '');
				} catch(e){
					bugs.track = true;
				}
			}
			
			var trackOptions = webshims.cfg.track;
			var trackListener = function(e){
				$(e.target).filter('track').each(changeApi);
			};
			var changeApi = function(){
				if(bugs.track || (!trackOptions.override && $.prop(this, 'readyState') == 3)){
					trackOptions.override = true;
					webshims.reTest('track');
					document.removeEventListener('error', trackListener, true);
					if(this && $.nodeName(this, 'track')){
						webshims.error("track support was overwritten. Please check your vtt including your vtt mime-type");
					} else {
						webshims.info("track support was overwritten. due to bad browser support");
					}
				}
			};
			var detectTrackError = function(){
				document.addEventListener('error', trackListener, true);
				
				if(bugs.track){
					changeApi();
				} else {
					$('track').each(changeApi);
				}
			};
			if(!trackOptions.override){
				if(webshims.isReady('track')){
					detectTrackError();
				} else {
					$(detectTrackError);
				}
			}
		})();
		
	}

webshims.register('mediaelement-core', function($, webshims, window, document, undefined){
	hasSwf = swfobject.hasFlashPlayerVersion('9.0.115');
	$('html').addClass(hasSwf ? 'swf' : 'no-swf');
	var mediaelement = webshims.mediaelement;
	mediaelement.parseRtmp = function(data){
		var src = data.src.split('://');
		var paths = src[1].split('/');
		var i, len, found;
		data.server = src[0]+'://'+paths[0]+'/';
		data.streamId = [];
		for(i = 1, len = paths.length; i < len; i++){
			if(!found && paths[i].indexOf(':') !== -1){
				paths[i] = paths[i].split(':')[1];
				found = true;
			}
			if(!found){
				data.server += paths[i]+'/';
			} else {
				data.streamId.push(paths[i]);
			}
		}
		if(!data.streamId.length){
			webshims.error('Could not parse rtmp url');
		}
		data.streamId = data.streamId.join('/');
		console.log(data)
	};
	var getSrcObj = function(elem, nodeName){
		elem = $(elem);
		var src = {src: elem.attr('src') || '', elem: elem, srcProp: elem.prop('src')};
		var tmp;
		
		if(!src.src){return src;}
		
		tmp = elem.attr('data-server');
		if(tmp != null){
			src.server = tmp;
		}
		
		tmp = elem.attr('type');
		if(tmp){
			src.type = tmp;
			src.container = $.trim(tmp.split(';')[0]);
		} else {
			if(!nodeName){
				nodeName = elem[0].nodeName.toLowerCase();
				if(nodeName == 'source'){
					nodeName = (elem.closest('video, audio')[0] || {nodeName: 'video'}).nodeName.toLowerCase();
				}
			}
			if(src.server){
				src.type = nodeName+'/rtmp';
				src.container = nodeName+'/rtmp';
			} else {
				
				tmp = mediaelement.getTypeForSrc( src.src, nodeName, src );
				
				if(tmp){
					src.type = tmp;
					src.container = tmp;
				}
			}
		}
		tmp = elem.attr('media');
		if(tmp){
			src.media = tmp;
		}
		if(src.type == 'audio/rtmp' || src.type == 'video/rtmp'){
			if(src.server){
				src.streamId = src.src;
			} else {
				mediaelement.parseRtmp(src);
			}
		}
		return src;
	};
	
	
	
	var hasYt = !hasSwf && ('postMessage' in window) && hasNative;
	
	var loadTrackUi = function(){
		if(loadTrackUi.loaded){return;}
		loadTrackUi.loaded = true;
		$(function(){
			webshims.loader.loadList(['track-ui']);
		});
	};
	var loadYt = (function(){
		var loaded;
		return function(){
			if(loaded || !hasYt){return;}
			loaded = true;
			webshims.loader.loadScript("https://www.youtube.com/player_api");
			$(function(){
				webshims.polyfill("mediaelement-yt");
			});
		};
	})();
	var loadThird = function(){
		if(hasSwf){
			loadSwf();
		} else {
			loadYt();
		}
	};
	
	webshims.addPolyfill('mediaelement-yt', {
		test: !hasYt,
		d: ['dom-support']
	});
	
	mediaelement.mimeTypes = {
		audio: {
				//ogm shouldn´t be used!
				'audio/ogg': ['ogg','oga', 'ogm'],
				'audio/ogg;codecs="opus"': 'opus',
				'audio/mpeg': ['mp2','mp3','mpga','mpega'],
				'audio/mp4': ['mp4','mpg4', 'm4r', 'm4a', 'm4p', 'm4b', 'aac'],
				'audio/wav': ['wav'],
				'audio/3gpp': ['3gp','3gpp'],
				'audio/webm': ['webm'],
				'audio/fla': ['flv', 'f4a', 'fla'],
				'application/x-mpegURL': ['m3u8', 'm3u']
			},
			video: {
				//ogm shouldn´t be used!
				'video/ogg': ['ogg','ogv', 'ogm'],
				'video/mpeg': ['mpg','mpeg','mpe'],
				'video/mp4': ['mp4','mpg4', 'm4v'],
				'video/quicktime': ['mov','qt'],
				'video/x-msvideo': ['avi'],
				'video/x-ms-asf': ['asf', 'asx'],
				'video/flv': ['flv', 'f4v'],
				'video/3gpp': ['3gp','3gpp'],
				'video/webm': ['webm'],
				'application/x-mpegURL': ['m3u8', 'm3u'],
				'video/MP2T': ['ts']
			}
		}
	;
	
	mediaelement.mimeTypes.source =  $.extend({}, mediaelement.mimeTypes.audio, mediaelement.mimeTypes.video);
	
	mediaelement.getTypeForSrc = function(src, nodeName, data){
		if(src.indexOf('youtube.com/watch?') != -1 || src.indexOf('youtube.com/v/') != -1){
			return 'video/youtube';
		}
		if(src.indexOf('rtmp') === 0){
			return nodeName+'/rtmp';
		}
		src = src.split('?')[0].split('.');
		src = src[src.length - 1];
		var mt;
		
		$.each(mediaelement.mimeTypes[nodeName], function(mimeType, exts){
			if(exts.indexOf(src) !== -1){
				mt = mimeType;
				return false;
			}
		});
		return mt;
	};
	
	
	mediaelement.srces = function(mediaElem, srces){
		mediaElem = $(mediaElem);
		if(!srces){
			srces = [];
			var nodeName = mediaElem[0].nodeName.toLowerCase();
			var src = getSrcObj(mediaElem, nodeName);
			
			if(!src.src){
				
				$('source', mediaElem).each(function(){
					src = getSrcObj(this, nodeName);
					if(src.src){srces.push(src);}
				});
			} else {
				srces.push(src);
			}
			return srces;
		} else {
			mediaElem.removeAttr('src').removeAttr('type').find('source').remove();
			if(!$.isArray(srces)){
				srces = [srces]; 
			}
			srces.forEach(function(src){
				var source = document.createElement('source');
				if(typeof src == 'string'){
					src = {src: src};
				} 
				source.setAttribute('src', src.src);
				if(src.type){
					source.setAttribute('type', src.type);
				}
				if(src.media){
					source.setAttribute('media', src.media);
				}
				mediaElem.append(source);
			});
			
		}
	};
	
	
	$.fn.loadMediaSrc = function(srces, poster){
		return this.each(function(){
			if(poster !== undefined){
				$(this).removeAttr('poster');
				if(poster){
					$.attr(this, 'poster', poster);
				}
			}
			mediaelement.srces(this, srces);
			$(this).mediaLoad();
		});
	};
	
	mediaelement.swfMimeTypes = ['video/3gpp', 'video/x-msvideo', 'video/quicktime', 'video/x-m4v', 'video/mp4', 'video/m4p', 'video/x-flv', 'video/flv', 'audio/mpeg', 'audio/aac', 'audio/mp4', 'audio/x-m4a', 'audio/m4a', 'audio/mp3', 'audio/x-fla', 'audio/fla', 'youtube/flv', 'jwplayer/jwplayer', 'video/youtube', 'video/rtmp', 'audio/rtmp'];
	
	mediaelement.canThirdPlaySrces = function(mediaElem, srces){
		var ret = '';
		if(hasSwf || hasYt){
			mediaElem = $(mediaElem);
			srces = srces || mediaelement.srces(mediaElem);
			$.each(srces, function(i, src){
				if(src.container && src.src && ((hasSwf && mediaelement.swfMimeTypes.indexOf(src.container) != -1) || (hasYt && src.container == 'video/youtube'))){
					ret = src;
					return false;
				}
			});
			
		}
		
		return ret;
	};
	
	var nativeCanPlayType = {};
	mediaelement.canNativePlaySrces = function(mediaElem, srces){
		var ret = '';
		if(hasNative){
			mediaElem = $(mediaElem);
			var nodeName = (mediaElem[0].nodeName || '').toLowerCase();
			if(!nativeCanPlayType[nodeName]){return ret;}
			srces = srces || mediaelement.srces(mediaElem);
			
			$.each(srces, function(i, src){
				if(src.type && nativeCanPlayType[nodeName].prop._supvalue.call(mediaElem[0], src.type) ){
					ret = src;
					return false;
				}
			});
		}
		return ret;
	};
	
	mediaelement.setError = function(elem, message){
		if(!message){
			message = "can't play sources";
		}
		
		$(elem).pause().data('mediaerror', message);
		webshims.warn('mediaelementError: '+ message);
		setTimeout(function(){
			if($(elem).data('mediaerror')){
				$(elem).trigger('mediaerror');
			}
		}, 1);
	};
	
	var handleThird = (function(){
		var requested;
		return function( mediaElem, ret, data ){
			if(!requested){
				loadTrackUi();
			}
			webshims.ready(hasSwf ? swfType : 'mediaelement-yt', function(){
				if(mediaelement.createSWF){
					mediaelement.createSWF( mediaElem, ret, data );
				} else if(!requested) {
					requested = true;
					loadThird();
					//readd to ready
					handleThird( mediaElem, ret, data );
				}
			});
			if(!requested && hasYt && !mediaelement.createSWF){
				loadYt();
			}
		};
	})();
	
	var stepSources = function(elem, data, useSwf, _srces, _noLoop){
		var ret;
		if(useSwf || (useSwf !== false && data && data.isActive == 'third')){
			ret = mediaelement.canThirdPlaySrces(elem, _srces);
			if(!ret){
				if(_noLoop){
					mediaelement.setError(elem, false);
				} else {
					stepSources(elem, data, false, _srces, true);
				}
			} else {
				handleThird(elem, ret, data);
			}
		} else {
			ret = mediaelement.canNativePlaySrces(elem, _srces);
			if(!ret){
				if(_noLoop){
					mediaelement.setError(elem, false);
					if(data && data.isActive == 'third') {
						mediaelement.setActive(elem, 'html5', data);
					}
				} else {
					stepSources(elem, data, true, _srces, true);
				}
			} else if(data && data.isActive == 'third') {
				mediaelement.setActive(elem, 'html5', data);
			}
		}
	};
	var stopParent = /^(?:embed|object|datalist)$/i;
	var selectSource = function(elem, data){
		var baseData = webshims.data(elem, 'mediaelementBase') || webshims.data(elem, 'mediaelementBase', {});
		var _srces = mediaelement.srces(elem);
		var parent = elem.parentNode;
		
		clearTimeout(baseData.loadTimer);
		$.data(elem, 'mediaerror', false);
		
		if(!_srces.length || !parent || parent.nodeType != 1 || stopParent.test(parent.nodeName || '')){return;}
		data = data || webshims.data(elem, 'mediaelement');
		stepSources(elem, data, options.preferFlash || undefined, _srces);
	};
	
	
	$(document).on('ended', function(e){
		var data = webshims.data(e.target, 'mediaelement');
		if( supportsLoop && (!data || data.isActive == 'html5') && !$.prop(e.target, 'loop')){return;}
		setTimeout(function(){
			if( $.prop(e.target, 'paused') || !$.prop(e.target, 'loop') ){return;}
			$(e.target).prop('currentTime', 0).play();
		}, 1);
		
	});
	if(!supportsLoop){
		webshims.defineNodeNamesBooleanProperty(['audio', 'video'], 'loop');
	}
	
	['audio', 'video'].forEach(function(nodeName){
		var supLoad = webshims.defineNodeNameProperty(nodeName, 'load',  {
			prop: {
				value: function(){
					var data = webshims.data(this, 'mediaelement');
					selectSource(this, data);
					if(hasNative && (!data || data.isActive == 'html5') && supLoad.prop._supvalue){
						supLoad.prop._supvalue.apply(this, arguments);
					}
				}
			}
		});
		nativeCanPlayType[nodeName] = webshims.defineNodeNameProperty(nodeName, 'canPlayType',  {
			prop: {
				value: function(type){
					var ret = '';
					if(hasNative && nativeCanPlayType[nodeName].prop._supvalue){
						ret = nativeCanPlayType[nodeName].prop._supvalue.call(this, type);
						if(ret == 'no'){
							ret = '';
						}
					}
					if(!ret && hasSwf){
						type = $.trim((type || '').split(';')[0]);
						if(mediaelement.swfMimeTypes.indexOf(type) != -1){
							ret = 'maybe';
						}
					}
					return ret;
				}
			}
		});
	});
	webshims.onNodeNamesPropertyModify(['audio', 'video'], ['src', 'poster'], {
		set: function(){
			var elem = this;
			var baseData = webshims.data(elem, 'mediaelementBase') || webshims.data(elem, 'mediaelementBase', {});
			clearTimeout(baseData.loadTimer);
			baseData.loadTimer = setTimeout(function(){
				selectSource(elem);
				elem = null;
			}, 9);
		}
	});
		
	var initMediaElements = function(){
		
		webshims.addReady(function(context, insertedElement){
			var media = $('video, audio', context)
				.add(insertedElement.filter('video, audio'))
				.each(function(){
					if($.browser.msie && webshims.browserVersion > 8 && $.prop(this, 'paused') && !$.prop(this, 'readyState') && $(this).is('audio[preload="none"][controls]:not([autoplay])')){
						$(this).prop('preload', 'metadata').mediaLoad();
					} else {
						selectSource(this);
					}
					
					
					
					if(hasNative){
						var bufferTimer;
						var lastBuffered;
						var elem = this;
						var getBufferedString = function(){
							var buffered = $.prop(elem, 'buffered');
							if(!buffered){return;}
							var bufferString = "";
							for(var i = 0, len = buffered.length; i < len;i++){
								bufferString += buffered.end(i);
							}
							return bufferString;
						};
						var testBuffer = function(){
							var buffered = getBufferedString();
							if(buffered != lastBuffered){
								lastBuffered = buffered;
								$(elem).triggerHandler('progress');
							}
						};
						
						$(this)
							.on({
								'play loadstart progress': function(e){
									if(e.type == 'progress'){
										lastBuffered = getBufferedString();
									}
									clearTimeout(bufferTimer);
									bufferTimer = setTimeout(testBuffer, 999);
								},
								'emptied stalled mediaerror abort suspend': function(e){
									if(e.type == 'emptied'){
										lastBuffered = false;
									}
									clearTimeout(bufferTimer);
								}
							})
						;
					}
					
				})
			;
			if(!loadTrackUi.loaded && $('track', media).length){
				loadTrackUi();
			}
			media = null;
		});
	};
	
	if(Modernizr.track && !bugs.track){
		webshims.defineProperty(TextTrack.prototype, 'shimActiveCues', {
			get: function(){
				return this._shimActiveCues || this.activeCues;
			}
		});
	}
	//set native implementation ready, before swf api is retested
	if(hasNative){
		webshims.isReady('mediaelement-core', true);
		initMediaElements();
		webshims.ready('WINDOWLOAD mediaelement', loadThird);
	} else {
		webshims.ready(swfType, initMediaElements);
	}
	webshims.ready('WINDOWLOAD mediaelement', loadTrackUi);
});
})(jQuery, Modernizr, jQuery.webshims);
/*
 * todos: 
 * - decouple muted/volume (needs improvement)
 * - implement video <-> flashcanvas pro API
 * - improve buffered-property with youtube/rtmp
 * - use jwplayer5 api instead of old flash4 api
 */

jQuery.webshims.register('mediaelement-swf', function($, webshims, window, document, undefined, options){
	"use strict";
	var SENDEVENT = 'sendEvent';
	var mediaelement = webshims.mediaelement;
	var swfobject = window.swfobject;
	var hasNative = Modernizr.audio && Modernizr.video;
	var hasFlash = swfobject.hasFlashPlayerVersion('9.0.115');
	var loadedSwf = 0;
	var getProps = {
		paused: true,
		ended: false,
		currentSrc: '',
		duration: window.NaN,
		
		readyState: 0,
		networkState: 0,
		videoHeight: 0,
		videoWidth: 0,
		error: null,
		buffered: {
			start: function(index){
				if(index){
					webshims.error('buffered index size error');
					return;
				}
				return 0;
			},
			end: function(index){
				if(index){
					webshims.error('buffered index size error');
					return;
				}
				return 0;
			},
			length: 0
		}
	};
	var getPropKeys = Object.keys(getProps);
	
	var getSetProps = {
		currentTime: 0,
		volume: 1,
		muted: false
	};
	var getSetPropKeys = Object.keys(getSetProps);
	
	var playerStateObj = $.extend({
		isActive: 'html5',
		activating: 'html5',	
		wasSwfReady: false,
		_bufferedEnd: 0,
		_bufferedStart: 0,
		_metadata: false,
		_durationCalcs: -1,
		_callMeta: false,
		currentTime: 0,
		_ppFlag: undefined
	}, getProps, getSetProps);
	
	var idRep = /^jwplayer-/;
	var getSwfDataFromID = function(id){
		
		var elem = document.getElementById(id.replace(idRep, ''));
		if(!elem){return;}
		var data = webshims.data(elem, 'mediaelement');
		return data.isActive == 'third' ? data : null;
	};
	
	
	var getSwfDataFromElem = function(elem){
		try {
			(elem.nodeName);
		} catch(er){
			return null;
		}
		var data = webshims.data(elem, 'mediaelement');
		return (data && data.isActive== 'third') ? data : null;
	};
	
	var trigger = function(elem, evt){
		evt = $.Event(evt);
		evt.preventDefault();
		$.event.trigger(evt, undefined, elem);
	};
	
	var playerSwfPath = options.playerPath || webshims.cfg.basePath + "jwplayer/" + (options.playerName || "player.swf");
	var jwplugin = options.pluginPath || webshims.cfg.basePath +'swf/jwwebshims.swf';
	
	webshims.extendUNDEFProp(options.params, {
		allowscriptaccess: 'always',
		allowfullscreen: 'true',
		wmode: 'transparent'
	});
	webshims.extendUNDEFProp(options.vars, {
		screencolor: 'ffffffff'
	});
	webshims.extendUNDEFProp(options.attrs, {
		bgcolor: '#000000'
	});
	
	var getDuration = function(data, obj){
		var curDuration = data.duration;
		if(curDuration && data._durationCalcs > 0){return;}
		try {
			data.duration = data.jwapi.getPlaylist()[0].duration;
			if(!data.duration || data.duration <= 0 || data.duration === data._lastDuration){
				data.duration = curDuration;
			}
		} catch(er){}
		if(data.duration && data.duration != data._lastDuration){
			trigger(data._elem, 'durationchange');
			if(data._elemNodeName == 'audio' || data._callMeta){
				mediaelement.jwEvents.Model.META($.extend({duration: data.duration}, obj), data);
			}
			data._durationCalcs--;
		} else {
			data._durationCalcs++;
		}
	};
	var setReadyState = function(readyState, data){
		if(readyState < 3){
			clearTimeout(data._canplaythroughTimer);
		}
		if(readyState >= 3 && data.readyState < 3){
			data.readyState = readyState;
			trigger(data._elem, 'canplay');
			clearTimeout(data._canplaythroughTimer);
			data._canplaythroughTimer = setTimeout(function(){
				setReadyState(4, data);
			}, 4000);
		}
		if(readyState >= 4 && data.readyState < 4){
			data.readyState = readyState;
			trigger(data._elem, 'canplaythrough');
		}
		data.readyState = readyState;
	};
	
	$.extend($.event.customEvent, {
		updatemediaelementdimensions: true,
		flashblocker: true,
		swfstageresize: true,
		mediaelementapichange: true
	});
	
	mediaelement.jwEvents = {
		View: {
			
			PLAY: function(obj){
				var data = getSwfDataFromID(obj.id);
				if(!data || data.stopPlayPause){return;}
				data._ppFlag = true;
				if(data.paused == obj.state){
					data.paused = !obj.state;
					if(data.ended){
						data.ended = false;
					}
					trigger(data._elem, obj.state ? 'play' : 'pause');
				}
			}
		},
		Model: {
			
			BUFFER: function(obj){
				var data = getSwfDataFromID(obj.id);
				if(!data || !('percentage' in obj) || data._bufferedEnd == obj.percentage){return;}
				data.networkState = (obj.percentage == 100) ? 1 : 2;
				if(isNaN(data.duration) || (obj.percentage > 5 && obj.percentage < 25) || (obj.percentage === 100)){
					getDuration(data, obj);
				}
				
				if(data.ended){
					data.ended = false;
				}
				if(!data.duration){
					return;
				}
				if(obj.percentage > 2 && obj.percentage < 20){
					setReadyState(3, data);
				} else if(obj.percentage > 20){
					setReadyState(4, data);
				}
				if(data._bufferedEnd && (data._bufferedEnd > obj.percentage)){
					data._bufferedStart = data.currentTime || 0;
				}
				
				data._bufferedEnd = obj.percentage;
				data.buffered.length = 1;
				if(obj.percentage == 100){
					data.networkState = 1;
					setReadyState(4, data);
				}
				$.event.trigger('progress', undefined, data._elem, true);
			},
			META: function(obj, data){
				
				data = data && data.networkState ? data : getSwfDataFromID(obj.id);

				if(!data){return;}
				if( !('duration' in obj) ){
					data._callMeta = true;
					return;
				}
				
				if( data._metadata && (!obj.height || data.videoHeight == obj.height) && (obj.duration === data.duration) ){return;}
				
				data._metadata = true;
								
				var oldDur = data.duration;
				if(obj.duration){
					data.duration = obj.duration;
				}
				data._lastDuration = data.duration;
				if(obj.height || obj.width){
					data.videoHeight = obj.height || 0;
					data.videoWidth = obj.width || 0;
				}
				if(!data.networkState){
					data.networkState = 2;
				}
				if(data.readyState < 1){
					setReadyState(1, data);
				}
				if(data.duration && oldDur !== data.duration){
					trigger(data._elem, 'durationchange');
				}
				
				trigger(data._elem, 'loadedmetadata');
			},
			TIME: function(obj){
				var data = getSwfDataFromID(obj.id);
				if(!data || data.currentTime === obj.position){return;}
				data.currentTime = obj.position;
				if(data.duration && data.duration < data.currentTime){
					getDuration(data, obj);
				}
				if(data.readyState < 2){
					setReadyState(2, data);
				}
				if(data.ended){
					data.ended = false;
				}
				trigger(data._elem, 'timeupdate');
				
			},
			STATE: function(obj){
				var data = getSwfDataFromID(obj.id);
				if(!data){return;}
				switch(obj.newstate) {
					case 'BUFFERING':
						
						if(data.ended){
							data.ended = false;
						}
						setReadyState(1, data);
						trigger(data._elem, 'waiting');
						break;
					case 'PLAYING':
						data.paused = false;
						data._ppFlag = true;
						if(!data.duration){
							getDuration(data, obj);
						}
						if(data.readyState < 3){
							setReadyState(3, data);
						}
						if(data.ended){
							data.ended = false;
						}
						trigger(data._elem, 'playing');
						break;
					case 'PAUSED':
						if(!data.paused && !data.stopPlayPause){
							data.paused = true;
							data._ppFlag = true;
							trigger(data._elem, 'pause');
						}
						break;
					case 'COMPLETED':
						if(data.readyState < 4){
							setReadyState(4, data);
						}
						data.ended = true;
						trigger(data._elem, 'ended');
						break;
				}
			}
		}
		,Controller: {
			
			ERROR: function(obj){
				var data = getSwfDataFromID(obj.id);
				if(!data){return;}
				mediaelement.setError(data._elem, obj.message);
			},
			SEEK: function(obj){
				var data = getSwfDataFromID(obj.id);
				if(!data){return;}
				if(data.ended){
					data.ended = false;
				}
				if(data.paused){
					try {
						data.jwapi[SENDEVENT]('play', 'false');
					} catch(er){}
				}
				if(data.currentTime != obj.position){
					data.currentTime = obj.position;
					trigger(data._elem, 'timeupdate');
				}
				
				
			},
			VOLUME: function(obj){
				var data = getSwfDataFromID(obj.id);
				if(!data){return;}
				var newVolume = obj.percentage / 100;
				if(data.volume == newVolume){return;}
				data.volume = newVolume;
				trigger(data._elem, 'volumechange');
			},
			MUTE: function(obj){
				if(obj.state){return;}
				var data = getSwfDataFromID(obj.id);
				if(!data){return;}
				if(data.muted == obj.state){return;}
				data.muted = obj.state;
				trigger(data._elem, 'volumechange');
			}
		}
	};
	
	var initEvents = function(data){
		var passed = true;
		$.each(mediaelement.jwEvents, function(mvcName, evts){
			$.each(evts, function(evtName){
				try {
					data.jwapi['add'+ mvcName +'Listener'](evtName, 'jQuery.webshims.mediaelement.jwEvents.'+ mvcName +'.'+ evtName);
				} catch(er){
					passed = false;
					return false;
				}
			});
		});
		return passed;
	};
	
	var workActionQueue = function(data){
		var actionLen = data.actionQueue.length;
		var i = 0;
		var operation;
		if(actionLen && data.isActive == 'third'){
			while(data.actionQueue.length && actionLen > i){
				i++;
				operation = data.actionQueue.shift();
				data.jwapi[operation.fn].apply(data.jwapi, operation.args);
			}
		}
		if(data.actionQueue.length){
			data.actionQueue = [];
		}
	};
	var startAutoPlay = function(data){
		if(!data){return;}
		if( (data._ppFlag === undefined && ($.prop(data._elem, 'autoplay')) || !data.paused)){
			setTimeout(function(){
				if(data.isActive == 'third' && (data._ppFlag === undefined || !data.paused)){
					try {
						$(data._elem).play();
					} catch(er){}
				}
			}, 1);
		}
	};
	
	
	mediaelement.playerResize = function(id){
		if(!id){return;}
		var elem = document.getElementById(id.replace(idRep, ''));
		
		if(elem){
			$(elem).triggerHandler('swfstageresize');
		}
		elem = null;
	};
	
	
	$(document).on('emptied', function(e){
		var data = getSwfDataFromElem(e.target);
		startAutoPlay(data);
	});
	
	var localConnectionTimer;
	mediaelement.jwPlayerReady = function(jwData){
		var data = getSwfDataFromID(jwData.id);
		var passed = true;
		var i = 0;
		var doneFn = function(){
			if(i > 9){return;}
			i++;
			if(initEvents(data)){
				if(!data.wasSwfReady){
					var version = parseFloat( jwData.version, 10);
					if(version < 5.1 || version >= 6){
						webshims.warn('mediaelement-swf is only testet with jwplayer 5.6+');
					}
				} else {
					$(data._elem).mediaLoad();
					
				}
				data.wasSwfReady = true;
				data.tryedReframeing = 0;
				workActionQueue(data);
				startAutoPlay(data);
			} else {
				clearTimeout(data.reframeTimer);
				data.reframeTimer = setTimeout(doneFn, 9 * i);
				if(i > 2 && data.tryedReframeing < 9){
					data.tryedReframeing++;
					data.shadowElem.css({overflow: 'visible'});
					setTimeout(function(){
						data.shadowElem.css({overflow: 'hidden'});
					}, 16);
				}
			}
		};
		if(!data || !data.jwapi){return;}
		if(!data.tryedReframeing){
			data.tryedReframeing = 0;
		}
		clearTimeout(localConnectionTimer);
		data.jwData = jwData;
		data.shadowElem.removeClass('flashblocker-assumed');
		$.prop(data._elem, 'volume', data.volume);
		$.prop(data._elem, 'muted', data.muted);
		doneFn();
		
	};
	
	var addMediaToStopEvents = $.noop;
	if(hasNative){
		var stopEvents = {
			play: 1,
			playing: 1
		};
		var hideEvtArray = ['play', 'pause', 'playing', 'canplay', 'progress', 'waiting', 'ended', 'loadedmetadata', 'durationchange', 'emptied'];
		var hidevents = hideEvtArray.map(function(evt){
			return evt +'.webshimspolyfill';
		}).join(' ');
		
		var hidePlayerEvents = function(event){
			var data = webshims.data(event.target, 'mediaelement');
			if(!data){return;}
			var isNativeHTML5 = ( event.originalEvent && event.originalEvent.type === event.type );
			if( isNativeHTML5 == (data.activating == 'third') ){
				event.stopImmediatePropagation();
				if(stopEvents[event.type] && data.isActive != data.activating){
					$(event.target).pause();
				}
			}
		};
		
		addMediaToStopEvents = function(elem){
			$(elem)
				.off(hidevents)
				.on(hidevents, hidePlayerEvents)
			;
			hideEvtArray.forEach(function(evt){
				webshims.moveToFirstEvent(elem, evt);
			});
		};
		addMediaToStopEvents(document);
	}
	
	
	mediaelement.setActive = function(elem, type, data){
		if(!data){
			data = webshims.data(elem, 'mediaelement');
		}
		if(!data || data.isActive == type){return;}
		if(type != 'html5' && type != 'third'){
			webshims.warn('wrong type for mediaelement activating: '+ type);
		}
		var shadowData = webshims.data(elem, 'shadowData');
		data.activating = type;
		$(elem).pause();
		data.isActive = type;
		if(type == 'third'){
			shadowData.shadowElement = shadowData.shadowFocusElement = data.shadowElem[0];
			$(elem).addClass('swf-api-active nonnative-api-active').hide().getShadowElement().show();
		} else {
			$(elem).removeClass('swf-api-active nonnative-api-active').show().getShadowElement().hide();
			shadowData.shadowElement = shadowData.shadowFocusElement = false;
		}
		$(elem).trigger('mediaelementapichange');
	};
	
	
	
	var resetSwfProps = (function(){
		var resetProtoProps = ['_bufferedEnd', '_bufferedStart', '_metadata', '_ppFlag', 'currentSrc', 'currentTime', 'duration', 'ended', 'networkState', 'paused', 'videoHeight', 'videoWidth', '_callMeta', '_durationCalcs'];
		var len = resetProtoProps.length;
		return function(data){
			
			if(!data){return;}
			var lenI = len;
			var networkState = data.networkState;
			setReadyState(0, data);
			while(--lenI){
				delete data[resetProtoProps[lenI]];
			}
			data.actionQueue = [];
			data.buffered.length = 0;
			if(networkState){
				trigger(data._elem, 'emptied');
			}
		};
	})();
	
	var setElementDimension = function(data, hasControls){
		var elem = data._elem;
		var box = data.shadowElem;
		$(elem)[hasControls ? 'addClass' : 'removeClass']('webshims-controls');
		if(data._elemNodeName == 'audio' && !hasControls){
			box.css({width: 0, height: 0});
		} else {
			box.css({
				width: elem.style.width || $(elem).width(),
				height: elem.style.height || $(elem).height()
			});
		}
	};
	
	mediaelement.createSWF = function( elem, canPlaySrc, data ){
		if(!hasFlash){
			setTimeout(function(){
				$(elem).mediaLoad(); //<- this should produce a mediaerror
			}, 1);
			return;
		}
		
		if(loadedSwf < 1){
			loadedSwf = 1;
		} else {
			loadedSwf++;
		}
		var vars = $.extend({}, options.vars, {
				image: $.prop(elem, 'poster') || '',
				file: canPlaySrc.streamId || canPlaySrc.srcProp
		});
		var elemVars = $(elem).data('vars') || {};
		
		if(canPlaySrc.server){
			vars.streamer = canPlaySrc.server;
		}
		if(!data){
			data = webshims.data(elem, 'mediaelement');
		}
		
		if(data && data.swfCreated){
			mediaelement.setActive(elem, 'third', data);
			resetSwfProps(data);
			data.currentSrc = canPlaySrc.srcProp;
			$.extend(vars, elemVars);
			options.changeSWF(vars, elem, canPlaySrc, data, 'load');
			queueSwfMethod(elem, SENDEVENT, ['LOAD', vars]);
			return;
		}
		
		
		var hasControls = $.prop(elem, 'controls');
		var elemId = 'jwplayer-'+ webshims.getID(elem);
		var params = $.extend(
			{},
			options.params,
			$(elem).data('params')
		);
		var elemNodeName = elem.nodeName.toLowerCase();
		var attrs = $.extend(
			{},
			options.attrs,
			{
				name: elemId,
				id: elemId
			},
			$(elem).data('attrs')
		);
		var box = $('<div class="polyfill-'+ (elemNodeName) +' polyfill-mediaelement" id="wrapper-'+ elemId +'"><div id="'+ elemId +'"></div>')
			.css({
				position: 'relative',
				overflow: 'hidden'
			})
		;
		data = webshims.data(elem, 'mediaelement', webshims.objectCreate(playerStateObj, {
			actionQueue: {
				value: []
			},
			shadowElem: {
				value: box
			},
			_elemNodeName: {
				value: elemNodeName
			},
			_elem: {
				value: elem
			},
			currentSrc: {
				value: canPlaySrc.srcProp
			},
			swfCreated: {
				value: true
			},
			buffered: {
				value: {
					start: function(index){
						if(index >= data.buffered.length){
							webshims.error('buffered index size error');
							return;
						}
						return 0;
					},
					end: function(index){
						if(index >= data.buffered.length){
							webshims.error('buffered index size error');
							return;
						}
						return ( (data.duration - data._bufferedStart) * data._bufferedEnd / 100) + data._bufferedStart;
					},
					length: 0
				}
			}
		}));
		
		setElementDimension(data, hasControls);
		
		box.insertBefore(elem);
		
		if(hasNative){
			$.extend(data, {volume: $.prop(elem, 'volume'), muted: $.prop(elem, 'muted')});
		}
		
		$.extend(vars, 
			{
				id: elemId,
				controlbar: hasControls ? options.vars.controlbar || (elemNodeName == 'video' ? 'over' : 'bottom') : (elemNodeName == 'video') ? 'none' : 'bottom',
				icons: ''+ (hasControls && elemNodeName == 'video')
			},
			elemVars,
			{playerready: 'jQuery.webshims.mediaelement.jwPlayerReady'}
		);
		if(vars.plugins){
			vars.plugins += ','+jwplugin;
		} else {
			vars.plugins = jwplugin;
		}
		
		
		webshims.addShadowDom(elem, box);
		
		addMediaToStopEvents(elem);
		
		mediaelement.setActive(elem, 'third', data);
		
		options.changeSWF(vars, elem, canPlaySrc, data, 'embed');
		
		$(elem).on('updatemediaelementdimensions updateshadowdom', function(){
			setElementDimension(data, $.prop(elem, 'controls'));
		});
		
		
		swfobject.embedSWF(playerSwfPath, elemId, "100%", "100%", "9.0.0", false, vars, params, attrs, function(swfData){
			
			if(swfData.success){
				data.jwapi = swfData.ref;
				
				if(!hasControls){
					$(swfData.ref).attr('tabindex', '-1').css('outline', 'none');
				}
				setTimeout(function(){
					if((!swfData.ref.parentNode && box[0].parentNode) || swfData.ref.style.display == "none"){
						box.addClass('flashblocker-assumed');
						$(elem).trigger('flashblocker');
						webshims.warn("flashblocker assumed");
					}
					$(swfData.ref).css({'minHeight': '2px', 'minWidth': '2px', display: 'block'});
				}, 9);
				if(!localConnectionTimer){
					clearTimeout(localConnectionTimer);
					localConnectionTimer = setTimeout(function(){
						var flash = $(swfData.ref);
						if(flash[0].offsetWidth > 1 && flash[0].offsetHeight > 1 && location.protocol.indexOf('file:') === 0){
							webshims.error("Add your local development-directory to the local-trusted security sandbox:  http://www.macromedia.com/support/documentation/en/flashplayer/help/settings_manager04.html");
						} else if(flash[0].offsetWidth < 2 || flash[0].offsetHeight < 2) {
							webshims.warn("JS-SWF connection can't be established on hidden or unconnected flash objects");
						}
						flash = null;
					}, 8000);
				}
			}
		});
	};
	
	
	var queueSwfMethod = function(elem, fn, args, data){
		data = data || getSwfDataFromElem(elem);
		if(data){
			if(data.jwapi && data.jwapi[fn]){
				data.jwapi[fn].apply(data.jwapi, args || []);
			} else {
				//todo add to queue
				data.actionQueue.push({fn: fn, args: args});
				if(data.actionQueue.length > 10){
					setTimeout(function(){
						if(data.actionQueue.length > 5){
							data.actionQueue.shift();
						}
					}, 99);
				}
			}
			return data;
		}
		return false;
	};
	
	['audio', 'video'].forEach(function(nodeName){
		var descs = {};
		var mediaSup;
		var createGetProp = function(key){
			if(nodeName == 'audio' && (key == 'videoHeight' || key == 'videoWidth')){return;}
			
			descs[key] = {
				get: function(){
					var data = getSwfDataFromElem(this);
					if(data){
						return data[key];
					} else if(hasNative && mediaSup[key].prop._supget) {
						return mediaSup[key].prop._supget.apply(this);
					} else {
						return playerStateObj[key];
					}
				},
				writeable: false
			};
		};
		var createGetSetProp = function(key, setFn){
			createGetProp(key);
			delete descs[key].writeable;
			descs[key].set = setFn;
		};
		
		createGetSetProp('volume', function(v){
			var data = getSwfDataFromElem(this);
			if(data){
				v *= 100;
				if(!isNaN(v)){
					var muted = data.muted;
					if(v < 0 || v > 100){
						webshims.error('volume greater or less than allowed '+ (v / 100));
					}
					
					queueSwfMethod(this, SENDEVENT, ['VOLUME', v], data);
					if(muted){
						try {
							data.jwapi.sendEvent('mute', 'true');
						} catch(er){}
					}
					v /= 100;
					if(data.volume == v || data.isActive != 'third'){return;}
					data.volume = v;
					trigger(data._elem, 'volumechange');
					data = null;
				} 
			} else if(mediaSup.volume.prop._supset) {
				return mediaSup.volume.prop._supset.apply(this, arguments);
			}
		});
		
		createGetSetProp('muted', function(m){
			var data = getSwfDataFromElem(this);
			if(data){
				m = !!m;
				queueSwfMethod(this, SENDEVENT, ['mute', ''+m], data);
				if(data.muted == m || data.isActive != 'third'){return;}
				data.muted = m;
				trigger(data._elem, 'volumechange');
				data = null;
			} else if(mediaSup.muted.prop._supset) {
				return mediaSup.muted.prop._supset.apply(this, arguments);
			}
		});
		
		
		createGetSetProp('currentTime', function(t){
			var data = getSwfDataFromElem(this);
			if(data){
				t *= 1;
				if (!isNaN(t)) {
					if(data.paused){
						clearTimeout(data.stopPlayPause);
						data.stopPlayPause = setTimeout(function(){
							data.paused = true;
							data.stopPlayPause = false;
						}, 50);
					}
					queueSwfMethod(this, SENDEVENT, ['SEEK', '' + t], data);
					
					if(data.paused){
						if(data.readyState > 0){
							data.currentTime = t;
							trigger(data._elem, 'timeupdate');
						}
						try {
							data.jwapi[SENDEVENT]('play', 'false');
						} catch(er){}
						
					}
				}
				 
			} else if(mediaSup.currentTime.prop._supset) {
				return mediaSup.currentTime.prop._supset.apply(this, arguments);
			}
		});
		
		['play', 'pause'].forEach(function(fn){
			descs[fn] = {
				value: function(){
					var data = getSwfDataFromElem(this);
					if(data){
						if(data.stopPlayPause){
							clearTimeout(data.stopPlayPause);
						}
						queueSwfMethod(this, SENDEVENT, ['play', fn == 'play'], data);
						setTimeout(function(){
							if(data.isActive == 'third'){
								data._ppFlag = true;
								if(data.paused != (fn != 'play')){
									data.paused = fn != 'play';
									trigger(data._elem, fn);
								}
							}
						}, 1);
					} else if(mediaSup[fn].prop._supvalue) {
						return mediaSup[fn].prop._supvalue.apply(this, arguments);
					}
				}
			};
		});
		
		getPropKeys.forEach(createGetProp);
		
		webshims.onNodeNamesPropertyModify(nodeName, 'controls', function(val, boolProp){
			var data = getSwfDataFromElem(this);
			$(this)[boolProp ? 'addClass' : 'removeClass']('webshims-controls');
			
			if(data){
				try {
					queueSwfMethod(this, boolProp ? 'showControls' : 'hideControls', [nodeName], data);
				} catch(er){
					webshims.warn("you need to generate a crossdomain.xml");
				}
				if(nodeName == 'audio'){
					setElementDimension(data, boolProp);
				}
				$(data.jwapi).attr('tabindex', boolProp ? '0' : '-1');
			}
		});
		
		mediaSup = webshims.defineNodeNameProperties(nodeName, descs, 'prop');
	});
	
	if(hasFlash){
		var oldClean = $.cleanData;
		var gcBrowser = $.browser.msie && webshims.browserVersion < 9;
		var flashNames = {
			object: 1,
			OBJECT: 1
		};
		$.cleanData = function(elems){
			var i, len, prop;
			if(elems && (len = elems.length) && loadedSwf){
				
				for(i = 0; i < len; i++){
					if(flashNames[elems[i].nodeName]){
						if(SENDEVENT in elems[i]){
							loadedSwf--;
							try {
								elems[i][SENDEVENT]('play', false);
							} catch(er){}
						}
						if(gcBrowser){
							try {
								for (prop in elems[i]) {
									if (typeof elems[i][prop] == "function") {
										elems[i][prop] = null;
									}
								}
							} catch(er){}
						}
					}
				}
				
			}
			return oldClean.apply(this, arguments);
		};
	}

	if(!hasNative){
		
		['poster', 'src'].forEach(function(prop){
			webshims.defineNodeNamesProperty(prop == 'src' ? ['audio', 'video', 'source'] : ['video'], prop, {
				//attr: {},
				reflect: true,
				propType: 'src'
			});
		});
		
		
		['autoplay', 'controls'].forEach(function(name){
			webshims.defineNodeNamesBooleanProperty(['audio', 'video'], name);
		});
			
		webshims.defineNodeNamesProperties(['audio', 'video'], {
			HAVE_CURRENT_DATA: {
				value: 2
			},
			HAVE_ENOUGH_DATA: {
				value: 4
			},
			HAVE_FUTURE_DATA: {
				value: 3
			},
			HAVE_METADATA: {
				value: 1
			},
			HAVE_NOTHING: {
				value: 0
			},
			NETWORK_EMPTY: {
				value: 0
			},
			NETWORK_IDLE: {
				value: 1
			},
			NETWORK_LOADING: {
				value: 2
			},
			NETWORK_NO_SOURCE: {
				value: 3
			}
					
		}, 'prop');
	}
});