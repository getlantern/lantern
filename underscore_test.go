package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
    "github.com/robertkrimen/otto/underscore"
)

func underscoreTest() func(string, ... interface{}) Value {
	Otto, test := runTestWithOtto()
	Otto.Run(underscore.Source())

	Otto.Set("assert", func(call FunctionCall) Value {
		if !toBoolean(call.Argument(0)) {
			message := "Assertion failed"
			if len(call.ArgumentList) > 1 {
				message = toString(call.ArgumentList[1])
			}
			Fail(message)
			return FalseValue()
		}
		return TrueValue()
	})

	Otto.Run(`
		// QUnit mock, adapted from twostroke
		function module() { /* Nothing happens. */ }
		function equals(a, b, msg) {
			assert(a == b, msg + ", <" + a + "> != <" + b + ">");
		}
		var equal = equals;
		function notStrictEqual(a, b, msg) {
			assert(a !== b, msg);
		}
		function strictEqual(a, b, msg) {
			assert(a === b, msg);
		}
		function ok(a, msg) {
			assert(a, msg);
		}
		function raises(fn, expected, message) {
			var actual, _ok = false;
			if(typeof expected === "string") {
				message = expected;
				expected = null;
			}
			
			try {
				fn();
			} catch(e) {
				actual = e;
			}
			
			if(actual) {
				if(!expected) {
					_ok = true;
				} else if(expected instanceof RegExp) {
					_ok = expected.test(actual);
				} else if(actual instanceof expected) {
					_ok = true
				} else if(expected.call({}, actual) === true) {
					_ok = true;
				}
			}
			
			ok(_ok, message);
		}
		function test(name){
			if (arguments.length == 3) {
				count = 0
				for (count = 0; count < arguments[1]; count++) {
					arguments[2]()
				}
				return
			}
			// For now.
			arguments[1]()
		}
		function deepEqual(a, b, msg) {
			// Also, for now.
			assert(_.isEqual(a, b), msg)
		}
	`)
	return test
}

func Test_underscore(t *testing.T) {
	Terst(t)

	test := underscoreTest()

	test(`
		_.map([1, 2, 3], function(value){
			return value + 1
		})
	`, "2,3,4")

	test(`
		abc = _.find([1, 2, 3, -1], function(value) { return value == -1 })
	`, "-1")

	test(`_.isEqual(1, 1)`, "true")
	test(`_.isEqual([], [])`, "true")
	test(`_.isEqual(['b', 'd'], ['b', 'd'])`, "true")
	test(`_.isEqual(['b', 'd', 'c'], ['b', 'd', 'e'])`, "false")
	test(`_.isFunction(function(){})`, "true")

	test(`_.template('<p>\u2028<%= "\\u2028\\u2029" %>\u2029</p>')()`, "<p>\u2028\u2028\u2029\u2029</p>")
}

// TODO Test: typeof An argument reference
// TODO Test: abc = {}; abc == Object(abc)

