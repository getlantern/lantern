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