func Test_underscoreObject(t *testing.T) {
	Terst(t)

	test := underscoreTest()

	test(`
	test("objects: keys", function() {
		equal(_.keys({one : 1, two : 2}).sort().join(', '), 'one, two', 'can extract the keys from an object');
		// the test above is not safe because it relies on for-in enumeration order
		var a = []; a[1] = 0;
		equal(_.keys(a).join(', '), '1', 'is not fooled by sparse arrays; see issue #95');
		raises(function() { _.keys(null); }, TypeError, 'throws an error for _null_ values');
		raises(function() { _.keys(void 0); }, TypeError, 'throws an error for _undefined_ values');
		raises(function() { _.keys(1); }, TypeError, 'throws an error for number primitives');
		raises(function() { _.keys('a'); }, TypeError, 'throws an error for string primitives');
		raises(function() { _.keys(true); }, TypeError, 'throws an error for boolean primitives');
	});
	`)

	test(`
	test("objects: values", function() {
		equal(_.values({one : 1, two : 2}).sort().join(', '), '1, 2', 'can extract the values from an object');
	});
	`)

	test(`
	test("objects: functions", function() {
		var obj = {a : 'dash', b : _.map, c : (/yo/), d : _.reduce};
		ok(_.isEqual(['b', 'd'], _.functions(obj)), 'can grab the function names of any passed-in object');

		var Animal = function(){};
		Animal.prototype.run = function(){};
		equal(_.functions(new Animal).join(''), 'run', 'also looks up functions on the prototype');
	});
	`)

	test(`
	test("objects: extend", function() {
		var result;
		equal(_.extend({}, {a:'b'}).a, 'b', 'can extend an object with the attributes of another');
		equal(_.extend({a:'x'}, {a:'b'}).a, 'b', 'properties in source override destination');
		equal(_.extend({x:'x'}, {a:'b'}).x, 'x', 'properties not in source dont get overriden');
		result = _.extend({x:'x'}, {a:'a'}, {b:'b'});
		ok(_.isEqual(result, {x:'x', a:'a', b:'b'}), 'can extend from multiple source objects');
		result = _.extend({x:'x'}, {a:'a', x:2}, {a:'b'});
		ok(_.isEqual(result, {x:2, a:'b'}), 'extending from multiple source objects last property trumps');
		result = _.extend({}, {a: void 0, b: null});
		equal(_.keys(result).sort().join(''), 'ab', 'extend does not copy undefined values');
	});
	`)

	test(`
	test("objects: pick", function() {
		var result;
		result = _.pick({a:1, b:2, c:3}, 'a', 'c');
		ok(_.isEqual(result, {a:1, c:3}), 'can restrict properties to those named');
		result = _.pick({a:1, b:2, c:3}, ['b', 'c']);
		ok(_.isEqual(result, {b:2, c:3}), 'can restrict properties to those named in an array');
		result = _.pick({a:1, b:2, c:3}, ['a'], 'b');
		ok(_.isEqual(result, {a:1, b:2}), 'can restrict properties to those named in mixed args');
	});
	`)

	test(`
	test("objects: defaults", function() {
		var result;
		var options = {zero: 0, one: 1, empty: "", nan: NaN, string: "string"};

		_.defaults(options, {zero: 1, one: 10, twenty: 20});
		equal(options.zero, 0, 'value exists');
		equal(options.one, 1, 'value exists');
		equal(options.twenty, 20, 'default applied');

		_.defaults(options, {empty: "full"}, {nan: "nan"}, {word: "word"}, {word: "dog"});
		equal(options.empty, "", 'value exists');
		ok(_.isNaN(options.nan), "NaN isn't overridden");
		equal(options.word, "word", 'new value is added, first one wins');
	});
	`)

	test(`
	test("objects: clone", function() {
		var moe = {name : 'moe', lucky : [13, 27, 34]};
		var clone = _.clone(moe);
		equal(clone.name, 'moe', 'the clone as the attributes of the original');

		clone.name = 'curly';
		ok(clone.name == 'curly' && moe.name == 'moe', 'clones can change shallow attributes without affecting the original');

		clone.lucky.push(101);
		equal(_.last(moe.lucky), 101, 'changes to deep attributes are shared with the original');

		equal(_.clone(undefined), void 0, 'non objects should not be changed by clone');
		equal(_.clone(1), 1, 'non objects should not be changed by clone');
		equal(_.clone(null), null, 'non objects should not be changed by clone');
	});
	`)

	test(`
	test("objects: isEqual", function() {
		function First() {
		this.value = 1;
		}
		First.prototype.value = 1;
		function Second() {
		this.value = 1;
		}
		Second.prototype.value = 2;

		// Basic equality and identity comparisons.
		ok(_.isEqual(null, null), "_null_ is equal to _null_");
		ok(_.isEqual(), "_undefined_ is equal to _undefined_");

		ok(!_.isEqual(0, -0), "_0_ is not equal to _-0_");
		ok(!_.isEqual(-0, 0), "Commutative equality is implemented for _0_ and _-0_");
		ok(!_.isEqual(null, undefined), "_null_ is not equal to _undefined_");
		ok(!_.isEqual(undefined, null), "Commutative equality is implemented for _null_ and _undefined_");

		// String object and primitive comparisons.
		ok(_.isEqual("Curly", "Curly"), "Identical string primitives are equal");
		ok(_.isEqual(new String("Curly"), new String("Curly")), "String objects with identical primitive values are equal");
		ok(_.isEqual(new String("Curly"), "Curly"), "String primitives and their corresponding object wrappers are equal");
		ok(_.isEqual("Curly", new String("Curly")), "Commutative equality is implemented for string objects and primitives");

		ok(!_.isEqual("Curly", "Larry"), "String primitives with different values are not equal");
		ok(!_.isEqual(new String("Curly"), new String("Larry")), "String objects with different primitive values are not equal");
		ok(!_.isEqual(new String("Curly"), {toString: function(){ return "Curly"; }}), "String objects and objects with a custom _toString_ method are not equal");

		// Number object and primitive comparisons.
		ok(_.isEqual(75, 75), "Identical number primitives are equal");
		ok(_.isEqual(new Number(75), new Number(75)), "Number objects with identical primitive values are equal");
		ok(_.isEqual(75, new Number(75)), "Number primitives and their corresponding object wrappers are equal");

		ok(_.isEqual(new Number(75), 75), "Commutative equality is implemented for number objects and primitives");
		ok(!_.isEqual(new Number(0), -0), "_new Number(0)_ and _-0_ are not equal");
		ok(!_.isEqual(0, new Number(-0)), "Commutative equality is implemented for _new Number(0)_ and _-0_");

		ok(!_.isEqual(new Number(75), new Number(63)), "Number objects with different primitive values are not equal");
		ok(!_.isEqual(new Number(63), {valueOf: function(){ return 63; }}), "Number objects and objects with a _valueOf_ method are not equal");

		// Comparisons involving _NaN_.
		ok(_.isEqual(NaN, NaN), "_NaN_ is equal to _NaN_");
		ok(!_.isEqual(61, NaN), "A number primitive is not equal to _NaN_");
		ok(!_.isEqual(new Number(79), NaN), "A number object is not equal to _NaN_");
		ok(!_.isEqual(Infinity, NaN), "_Infinity_ is not equal to _NaN_");

		// Boolean object and primitive comparisons.
		ok(_.isEqual(true, true), "Identical boolean primitives are equal");
		ok(_.isEqual(new Boolean, new Boolean), "Boolean objects with identical primitive values are equal");
		ok(_.isEqual(true, new Boolean(true)), "Boolean primitives and their corresponding object wrappers are equal");
		ok(_.isEqual(new Boolean(true), true), "Commutative equality is implemented for booleans");
		ok(!_.isEqual(new Boolean(true), new Boolean), "Boolean objects with different primitive values are not equal");

		// Common type coercions.
		ok(!_.isEqual(true, new Boolean(false)), "Boolean objects are not equal to the boolean primitive _true_");
		ok(!_.isEqual("75", 75), "String and number primitives with like values are not equal");
		ok(!_.isEqual(new Number(63), new String(63)), "String and number objects with like values are not equal");
		ok(!_.isEqual(75, "75"), "Commutative equality is implemented for like string and number values");
		ok(!_.isEqual(0, ""), "Number and string primitives with like values are not equal");
		ok(!_.isEqual(1, true), "Number and boolean primitives with like values are not equal");
		ok(!_.isEqual(new Boolean(false), new Number(0)), "Boolean and number objects with like values are not equal");
		ok(!_.isEqual(false, new String("")), "Boolean primitives and string objects with like values are not equal");
		ok(!_.isEqual(12564504e5, new Date(2009, 9, 25)), "Dates and their corresponding numeric primitive values are not equal");

		// Dates.
		ok(_.isEqual(new Date(2009, 9, 25), new Date(2009, 9, 25)), "Date objects referencing identical times are equal");
		ok(!_.isEqual(new Date(2009, 9, 25), new Date(2009, 11, 13)), "Date objects referencing different times are not equal");
		ok(!_.isEqual(new Date(2009, 11, 13), {
		getTime: function(){
			return 12606876e5;
		}
		}), "Date objects and objects with a _getTime_ method are not equal");
		ok(!_.isEqual(new Date("Curly"), new Date("Curly")), "Invalid dates are not equal");

		// Functions.
		ok(!_.isEqual(First, Second), "Different functions with identical bodies and source code representations are not equal");

		// RegExps.
		ok(_.isEqual(/(?:)/gim, /(?:)/gim), "RegExps with equivalent patterns and flags are equal");
		ok(!_.isEqual(/(?:)/g, /(?:)/gi), "RegExps with equivalent patterns and different flags are not equal");
		ok(!_.isEqual(/Moe/gim, /Curly/gim), "RegExps with different patterns and equivalent flags are not equal");
		ok(!_.isEqual(/(?:)/gi, /(?:)/g), "Commutative equality is implemented for RegExps");
		ok(!_.isEqual(/Curly/g, {source: "Larry", global: true, ignoreCase: false, multiline: false}), "RegExps and RegExp-like objects are not equal");

		// Empty arrays, array-like objects, and object literals.
		ok(_.isEqual({}, {}), "Empty object literals are equal");
		ok(_.isEqual([], []), "Empty array literals are equal");
		ok(_.isEqual([{}], [{}]), "Empty nested arrays and objects are equal");
		ok(!_.isEqual({length: 0}, []), "Array-like objects and arrays are not equal.");
		ok(!_.isEqual([], {length: 0}), "Commutative equality is implemented for array-like objects");

		ok(!_.isEqual({}, []), "Object literals and array literals are not equal");
		ok(!_.isEqual([], {}), "Commutative equality is implemented for objects and arrays");

		// Arrays with primitive and object values.
		ok(_.isEqual([1, "Larry", true], [1, "Larry", true]), "Arrays containing identical primitives are equal");
		ok(_.isEqual([(/Moe/g), new Date(2009, 9, 25)], [(/Moe/g), new Date(2009, 9, 25)]), "Arrays containing equivalent elements are equal");

		// Multi-dimensional arrays.
		var a = [new Number(47), false, "Larry", /Moe/, new Date(2009, 11, 13), ['running', 'biking', new String('programming')], {a: 47}];
		var b = [new Number(47), false, "Larry", /Moe/, new Date(2009, 11, 13), ['running', 'biking', new String('programming')], {a: 47}];
		ok(_.isEqual(a, b), "Arrays containing nested arrays and objects are recursively compared");

		// Overwrite the methods defined in ES 5.1 section 15.4.4.
		a.forEach = a.map = a.filter = a.every = a.indexOf = a.lastIndexOf = a.some = a.reduce = a.reduceRight = null;
		b.join = b.pop = b.reverse = b.shift = b.slice = b.splice = b.concat = b.sort = b.unshift = null;

		// Array elements and properties.
		ok(_.isEqual(a, b), "Arrays containing equivalent elements and different non-numeric properties are equal");
		a.push("White Rocks");
		ok(!_.isEqual(a, b), "Arrays of different lengths are not equal");
		a.push("East Boulder");
		b.push("Gunbarrel Ranch", "Teller Farm");
		ok(!_.isEqual(a, b), "Arrays of identical lengths containing different elements are not equal");

		// Sparse arrays.
		ok(_.isEqual(Array(3), Array(3)), "Sparse arrays of identical lengths are equal");
		ok(!_.isEqual(Array(3), Array(6)), "Sparse arrays of different lengths are not equal when both are empty");

		// According to the Microsoft deviations spec, section 2.1.26, JScript 5.x treats _undefined_
		// elements in arrays as elisions. Thus, sparse arrays and dense arrays containing _undefined_
		// values are equivalent.
		if (0 in [undefined]) {
		ok(!_.isEqual(Array(3), [undefined, undefined, undefined]), "Sparse and dense arrays are not equal");
		ok(!_.isEqual([undefined, undefined, undefined], Array(3)), "Commutative equality is implemented for sparse and dense arrays");
		}

		// Simple objects.
		ok(_.isEqual({a: "Curly", b: 1, c: true}, {a: "Curly", b: 1, c: true}), "Objects containing identical primitives are equal");
		ok(_.isEqual({a: /Curly/g, b: new Date(2009, 11, 13)}, {a: /Curly/g, b: new Date(2009, 11, 13)}), "Objects containing equivalent members are equal");
		ok(!_.isEqual({a: 63, b: 75}, {a: 61, b: 55}), "Objects of identical sizes with different values are not equal");
		ok(!_.isEqual({a: 63, b: 75}, {a: 61, c: 55}), "Objects of identical sizes with different property names are not equal");
		ok(!_.isEqual({a: 1, b: 2}, {a: 1}), "Objects of different sizes are not equal");
		ok(!_.isEqual({a: 1}, {a: 1, b: 2}), "Commutative equality is implemented for objects");
		ok(!_.isEqual({x: 1, y: undefined}, {x: 1, z: 2}), "Objects with identical keys and different values are not equivalent");

		// _A_ contains nested objects and arrays.
		a = {
		name: new String("Moe Howard"),
		age: new Number(77),
		stooge: true,
		hobbies: ["acting"],
		film: {
			name: "Sing a Song of Six Pants",
			release: new Date(1947, 9, 30),
			stars: [new String("Larry Fine"), "Shemp Howard"],
			minutes: new Number(16),
			seconds: 54
		}
		};

		// _B_ contains equivalent nested objects and arrays.
		b = {
		name: new String("Moe Howard"),
		age: new Number(77),
		stooge: true,
		hobbies: ["acting"],
		film: {
			name: "Sing a Song of Six Pants",
			release: new Date(1947, 9, 30),
			stars: [new String("Larry Fine"), "Shemp Howard"],
			minutes: new Number(16),
			seconds: 54
		}
		};
		ok(_.isEqual(a, b), "Objects with nested equivalent members are recursively compared");

		// Instances.
		ok(_.isEqual(new First, new First), "Object instances are equal");
		ok(!_.isEqual(new First, new Second), "Objects with different constructors and identical own properties are not equal");
		ok(!_.isEqual({value: 1}, new First), "Object instances and objects sharing equivalent properties are not equal");
		ok(!_.isEqual({value: 2}, new Second), "The prototype chain of objects should not be examined");

		// Circular Arrays.
		(a = []).push(a);
		(b = []).push(b);
		ok(_.isEqual(a, b), "Arrays containing circular references are equal");
		a.push(new String("Larry"));
		b.push(new String("Larry"));
		ok(_.isEqual(a, b), "Arrays containing circular references and equivalent properties are equal");
		a.push("Shemp");
		b.push("Curly");
		ok(!_.isEqual(a, b), "Arrays containing circular references and different properties are not equal");

		// Circular Objects.
		a = {abc: null};
		b = {abc: null};
		a.abc = a;
		b.abc = b;
		ok(_.isEqual(a, b), "Objects containing circular references are equal");
		a.def = 75;
		b.def = 75;
		ok(_.isEqual(a, b), "Objects containing circular references and equivalent properties are equal");
		a.def = new Number(75);
		b.def = new Number(63);
		ok(!_.isEqual(a, b), "Objects containing circular references and different properties are not equal");

		// Cyclic Structures.
		a = [{abc: null}];
		b = [{abc: null}];
		(a[0].abc = a).push(a);
		(b[0].abc = b).push(b);
		ok(_.isEqual(a, b), "Cyclic structures are equal");
		a[0].def = "Larry";
		b[0].def = "Larry";
		ok(_.isEqual(a, b), "Cyclic structures containing equivalent properties are equal");
		a[0].def = new String("Larry");
		b[0].def = new String("Curly");
		ok(!_.isEqual(a, b), "Cyclic structures containing different properties are not equal");

		// Complex Circular references.
		a = {foo: {b: {foo: {c: {foo: null}}}}};
		b = {foo: {b: {foo: {c: {foo: null}}}}};
		a.foo.b.foo.c.foo = a;
		b.foo.b.foo.c.foo = b;
		ok(_.isEqual(a, b), "Cyclic structures with nested and identically-named properties are equal");

		// Chaining.
		ok(!_.isEqual(_({x: 1, y: undefined}).chain(), _({x: 1, z: 2}).chain()), 'Chained objects containing different values are not equal');
		equal(_({x: 1, y: 2}).chain().isEqual(_({x: 1, y: 2}).chain()).value(), true, '_isEqual_ can be chained');

		// Custom _isEqual_ methods.
		var isEqualObj = {isEqual: function (o) { return o.isEqual == this.isEqual; }, unique: {}};
		var isEqualObjClone = {isEqual: isEqualObj.isEqual, unique: {}};

		ok(_.isEqual(isEqualObj, isEqualObjClone), 'Both objects implement identical _isEqual_ methods');
		ok(_.isEqual(isEqualObjClone, isEqualObj), 'Commutative equality is implemented for objects with custom _isEqual_ methods');
		ok(!_.isEqual(isEqualObj, {}), 'Objects that do not implement equivalent _isEqual_ methods are not equal');
		ok(!_.isEqual({}, isEqualObj), 'Commutative equality is implemented for objects with different _isEqual_ methods');

		// Custom _isEqual_ methods - comparing different types
		LocalizedString = (function() {
		function LocalizedString(id) { this.id = id; this.string = (this.id===10)? 'Bonjour': ''; }
		LocalizedString.prototype.isEqual = function(that) {
			if (_.isString(that)) return this.string == that;
			else if (that instanceof LocalizedString) return this.id == that.id;
			return false;
		};
		return LocalizedString;
		})();
		var localized_string1 = new LocalizedString(10), localized_string2 = new LocalizedString(10), localized_string3 = new LocalizedString(11);
		ok(_.isEqual(localized_string1, localized_string2), 'comparing same typed instances with same ids');
		ok(!_.isEqual(localized_string1, localized_string3), 'comparing same typed instances with different ids');
		ok(_.isEqual(localized_string1, 'Bonjour'), 'comparing different typed instances with same values');
		ok(_.isEqual('Bonjour', localized_string1), 'comparing different typed instances with same values');
		ok(!_.isEqual('Bonjour', localized_string3), 'comparing two localized strings with different ids');
		ok(!_.isEqual(localized_string1, 'Au revoir'), 'comparing different typed instances with different values');
		ok(!_.isEqual('Au revoir', localized_string1), 'comparing different typed instances with different values');

		// Custom _isEqual_ methods - comparing with serialized data
		Date.prototype.toJSON = function() {
		return {
			_type:'Date',
			year:this.getUTCFullYear(),
			month:this.getUTCMonth(),
			day:this.getUTCDate(),
			hours:this.getUTCHours(),
			minutes:this.getUTCMinutes(),
			seconds:this.getUTCSeconds()
		};
		};
		Date.prototype.isEqual = function(that) {
		var this_date_components = this.toJSON();
		var that_date_components = (that instanceof Date) ? that.toJSON() : that;
		delete this_date_components['_type']; delete that_date_components['_type'];
		return _.isEqual(this_date_components, that_date_components);
		};

		var date = new Date();
		var date_json = {
		_type:'Date',
		year:date.getUTCFullYear(),
		month:date.getUTCMonth(),
		day:date.getUTCDate(),
		hours:date.getUTCHours(),
		minutes:date.getUTCMinutes(),
		seconds:date.getUTCSeconds()
		};

		ok(_.isEqual(date_json, date), 'serialized date matches date');
		ok(_.isEqual(date, date_json), 'date matches serialized date');

	});
	`)

	test(`
	test("objects: isArguments", function() {
		var args = (function(){ return arguments; })(1, 2, 3);
		ok(!_.isArguments('string'), 'a string is not an arguments object');
		ok(!_.isArguments(_.isArguments), 'a function is not an arguments object');
		ok(_.isArguments(args), 'but the arguments object is an arguments object');
		ok(!_.isArguments(_.toArray(args)), 'but not when it\'s converted into an array');
		ok(!_.isArguments([1,2,3]), 'and not vanilla arrays.');
	});
	`)

	test(`
	test("objects: isObject", function() {
		ok(_.isObject(arguments), 'the arguments object is object');
		ok(_.isObject([1, 2, 3]), 'and arrays');
		ok(_.isObject(function () {}), 'and functions');
		ok(!_.isObject(null), 'but not null');
		ok(!_.isObject(undefined), 'and not undefined');
		ok(!_.isObject('string'), 'and not string');
		ok(!_.isObject(12), 'and not number');
		ok(!_.isObject(true), 'and not boolean');
		ok(_.isObject(new String('string')), 'but new String()');
	});
	`)

	test(`
	test("objects: isArray", function() {
		ok(!_.isArray(arguments), 'the arguments object is not an array');
		ok(_.isArray([1, 2, 3]), 'but arrays are');
	});
	`)

	test(`
	test("objects: isString", function() {
		ok(!_.isString(arguments), 'arguments is not a string');
		ok(_.isString([1, 2, 3].join(', ')), 'but strings are');
	});
	`)

	test(`
	test("objects: isNumber", function() {
		ok(!_.isNumber('string'), 'a string is not a number');
		ok(!_.isNumber(arguments), 'the arguments object is not a number');
		ok(!_.isNumber(undefined), 'undefined is not a number');
		ok(_.isNumber(3 * 4 - 7 / 10), 'but numbers are');
		ok(_.isNumber(NaN), 'NaN *is* a number');
		ok(_.isNumber(Infinity), 'Infinity is a number');
		ok(!_.isNumber('1'), 'numeric strings are not numbers');
	});
	`)

	test(`
	test("objects: isBoolean", function() {
		ok(!_.isBoolean(2), 'a number is not a boolean');
		ok(!_.isBoolean("string"), 'a string is not a boolean');
		ok(!_.isBoolean("false"), 'the string "false" is not a boolean');
		ok(!_.isBoolean("true"), 'the string "true" is not a boolean');
		ok(!_.isBoolean(arguments), 'the arguments object is not a boolean');
		ok(!_.isBoolean(undefined), 'undefined is not a boolean');
		ok(!_.isBoolean(NaN), 'NaN is not a boolean');
		ok(!_.isBoolean(null), 'null is not a boolean');
		ok(_.isBoolean(true), 'but true is');
		ok(_.isBoolean(false), 'and so is false');
	});
	`)

	test(`
	test("objects: isFunction", function() {
		ok(!_.isFunction([1, 2, 3]), 'arrays are not functions');
		ok(!_.isFunction('moe'), 'strings are not functions');
		ok(_.isFunction(_.isFunction), 'but functions are');
	});
	`)

	test(`
	test("objects: isDate", function() {
		ok(!_.isDate(100), 'numbers are not dates');
		ok(!_.isDate({}), 'objects are not dates');
		ok(_.isDate(new Date()), 'but dates are');
	});
	`)

	test(`
	test("objects: isRegExp", function() {
		ok(!_.isRegExp(_.identity), 'functions are not RegExps');
		ok(_.isRegExp(/identity/), 'but RegExps are');
	});
	`)

	test(`
	test("objects: isFinite", function() {
		ok(!_.isFinite(undefined), 'undefined is not Finite');
		ok(!_.isFinite(null), 'null is not Finite');
		ok(!_.isFinite(NaN), 'NaN is not Finite');
		ok(!_.isFinite(Infinity), 'Infinity is not Finite');
		ok(!_.isFinite(-Infinity), '-Infinity is not Finite');
		ok(!_.isFinite('12'), 'Strings are not numbers');
		var obj = new Number(5);
		ok(_.isFinite(obj), 'Number instances can be finite');
		ok(_.isFinite(0), '0 is Finite');
		ok(_.isFinite(123), 'Ints are Finite');
		ok(_.isFinite(-12.44), 'Floats are Finite');
	});
	`)

	test(`
	test("objects: isNaN", function() {
		ok(!_.isNaN(undefined), 'undefined is not NaN');
		ok(!_.isNaN(null), 'null is not NaN');
		ok(!_.isNaN(0), '0 is not NaN');
		ok(_.isNaN(NaN), 'but NaN is');
	});
	`)

	test(`
	test("objects: isNull", function() {
		ok(!_.isNull(undefined), 'undefined is not null');
		ok(!_.isNull(NaN), 'NaN is not null');
		ok(_.isNull(null), 'but null is');
	});
	`)

	test(`
	test("objects: isUndefined", function() {
		ok(!_.isUndefined(1), 'numbers are defined');
		ok(!_.isUndefined(null), 'null is defined');
		ok(!_.isUndefined(false), 'false is defined');
		ok(!_.isUndefined(NaN), 'NaN is defined');
		ok(_.isUndefined(), 'nothing is undefined');
		ok(_.isUndefined(undefined), 'undefined is undefined');
	});
	`)

	test(`
	test("objects: tap", function() {
		var intercepted = null;
		var interceptor = function(obj) { intercepted = obj; };
		var returned = _.tap(1, interceptor);
		equal(intercepted, 1, "passes tapped object to interceptor");
		equal(returned, 1, "returns tapped object");

		returned = _([1,2,3]).chain().
		map(function(n){ return n * 2; }).
		max().
		tap(interceptor).
		value();
		ok(returned == 6 && intercepted == 6, 'can use tapped objects in a chain');
	});
	`)
}

func Test_underscoreArray(t *testing.T) {
	Terst(t)

	test := underscoreTest()

	test(`
	test("arrays: first", function() {
		equal(_.first([1,2,3]), 1, 'can pull out the first element of an array');
		equal(_([1, 2, 3]).first(), 1, 'can perform OO-style "first()"');
		equal(_.first([1,2,3], 0).join(', '), "", 'can pass an index to first');
		equal(_.first([1,2,3], 2).join(', '), '1, 2', 'can pass an index to first');
		equal(_.first([1,2,3], 5).join(', '), '1, 2, 3', 'can pass an index to first');
		var result = (function(){ return _.first(arguments); })(4, 3, 2, 1);
		equal(result, 4, 'works on an arguments object.');
		result = _.map([[1,2,3],[1,2,3]], _.first);
		equal(result.join(','), '1,1', 'works well with _.map');
		result = (function() { return _.take([1,2,3], 2); })();
		equal(result.join(','), '1,2', 'aliased as take');
	});
	`)

	test(`
	test("arrays: rest", function() {
		var numbers = [1, 2, 3, 4];
		equal(_.rest(numbers).join(", "), "2, 3, 4", 'working rest()');
		equal(_.rest(numbers, 0).join(", "), "1, 2, 3, 4", 'working rest(0)');
		equal(_.rest(numbers, 2).join(', '), '3, 4', 'rest can take an index');
		var result = (function(){ return _(arguments).tail(); })(1, 2, 3, 4);
		equal(result.join(', '), '2, 3, 4', 'aliased as tail and works on arguments object');
		result = _.map([[1,2,3],[1,2,3]], _.rest);
		equal(_.flatten(result).join(','), '2,3,2,3', 'works well with _.map');
	});
	`)

	test(`
	test("arrays: initial", function() {
		equal(_.initial([1,2,3,4,5]).join(", "), "1, 2, 3, 4", 'working initial()');
		equal(_.initial([1,2,3,4],2).join(", "), "1, 2", 'initial can take an index');
		var result = (function(){ return _(arguments).initial(); })(1, 2, 3, 4);
		equal(result.join(", "), "1, 2, 3", 'initial works on arguments object');
		result = _.map([[1,2,3],[1,2,3]], _.initial);
		equal(_.flatten(result).join(','), '1,2,1,2', 'initial works with _.map');
	});
	`)

	test(`
	test("arrays: last", function() {
		equal(_.last([1,2,3]), 3, 'can pull out the last element of an array');
		equal(_.last([1,2,3], 0).join(', '), "", 'can pass an index to last');
		equal(_.last([1,2,3], 2).join(', '), '2, 3', 'can pass an index to last');
		equal(_.last([1,2,3], 5).join(', '), '1, 2, 3', 'can pass an index to last');
		var result = (function(){ return _(arguments).last(); })(1, 2, 3, 4);
		equal(result, 4, 'works on an arguments object');
		result = _.map([[1,2,3],[1,2,3]], _.last);
		equal(result.join(','), '3,3', 'works well with _.map');
	});
	`)

	test(`
	test("arrays: compact", function() {
		equal(_.compact([0, 1, false, 2, false, 3]).length, 3, 'can trim out all falsy values');
		var result = (function(){ return _(arguments).compact().length; })(0, 1, false, 2, false, 3);
		equal(result, 3, 'works on an arguments object');
	});
	`)

// TODO
	if false {
	test(`
	test("arrays: flatten", function() {
		if (window.JSON) {
		var list = [1, [2], [3, [[[4]]]]];
		equal(JSON.stringify(_.flatten(list)), '[1,2,3,4]', 'can flatten nested arrays');
		equal(JSON.stringify(_.flatten(list, true)), '[1,2,3,[[[4]]]]', 'can shallowly flatten nested arrays');
		var result = (function(){ return _.flatten(arguments); })(1, [2], [3, [[[4]]]]);
		equal(JSON.stringify(result), '[1,2,3,4]', 'works on an arguments object');
		}
	});
	`)
	}

	test(`
	test("arrays: without", function() {
		var list = [1, 2, 1, 0, 3, 1, 4];
		equal(_.without(list, 0, 1).join(', '), '2, 3, 4', 'can remove all instances of an object');
		var result = (function(){ return _.without(arguments, 0, 1); })(1, 2, 1, 0, 3, 1, 4);
		equal(result.join(', '), '2, 3, 4', 'works on an arguments object');

		var list = [{one : 1}, {two : 2}];
		ok(_.without(list, {one : 1}).length == 2, 'uses real object identity for comparisons.');
		ok(_.without(list, list[0]).length == 1, 'ditto.');
	});
	`)

	test(`
	test("arrays: uniq", function() {
		var list = [1, 2, 1, 3, 1, 4];
		equal(_.uniq(list).join(', '), '1, 2, 3, 4', 'can find the unique values of an unsorted array');

		var list = [1, 1, 1, 2, 2, 3];
		equal(_.uniq(list, true).join(', '), '1, 2, 3', 'can find the unique values of a sorted array faster');

		var list = [{name:'moe'}, {name:'curly'}, {name:'larry'}, {name:'curly'}];
		var iterator = function(value) { return value.name; };
		equal(_.map(_.uniq(list, false, iterator), iterator).join(', '), 'moe, curly, larry', 'can find the unique values of an array using a custom iterator');

		var iterator = function(value) { return value +1; };
		var list = [1, 2, 2, 3, 4, 4];
		equal(_.uniq(list, true, iterator).join(', '), '1, 2, 3, 4', 'iterator works with sorted array');

		var result = (function(){ return _.uniq(arguments); })(1, 2, 1, 3, 1, 4);
		equal(result.join(', '), '1, 2, 3, 4', 'works on an arguments object');
	});
	`)

	test(`
	test("arrays: intersection", function() {
		var stooges = ['moe', 'curly', 'larry'], leaders = ['moe', 'groucho'];
		equal(_.intersection(stooges, leaders).join(''), 'moe', 'can take the set intersection of two arrays');
		equal(_(stooges).intersection(leaders).join(''), 'moe', 'can perform an OO-style intersection');
		var result = (function(){ return _.intersection(arguments, leaders); })('moe', 'curly', 'larry');
		equal(result.join(''), 'moe', 'works on an arguments object');
	});
	`)

	test(`
	test("arrays: union", function() {
		var result = _.union([1, 2, 3], [2, 30, 1], [1, 40]);
		equal(result.join(' '), '1 2 3 30 40', 'takes the union of a list of arrays');

		var result = _.union([1, 2, 3], [2, 30, 1], [1, 40, [1]]);
		equal(result.join(' '), '1 2 3 30 40 1', 'takes the union of a list of nested arrays');
	});
	`)

	test(`
	test("arrays: difference", function() {
		var result = _.difference([1, 2, 3], [2, 30, 40]);
		equal(result.join(' '), '1 3', 'takes the difference of two arrays');

		var result = _.difference([1, 2, 3, 4], [2, 30, 40], [1, 11, 111]);
		equal(result.join(' '), '3 4', 'takes the difference of three arrays');
	});
	`)

	test(`
	test('arrays: zip', function() {
		var names = ['moe', 'larry', 'curly'], ages = [30, 40, 50], leaders = [true];
		var stooges = _.zip(names, ages, leaders);
		equal(String(stooges), 'moe,30,true,larry,40,,curly,50,', 'zipped together arrays of different lengths');
	});
	`)

	test(`
	test('arrays: zipObject', function() {
		var result = _.zipObject(['moe', 'larry', 'curly'], [30, 40, 50]);
		var shouldBe = {moe: 30, larry: 40, curly: 50};
		ok(_.isEqual(result, shouldBe), 'two arrays zipped together into an object');
	});
	`)

	test(`
	test("arrays: indexOf", function() {
		var numbers = [1, 2, 3];
		numbers.indexOf = null;
		equal(_.indexOf(numbers, 2), 1, 'can compute indexOf, even without the native function');
		var result = (function(){ return _.indexOf(arguments, 2); })(1, 2, 3);
		equal(result, 1, 'works on an arguments object');
		equal(_.indexOf(null, 2), -1, 'handles nulls properly');

		var numbers = [10, 20, 30, 40, 50], num = 35;
		var index = _.indexOf(numbers, num, true);
		equal(index, -1, '35 is not in the list');

		numbers = [10, 20, 30, 40, 50]; num = 40;
		index = _.indexOf(numbers, num, true);
		equal(index, 3, '40 is in the list');

		numbers = [1, 40, 40, 40, 40, 40, 40, 40, 50, 60, 70]; num = 40;
		index = _.indexOf(numbers, num, true);
		equal(index, 1, '40 is in the list');
	});
	`)

	test(`
	test("arrays: lastIndexOf", function() {
		var numbers = [1, 0, 1, 0, 0, 1, 0, 0, 0];
		numbers.lastIndexOf = null;
		equal(_.lastIndexOf(numbers, 1), 5, 'can compute lastIndexOf, even without the native function');
		equal(_.lastIndexOf(numbers, 0), 8, 'lastIndexOf the other element');
		var result = (function(){ return _.lastIndexOf(arguments, 1); })(1, 0, 1, 0, 0, 1, 0, 0, 0);
		equal(result, 5, 'works on an arguments object');
		equal(_.indexOf(null, 2), -1, 'handles nulls properly');
	});
	`)

	test(`
	test("arrays: range", function() {
		equal(_.range(0).join(''), '', 'range with 0 as a first argument generates an empty array');
		equal(_.range(4).join(' '), '0 1 2 3', 'range with a single positive argument generates an array of elements 0,1,2,...,n-1');
		equal(_.range(5, 8).join(' '), '5 6 7', 'range with two arguments a &amp; b, a&lt;b generates an array of elements a,a+1,a+2,...,b-2,b-1');
		equal(_.range(8, 5).join(''), '', 'range with two arguments a &amp; b, b&lt;a generates an empty array');
		equal(_.range(3, 10, 3).join(' '), '3 6 9', 'range with three arguments a &amp; b &amp; c, c &lt; b-a, a &lt; b generates an array of elements a,a+c,a+2c,...,b - (multiplier of a) &lt; c');
		equal(_.range(3, 10, 15).join(''), '3', 'range with three arguments a &amp; b &amp; c, c &gt; b-a, a &lt; b generates an array with a single element, equal to a');
		equal(_.range(12, 7, -2).join(' '), '12 10 8', 'range with three arguments a &amp; b &amp; c, a &gt; b, c &lt; 0 generates an array of elements a,a-c,a-2c and ends with the number not less than b');
		equal(_.range(0, -10, -1).join(' '), '0 -1 -2 -3 -4 -5 -6 -7 -8 -9', 'final example in the Python docs');
	});
	`)
}

func Test_underscoreFunction(t *testing.T) {
	Terst(t)

	test := underscoreTest()

	test(`
	test("functions: bind", function() {
		var context = {name : 'moe'};
		var func = function(arg) { return "name: " + (this.name || arg); };
		var bound = _.bind(func, context);
		equal(bound(), 'name: moe', 'can bind a function to a context');

		bound = _(func).bind(context);
		equal(bound(), 'name: moe', 'can do OO-style binding');

		bound = _.bind(func, null, 'curly');
		equal(bound(), 'name: curly', 'can bind without specifying a context');

		func = function(salutation, name) { return salutation + ': ' + name; };
		func = _.bind(func, this, 'hello');
		equal(func('moe'), 'hello: moe', 'the function was partially applied in advance');

		var func = _.bind(func, this, 'curly');
		equal(func(), 'hello: curly', 'the function was completely applied in advance');

		var func = function(salutation, firstname, lastname) { return salutation + ': ' + firstname + ' ' + lastname; };
		func = _.bind(func, this, 'hello', 'moe', 'curly');
		equal(func(), 'hello: moe curly', 'the function was partially applied in advance and can accept multiple arguments');

		func = function(context, message) { equal(this, context, message); };
		_.bind(func, 0, 0, 'can bind a function to _0_')();
		_.bind(func, '', '', 'can bind a function to an empty string')();
		_.bind(func, false, false, 'can bind a function to _false_')();

		// These tests are only meaningful when using a browser without a native bind function
		// to test this with a modern browser, set underscore's nativeBind to undefined
		var F = function () { return this; };
		var Boundf = _.bind(F, {hello: "moe curly"});
		equal(new Boundf().hello, undefined, "function should not be bound to the context, to comply with ECMAScript 5");
		equal(Boundf().hello, "moe curly", "When called without the new operator, it's OK to be bound to the context");
	});
	`)

	test(`
	test("functions: bindAll", function() {
		var curly = {name : 'curly'}, moe = {
		name    : 'moe',
		getName : function() { return 'name: ' + this.name; },
		sayHi   : function() { return 'hi: ' + this.name; }
		};
		curly.getName = moe.getName;
		_.bindAll(moe, 'getName', 'sayHi');
		curly.sayHi = moe.sayHi;
		equal(curly.getName(), 'name: curly', 'unbound function is bound to current object');
		equal(curly.sayHi(), 'hi: moe', 'bound function is still bound to original object');

		curly = {name : 'curly'};
		moe = {
		name    : 'moe',
		getName : function() { return 'name: ' + this.name; },
		sayHi   : function() { return 'hi: ' + this.name; }
		};
		_.bindAll(moe);
		curly.sayHi = moe.sayHi;
		equal(curly.sayHi(), 'hi: moe', 'calling bindAll with no arguments binds all functions to the object');
	});
	`)

	test(`
	test("functions: memoize", function() {
		var fib = function(n) {
		return n < 2 ? n : fib(n - 1) + fib(n - 2);
		};
		var fastFib = _.memoize(fib);
		equal(fib(10), 55, 'a memoized version of fibonacci produces identical results');
		equal(fastFib(10), 55, 'a memoized version of fibonacci produces identical results');

		var o = function(str) {
		return str;
		};
		var fastO = _.memoize(o);
		equal(o('toString'), 'toString', 'checks hasOwnProperty');
		equal(fastO('toString'), 'toString', 'checks hasOwnProperty');
	});
	`)

// TODO
/*
	asyncTest("functions: delay", 2, function() {
		var delayed = false;
		_.delay(function(){ delayed = true; }, 100);
		setTimeout(function(){ ok(!delayed, "didn't delay the function quite yet"); }, 50);
		setTimeout(function(){ ok(delayed, 'delayed the function'); start(); }, 150);
	});

	asyncTest("functions: defer", 1, function() {
		var deferred = false;
		_.defer(function(bool){ deferred = bool; }, true);
		_.delay(function(){ ok(deferred, "deferred the function"); start(); }, 50);
	});

	asyncTest("functions: throttle", 2, function() {
		var counter = 0;
		var incr = function(){ counter++; };
		var throttledIncr = _.throttle(incr, 100);
		throttledIncr(); throttledIncr(); throttledIncr();
		setTimeout(throttledIncr, 70);
		setTimeout(throttledIncr, 120);
		setTimeout(throttledIncr, 140);
		setTimeout(throttledIncr, 190);
		setTimeout(throttledIncr, 220);
		setTimeout(throttledIncr, 240);
		_.delay(function(){ equal(counter, 1, "incr was called immediately"); }, 30);
		_.delay(function(){ equal(counter, 4, "incr was throttled"); start(); }, 400);
	});

	asyncTest("functions: throttle arguments", 2, function() {
		var value = 0;
		var update = function(val){ value = val; };
		var throttledUpdate = _.throttle(update, 100);
		throttledUpdate(1); throttledUpdate(2); throttledUpdate(3);
		setTimeout(function(){ throttledUpdate(4); }, 120);
		setTimeout(function(){ throttledUpdate(5); }, 140);
		setTimeout(function(){ throttledUpdate(6); }, 250);
		_.delay(function(){ equal(value, 1, "updated to latest value"); }, 40);
		_.delay(function(){ equal(value, 6, "updated to latest value"); start(); }, 400);
	});

	asyncTest("functions: throttle once", 2, function() {
		var counter = 0;
		var incr = function(){ return ++counter; };
		var throttledIncr = _.throttle(incr, 100);
		var result = throttledIncr();
		_.delay(function(){
		equal(result, 1, "throttled functions return their value");
		equal(counter, 1, "incr was called once"); start();
		}, 220);
	});

	asyncTest("functions: throttle twice", 1, function() {
		var counter = 0;
		var incr = function(){ counter++; };
		var throttledIncr = _.throttle(incr, 100);
		throttledIncr(); throttledIncr();
		_.delay(function(){ equal(counter, 2, "incr was called twice"); start(); }, 220);
	});

	asyncTest("functions: debounce", 1, function() {
		var counter = 0;
		var incr = function(){ counter++; };
		var debouncedIncr = _.debounce(incr, 50);
		debouncedIncr(); debouncedIncr(); debouncedIncr();
		setTimeout(debouncedIncr, 30);
		setTimeout(debouncedIncr, 60);
		setTimeout(debouncedIncr, 90);
		setTimeout(debouncedIncr, 120);
		setTimeout(debouncedIncr, 150);
		_.delay(function(){ equal(counter, 1, "incr was debounced"); start(); }, 220);
	});

	asyncTest("functions: debounce asap", 2, function() {
		var counter = 0;
		var incr = function(){ counter++; };
		var debouncedIncr = _.debounce(incr, 50, true);
		debouncedIncr(); debouncedIncr(); debouncedIncr();
		equal(counter, 1, 'incr was called immediately');
		setTimeout(debouncedIncr, 30);
		setTimeout(debouncedIncr, 60);
		setTimeout(debouncedIncr, 90);
		setTimeout(debouncedIncr, 120);
		setTimeout(debouncedIncr, 150);
		_.delay(function(){ equal(counter, 1, "incr was debounced"); start(); }, 220);
	});

	asyncTest("functions: debounce asap recursively", 2, function() {
		var counter = 0;
		var debouncedIncr = _.debounce(function(){
		counter++;
		if (counter < 5) debouncedIncr();
		}, 50, true);
		debouncedIncr();
		equal(counter, 1, 'incr was called immediately');
		_.delay(function(){ equal(counter, 1, "incr was debounced"); start(); }, 70);
	});
*/


	test(`
	test("functions: once", function() {
		var num = 0;
		var increment = _.once(function(){ num++; });
		increment();
		increment();
		equal(num, 1);
	});
	`)

	test(`
	test("functions: wrap", function() {
		var greet = function(name){ return "hi: " + name; };
		var backwards = _.wrap(greet, function(func, name){ return func(name) + ' ' + name.split('').reverse().join(''); });
		equal(backwards('moe'), 'hi: moe eom', 'wrapped the saluation function');

		var inner = function(){ return "Hello "; };
		var obj   = {name : "Moe"};
		obj.hi    = _.wrap(inner, function(fn){ return fn() + this.name; });
		equal(obj.hi(), "Hello Moe");

		var noop    = function(){};
		var wrapped = _.wrap(noop, function(fn){ return Array.prototype.slice.call(arguments, 0); });
		var ret     = wrapped(['whats', 'your'], 'vector', 'victor');
		deepEqual(ret, [noop, ['whats', 'your'], 'vector', 'victor']);
	});
	`)

	test(`
	test("functions: compose", function() {
		var greet = function(name){ return "hi: " + name; };
		var exclaim = function(sentence){ return sentence + '!'; };
		var composed = _.compose(exclaim, greet);
		equal(composed('moe'), 'hi: moe!', 'can compose a function that takes another');

		composed = _.compose(greet, exclaim);
		equal(composed('moe'), 'hi: moe!', 'in this case, the functions are also commutative');
	});
	`)

	test(`
	test("functions: after", function() {
		var testAfter = function(afterAmount, timesCalled) {
		var afterCalled = 0;
		var after = _.after(afterAmount, function() {
			afterCalled++;
		});
		while (timesCalled--) after();
		return afterCalled;
		};

		equal(testAfter(5, 5), 1, "after(N) should fire after being called N times");
		equal(testAfter(5, 4), 0, "after(N) should not fire unless called N times");
		equal(testAfter(0, 0), 1, "after(0) should fire immediately");
	});
	`)
}

func Test_underscoreChain(t *testing.T) {
	Terst(t)

	test := underscoreTest()

	test(`
	test("chaining: map/flatten/reduce", function() {
		var lyrics = [
		"I'm a lumberjack and I'm okay",
		"I sleep all night and I work all day",
		"He's a lumberjack and he's okay",
		"He sleeps all night and he works all day"
		];
		var counts = _(lyrics).chain()
		.map(function(line) { return line.split(''); })
		.flatten()
		.reduce(function(hash, l) {
			hash[l] = hash[l] || 0;
			hash[l]++;
			return hash;
		}, {}).value();
		ok(counts['a'] == 16 && counts['e'] == 10, 'counted all the letters in the song');
	});
	`)

	test(`
	test("chaining: select/reject/sortBy", function() {
		var numbers = [1,2,3,4,5,6,7,8,9,10];
		numbers = _(numbers).chain().select(function(n) {
		return n % 2 == 0;
		}).reject(function(n) {
		return n % 4 == 0;
		}).sortBy(function(n) {
		return -n;
		}).value();
		equal(numbers.join(', '), "10, 6, 2", "filtered and reversed the numbers");
	});
	`)

	test(`
	test("chaining: select/reject/sortBy in functional style", function() {
		var numbers = [1,2,3,4,5,6,7,8,9,10];
		numbers = _.chain(numbers).select(function(n) {
		return n % 2 == 0;
		}).reject(function(n) {
		return n % 4 == 0;
		}).sortBy(function(n) {
		return -n;
		}).value();
		equal(numbers.join(', '), "10, 6, 2", "filtered and reversed the numbers");
	});
	`)

	test(`
	test("chaining: reverse/concat/unshift/pop/map", function() {
		var numbers = [1,2,3,4,5];
		numbers = _(numbers).chain()
		.reverse()
		.concat([5, 5, 5])
		.unshift(17)
		.pop()
		.map(function(n){ return n * 2; })
		.value();
		equal(numbers.join(', '), "34, 10, 8, 6, 4, 2, 10, 10", 'can chain together array functions.');
	});
	`)
}

func Test_underscoreCollection(t *testing.T) {
	Terst(t)

	test := underscoreTest()

	test(`
	test("collections: each", function() {
		_.each([1, 2, 3], function(num, i) {
		equal(num, i + 1, 'each iterators provide value and iteration count');
		});

		var answers = [];
		_.each([1, 2, 3], function(num){ answers.push(num * this.multiplier);}, {multiplier : 5});
		equal(answers.join(', '), '5, 10, 15', 'context object property accessed');

		answers = [];
		_.forEach([1, 2, 3], function(num){ answers.push(num); });
		equal(answers.join(', '), '1, 2, 3', 'aliased as "forEach"');

		answers = [];
		var obj = {one : 1, two : 2, three : 3};
		obj.constructor.prototype.four = 4;
		_.each(obj, function(value, key){ answers.push(key); });
		equal(answers.sort().join(", "), 'one, three, two', 'iterating over objects works, and ignores the object prototype.');
		delete obj.constructor.prototype.four;

		answer = null;
		_.each([1, 2, 3], function(num, index, arr){ if (_.include(arr, num)) answer = true; });
		ok(answer, 'can reference the original collection from inside the iterator');

		answers = 0;
		_.each(null, function(){ ++answers; });
		equal(answers, 0, 'handles a null properly');
	});
	`)

	test(`
	test('collections: map', function() {
		var doubled = _.map([1, 2, 3], function(num){ return num * 2; });
		equal(doubled.join(', '), '2, 4, 6', 'doubled numbers');

		doubled = _.collect([1, 2, 3], function(num){ return num * 2; });
		equal(doubled.join(', '), '2, 4, 6', 'aliased as "collect"');

		var tripled = _.map([1, 2, 3], function(num){ return num * this.multiplier; }, {multiplier : 3});
		equal(tripled.join(', '), '3, 6, 9', 'tripled numbers with context');

		var doubled = _([1, 2, 3]).map(function(num){ return num * 2; });
		equal(doubled.join(', '), '2, 4, 6', 'OO-style doubled numbers');

// TODO
		/*
		var ids = _.map($('#map-test').children(), function(n){ return n.id; });
		deepEqual(ids, ['id1', 'id2'], 'Can use collection methods on nodeLists.');

		var ids = _.map(document.images, function(n){ return n.id; });
		ok(ids[0] == 'chart_image', 'can use collection methods on HTMLCollections');
		*/

		var ifnull = _.map(null, function(){});
		ok(_.isArray(ifnull) && ifnull.length === 0, 'handles a null properly');
	});
	`)

	test(`
	test('collections: reduce', function() {
		var sum = _.reduce([1, 2, 3], function(sum, num){ return sum + num; }, 0);
		equal(sum, 6, 'can sum up an array');

		var context = {multiplier : 3};
		sum = _.reduce([1, 2, 3], function(sum, num){ return sum + num * this.multiplier; }, 0, context);
		equal(sum, 18, 'can reduce with a context object');

		sum = _.inject([1, 2, 3], function(sum, num){ return sum + num; }, 0);
		equal(sum, 6, 'aliased as "inject"');

		sum = _([1, 2, 3]).reduce(function(sum, num){ return sum + num; }, 0);
		equal(sum, 6, 'OO-style reduce');

		var sum = _.reduce([1, 2, 3], function(sum, num){ return sum + num; });
		equal(sum, 6, 'default initial value');

		var ifnull;
		try {
		_.reduce(null, function(){});
		} catch (ex) {
		ifnull = ex;
		}
		ok(ifnull instanceof TypeError, 'handles a null (without inital value) properly');

		ok(_.reduce(null, function(){}, 138) === 138, 'handles a null (with initial value) properly');
		equal(_.reduce([], function(){}, undefined), undefined, 'undefined can be passed as a special case');
		raises(function() { _.reduce([], function(){}); }, TypeError, 'throws an error for empty arrays with no initial value');
	});
	`)

	test(`
	test('collections: reduceRight', function() {
		var list = _.reduceRight(["foo", "bar", "baz"], function(memo, str){ return memo + str; }, '');
		equal(list, 'bazbarfoo', 'can perform right folds');

		var list = _.foldr(["foo", "bar", "baz"], function(memo, str){ return memo + str; }, '');
		equal(list, 'bazbarfoo', 'aliased as "foldr"');

		var list = _.foldr(["foo", "bar", "baz"], function(memo, str){ return memo + str; });
		equal(list, 'bazbarfoo', 'default initial value');

		var ifnull;
		try {
		_.reduceRight(null, function(){});
		} catch (ex) {
		ifnull = ex;
		}
		ok(ifnull instanceof TypeError, 'handles a null (without inital value) properly');

		ok(_.reduceRight(null, function(){}, 138) === 138, 'handles a null (with initial value) properly');

		equal(_.reduceRight([], function(){}, undefined), undefined, 'undefined can be passed as a special case');
		raises(function() { _.reduceRight([], function(){}); }, TypeError, 'throws an error for empty arrays with no initial value');
	});
	`)

	test(`
	test('collections: find', function() {
		var array = [1, 2, 3, 4];
		strictEqual(_.find(array, function(n) { return n > 2; }), 3, 'should return first found _value_');
		strictEqual(_.find(array, function() { return false; }), void 0, 'should return _undefined_ if _value_ is not found');
	});
	`)

	test(`
	test('collections: detect', function() {
		var result = _.detect([1, 2, 3], function(num){ return num * 2 == 4; });
		equal(result, 2, 'found the first "2" and broke the loop');
	});
	`)

	test(`
	test('collections: select', function() {
		var evens = _.select([1, 2, 3, 4, 5, 6], function(num){ return num % 2 == 0; });
		equal(evens.join(', '), '2, 4, 6', 'selected each even number');

		evens = _.filter([1, 2, 3, 4, 5, 6], function(num){ return num % 2 == 0; });
		equal(evens.join(', '), '2, 4, 6', 'aliased as "filter"');
	});
	`)

	test(`
	test('collections: reject', function() {
		var odds = _.reject([1, 2, 3, 4, 5, 6], function(num){ return num % 2 == 0; });
		equal(odds.join(', '), '1, 3, 5', 'rejected each even number');
	});
	`)

	test(`
	test('collections: all', function() {
		ok(_.all([], _.identity), 'the empty set');
		ok(_.all([true, true, true], _.identity), 'all true values');
		ok(!_.all([true, false, true], _.identity), 'one false value');
		ok(_.all([0, 10, 28], function(num){ return num % 2 == 0; }), 'even numbers');
		ok(!_.all([0, 11, 28], function(num){ return num % 2 == 0; }), 'an odd number');
		ok(_.all([1], _.identity) === true, 'cast to boolean - true');
		ok(_.all([0], _.identity) === false, 'cast to boolean - false');
		ok(_.every([true, true, true], _.identity), 'aliased as "every"');
	});
	`)

	test(`
	test('collections: any', function() {
		var nativeSome = Array.prototype.some;
		Array.prototype.some = null;
		ok(!_.any([]), 'the empty set');
		ok(!_.any([false, false, false]), 'all false values');
		ok(_.any([false, false, true]), 'one true value');
		ok(_.any([null, 0, 'yes', false]), 'a string');
		ok(!_.any([null, 0, '', false]), 'falsy values');
		ok(!_.any([1, 11, 29], function(num){ return num % 2 == 0; }), 'all odd numbers');
		ok(_.any([1, 10, 29], function(num){ return num % 2 == 0; }), 'an even number');
		ok(_.any([1], _.identity) === true, 'cast to boolean - true');
		ok(_.any([0], _.identity) === false, 'cast to boolean - false');
		ok(_.some([false, false, true]), 'aliased as "some"');
		Array.prototype.some = nativeSome;
	});
	`)

	test(`
	test('collections: include', function() {
		ok(_.include([1,2,3], 2), 'two is in the array');
		ok(!_.include([1,3,9], 2), 'two is not in the array');
		ok(_.contains({moe:1, larry:3, curly:9}, 3) === true, '_.include on objects checks their values');
		ok(_([1,2,3]).include(2), 'OO-style include');
	});
	`)

	test(`
	test('collections: invoke', function() {
		var list = [[5, 1, 7], [3, 2, 1]];
		var result = _.invoke(list, 'sort');
		equal(result[0].join(', '), '1, 5, 7', 'first array sorted');
		equal(result[1].join(', '), '1, 2, 3', 'second array sorted');
	});
	`)

	test(`
	test('collections: invoke w/ function reference', function() {
		var list = [[5, 1, 7], [3, 2, 1]];
		var result = _.invoke(list, Array.prototype.sort);
		equal(result[0].join(', '), '1, 5, 7', 'first array sorted');
		equal(result[1].join(', '), '1, 2, 3', 'second array sorted');
	});
	`)

	test(`
	// Relevant when using ClojureScript
	test('collections: invoke when strings have a call method', function() {
		String.prototype.call = function() {
		return 42;
		};
		var list = [[5, 1, 7], [3, 2, 1]];
		var s = "foo";
		equal(s.call(), 42, "call function exists");
		var result = _.invoke(list, 'sort');
		equal(result[0].join(', '), '1, 5, 7', 'first array sorted');
		equal(result[1].join(', '), '1, 2, 3', 'second array sorted');
		delete String.prototype.call;
		equal(s.call, undefined, "call function removed");
	});
	`)

	test(`
	test('collections: pluck', function() {
		var people = [{name : 'moe', age : 30}, {name : 'curly', age : 50}];
		equal(_.pluck(people, 'name').join(', '), 'moe, curly', 'pulls names out of objects');
	});
	`)

// TODO
	if true {
	test(`
	test('collections: max', function() {
		equal(3, _.max([1, 2, 3]), 'can perform a regular Math.max');

		var neg = _.max([1, 2, 3], function(num){ return -num; });
		equal(neg, 1, 'can perform a computation-based max');

		equal(-Infinity, _.max({}), 'Maximum value of an empty object');
		equal(-Infinity, _.max([]), 'Maximum value of an empty array');

// TODO A slo-o-o-o-w test
		if (false) {
			equal(299999, _.max(_.range(1,300000)), "Maximum value of a too-big array");
		}
	});
	`)

	test(`
	test('collections: min', function() {
		equal(1, _.min([1, 2, 3]), 'can perform a regular Math.min');

		var neg = _.min([1, 2, 3], function(num){ return -num; });
		equal(neg, 3, 'can perform a computation-based min');

		equal(Infinity, _.min({}), 'Minimum value of an empty object');
		equal(Infinity, _.min([]), 'Minimum value of an empty array');

		var now = new Date(9999999999);
		var then = new Date(0);
		equal(_.min([now, then]), then);

// TODO A slo-o-o-o-w test
		if (false) {
			equal(1, _.min(_.range(1,300000)), "Minimum value of a too-big array");
		}
	});
	`)
	}

	test(`
	test('collections: sortBy', function() {
		var people = [{name : 'curly', age : 50}, {name : 'moe', age : 30}];
		people = _.sortBy(people, function(person){ return person.age; });
		equal(_.pluck(people, 'name').join(', '), 'moe, curly', 'stooges sorted by age');

		var list = [undefined, 4, 1, undefined, 3, 2];
		equal(_.sortBy(list, _.identity).join(','), '1,2,3,4,,', 'sortBy with undefined values');

		var list = ["one", "two", "three", "four", "five"];
		var sorted = _.sortBy(list, 'length');
		equal(sorted.join(' '), 'two one five four three', 'sorted by length');
	});
	`)

	test(`
	test('collections: groupBy', function() {
		var parity = _.groupBy([1, 2, 3, 4, 5, 6], function(num){ return num % 2; });
		ok('0' in parity && '1' in parity, 'created a group for each value');
		equal(parity[0].join(', '), '2, 4, 6', 'put each even number in the right group');

		var list = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"];
		var grouped = _.groupBy(list, 'length');
		equal(grouped['3'].join(' '), 'one two six ten');
		equal(grouped['4'].join(' '), 'four five nine');
		equal(grouped['5'].join(' '), 'three seven eight');
	});
	`)

	test(`
	test('collections: countBy', function() {
		var parity = _.countBy([1, 2, 3, 4, 5], function(num){ return num % 2 == 0; });
		equal(parity['true'], 2);
		equal(parity['false'], 3);

		var list = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"];
		var grouped = _.countBy(list, 'length');
		equal(grouped['3'], 4);
		equal(grouped['4'], 3);
		equal(grouped['5'], 3);
	});
	`)

	test(`
	test('collections: sortedIndex', function() {
		var numbers = [10, 20, 30, 40, 50], num = 35;
		var indexForNum = _.sortedIndex(numbers, num);
		equal(indexForNum, 3, '35 should be inserted at index 3');

		var indexFor30 = _.sortedIndex(numbers, 30);
		equal(indexFor30, 2, '30 should be inserted at index 2');
	});
	`)

	test(`
	test('collections: shuffle', function() {
		var numbers = _.range(10);
		var shuffled = _.shuffle(numbers).sort();
		return
		notStrictEqual(numbers, shuffled, 'original object is unmodified');
		equal(shuffled.join(','), numbers.join(','), 'contains the same members before and after shuffle');
	});
	`)

	test(`
	test('collections: toArray', function() {
		ok(!_.isArray(arguments), 'arguments object is not an array');
		ok(_.isArray(_.toArray(arguments)), 'arguments object converted into array');
		var a = [1,2,3];
		ok(_.toArray(a) !== a, 'array is cloned');
		equal(_.toArray(a).join(', '), '1, 2, 3', 'cloned array contains same elements');

		var numbers = _.toArray({one : 1, two : 2, three : 3});
		equal(numbers.sort().join(', '), '1, 2, 3', 'object flattened into array');

		var objectWithToArrayFunction = {toArray: function() {
			return [1, 2, 3];
		}};
		equal(_.toArray(objectWithToArrayFunction).sort().join(', '), '1, 2, 3', 'toArray method used if present');

		var objectWithToArrayValue = {toArray: 1};
		equal(_.toArray(objectWithToArrayValue).join(', '), '1', 'toArray property ignored if not a function');
	});
	`)

	test(`
	test('collections: size', function() {
		equal(_.size({one : 1, two : 2, three : 3}), 3, 'can compute the size of an object');
		equal(_.size([1, 2, 3]), 3, 'can compute the size of an array');
	});
	`)
}

func Test_underscoreUtility(t *testing.T) {
	Terst(t)

	test := underscoreTest()

	test(`
	test("utility: identity", function() {
		var moe = {name : 'moe'};
		equal(_.identity(moe), moe, 'moe is the same as his identity');
	});
	`)

	test(`
	test("utility: uniqueId", function() {
		var ids = [], i = 0;
		while(i++ < 100) ids.push(_.uniqueId());
		equal(_.uniq(ids).length, ids.length, 'can generate a globally-unique stream of ids');
	});
	`)

	test(`
	test("utility: times", function() {
		var vals = [];
		_.times(3, function (i) { vals.push(i); });
		ok(_.isEqual(vals, [0,1,2]), "is 0 indexed");
		//
		vals = [];
		_(3).times(function (i) { vals.push(i); });
		ok(_.isEqual(vals, [0,1,2]), "works as a wrapper");
	});
	`)

	test(`
	test("utility: mixin", function() {
		_.mixin({
		myReverse: function(string) {
			return string.split('').reverse().join('');
		}
		});
		equal(_.myReverse('panacea'), 'aecanap', 'mixed in a function to _');
		equal(_('champ').myReverse(), 'pmahc', 'mixed in a function to the OOP wrapper');
	});
	`)

	test(`
	test("utility: _.escape", function() {
		equal(_.escape("Curly & Moe"), "Curly &amp; Moe");
		equal(_.escape("Curly &amp; Moe"), "Curly &amp;amp; Moe");
	});
	`)

	test(`
	var templateSettings
	`)

// TODO
	test(`
	templateSettings = _.clone(_.templateSettings);

	test("utility: template", function() {
		var basicTemplate = _.template("<%= thing %> is gettin' on my noives!");
		var result = basicTemplate({thing : 'This'});
		equal(result, "This is gettin' on my noives!", 'can do basic attribute interpolation');

		var sansSemicolonTemplate = _.template("A <% this %> B");
		equal(sansSemicolonTemplate(), "A  B");

		var backslashTemplate = _.template("<%= thing %> is \\ridanculous");
		equal(backslashTemplate({thing: 'This'}), "This is \\ridanculous");

		var escapeTemplate = _.template('<%= a ? "checked=\\"checked\\"" : "" %>');
		equal(escapeTemplate({a: true}), 'checked="checked"', 'can handle slash escapes in interpolations.');

		var fancyTemplate = _.template("<ul><% \
		for (key in people) { \
		%><li><%= people[key] %></li><% } %></ul>");
// TODO
		/*
		result = fancyTemplate({people : {moe : "Moe", larry : "Larry", curly : "Curly"}});
		equal(result, "<ul><li>Moe</li><li>Larry</li><li>Curly</li></ul>", 'can run arbitrary javascript in templates');

		var escapedCharsInJavascriptTemplate = _.template("<ul><% _.each(numbers.split('\\n'), function(item) { %><li><%= item %></li><% }) %></ul>");
		result = escapedCharsInJavascriptTemplate({numbers: "one\ntwo\nthree\nfour"});
		equal(result, "<ul><li>one</li><li>two</li><li>three</li><li>four</li></ul>", 'Can use escaped characters (e.g. \\n) in Javascript');

		var namespaceCollisionTemplate = _.template("<%= pageCount %> <%= thumbnails[pageCount] %> <% _.each(thumbnails, function(p) { %><div class=\"thumbnail\" rel=\"<%= p %>\"></div><% }); %>");
		result = namespaceCollisionTemplate({
		pageCount: 3,
		thumbnails: {
			1: "p1-thumbnail.gif",
			2: "p2-thumbnail.gif",
			3: "p3-thumbnail.gif"
		}
		});
		equal(result, "3 p3-thumbnail.gif <div class=\"thumbnail\" rel=\"p1-thumbnail.gif\"></div><div class=\"thumbnail\" rel=\"p2-thumbnail.gif\"></div><div class=\"thumbnail\" rel=\"p3-thumbnail.gif\"></div>");
		*/

		var noInterpolateTemplate = _.template("<div><p>Just some text. Hey, I know this is silly but it aids consistency.</p></div>");
		result = noInterpolateTemplate();
		equal(result, "<div><p>Just some text. Hey, I know this is silly but it aids consistency.</p></div>");

		var quoteTemplate = _.template("It's its, not it's");
		equal(quoteTemplate({}), "It's its, not it's");

		var quoteInStatementAndBody = _.template("<%\
		if(foo == 'bar'){ \
		%>Statement quotes and 'quotes'.<% } %>");
		equal(quoteInStatementAndBody({foo: "bar"}), "Statement quotes and 'quotes'.");

		var withnewlinesAndTabs = _.template('This\n\t\tis: <%= x %>.\n\tok.\nend.');
		equal(withnewlinesAndTabs({x: 'that'}), 'This\n\t\tis: that.\n\tok.\nend.');

		var template = _.template("<i><%- value %></i>");
		var result = template({value: "<script>"});
		equal(result, '<i>&lt;script&gt;</i>');

		var stooge = {
		name: "Moe",
		template: _.template("I'm <%= this.name %>")
		};
		equal(stooge.template(), "I'm Moe");

		/*
		if (!$.browser.msie) {
		var fromHTML = _.template($('#template').html());
		equal(fromHTML({data : 12345}).replace(/\s/g, ''), '<li>24690</li>');
		}
		*/

		_.templateSettings = {
		evaluate    : /\{\{([\s\S]+?)\}\}/g,
		interpolate : /\{\{=([\s\S]+?)\}\}/g
		};

		var custom = _.template("<ul>{{ for (key in people) { }}<li>{{= people[key] }}</li>{{ } }}</ul>");
// TODO
/*
		result = custom({people : {moe : "Moe", larry : "Larry", curly : "Curly"}});
		equal(result, "<ul><li>Moe</li><li>Larry</li><li>Curly</li></ul>", 'can run arbitrary javascript in templates');
*/

		var customQuote = _.template("It's its, not it's");
		equal(customQuote({}), "It's its, not it's");

		var quoteInStatementAndBody = _.template("{{ if(foo == 'bar'){ }}Statement quotes and 'quotes'.{{ } }}");
		equal(quoteInStatementAndBody({foo: "bar"}), "Statement quotes and 'quotes'.");

		_.templateSettings = {
		evaluate    : /<\?([\s\S]+?)\?>/g,
		interpolate : /<\?=([\s\S]+?)\?>/g
		};

		var customWithSpecialChars = _.template("<ul><? for (key in people) { ?><li><?= people[key] ?></li><? } ?></ul>");
// TODO
/*
		result = customWithSpecialChars({people : {moe : "Moe", larry : "Larry", curly : "Curly"}});
//		equal(result, "<ul><li>Moe</li><li>Larry</li><li>Curly</li></ul>", 'can run arbitrary javascript in templates');
*/

		var customWithSpecialCharsQuote = _.template("It's its, not it's");
		equal(customWithSpecialCharsQuote({}), "It's its, not it's");

		var quoteInStatementAndBody = _.template("<? if(foo == 'bar'){ ?>Statement quotes and 'quotes'.<? } ?>");
		equal(quoteInStatementAndBody({foo: "bar"}), "Statement quotes and 'quotes'.");

		_.templateSettings = {
		interpolate : /\{\{(.+?)\}\}/g
		};

		var mustache = _.template("Hello {{planet}}!");
		equal(mustache({planet : "World"}), "Hello World!", "can mimic mustache.js");

		var templateWithNull = _.template("a null undefined {{planet}}");
		equal(templateWithNull({planet : "world"}), "a null undefined world", "can handle missing escape and evaluate settings");
	});

	 _.templateSettings = templateSettings;
	`)

	test(`
	test('_.template handles \\u2028 & \\u2029', function() {
		var tmpl = _.template('<p>\u2028<%= "\\u2028\\u2029" %>\u2029</p>');
		strictEqual(tmpl(), '<p>\u2028\u2028\u2029\u2029</p>');
	});
	`)

	test(`
	test('result calls functions and returns primitives', function() {
		var obj = {w: '', x: 'x', y: function(){ return this.x; }};
		strictEqual(_.result(obj, 'w'), '');
		strictEqual(_.result(obj, 'x'), 'x');
		strictEqual(_.result(obj, 'y'), 'x');
		strictEqual(_.result(obj, 'z'), undefined);
		strictEqual(_.result(null, 'x'), null);
	});
	`)

	test(`
	templateSettings = _.clone(_.templateSettings);

	test('_.templateSettings.variable', function() {
		var s = '<%=data.x%>';
		var data = {x: 'x'};
		strictEqual(_.template(s, data, {variable: 'data'}), 'x');
		_.templateSettings.variable = 'data';
		strictEqual(_.template(s)(data), 'x');
	});

	 _.templateSettings = templateSettings;
	`)

	test(`
	test('#547 - _.templateSettings is unchanged by custom settings.', function() {
		ok(!_.templateSettings.variable);
		_.template('', {}, {variable: 'x'});
		ok(!_.templateSettings.variable);
	});
	`)

	test(`
	test('#556 - undefined template variables.', function() {
		var template = _.template('<%=x%>');
		strictEqual(template({x: null}), '');
		strictEqual(template({x: undefined}), '');

		var templateEscaped = _.template('<%-x%>');
		strictEqual(templateEscaped({x: null}), '');
		strictEqual(templateEscaped({x: undefined}), '');

		var templateWithProperty = _.template('<%=x.foo%>');
		strictEqual(templateWithProperty({x: {} }), '');
		strictEqual(templateWithProperty({x: {} }), '');

		var templateWithPropertyEscaped = _.template('<%-x.foo%>');
		strictEqual(templateWithPropertyEscaped({x: {} }), '');
		strictEqual(templateWithPropertyEscaped({x: {} }), '');
	});
	`)

	// This may behave better with native go iterator, rather
	// than using JavaScript via test(..., 2, ...)
	test(`
	test('interpolate evaluates code only once.', 2, function() {
		var count = 0;
		var template = _.template('<%= f() %>');
		template({f: function(){ ok(!(count++)); }});

		var countEscaped = 0;
		var templateEscaped = _.template('<%- f() %>');
		templateEscaped({f: function(){ ok(!(countEscaped++)); }});
	});
	`)
}
