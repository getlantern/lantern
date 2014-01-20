package otto

import (
	. "./terst"
	"fmt"
	"regexp"
	"strings"
	"testing"
)

var beforeAfterSeparator_Regexp = regexp.MustCompile(`(?m)^[ \t]*---$`)

func parserTestNormalizeWant(want string) string {
	index := beforeAfterSeparator_Regexp.FindAllStringIndex(want, -1)
	if index != nil && len(index) > 0 {
		lastIndex := index[len(index)-1]
		want = want[lastIndex[1]+1:]
	}
	want = strings.TrimSpace(want)
	normal := ""
	aSpace := false
	inQuote := false
	ignoreNext := false
	for _, rune := range want {
		if inQuote {
			if !ignoreNext {
				switch rune {
				case '"':
					inQuote = false
				case '\\':
					ignoreNext = true
				case '\n':
					inQuote = false
					aSpace = true
					continue
				}
			} else {
				ignoreNext = false
			}
		} else {
			switch rune {
			case ' ', '\t', '\n':
				aSpace = true
				continue
			case '"':
				inQuote = true
			}
		}
		if aSpace {
			normal += " "
			aSpace = false
		}
		normal += string(rune)
	}
	return normal
}

var errorOptionalLine_Regexp = regexp.MustCompile(` (-):[\d-]+:[\d-]+$`)
var errorOptionalColumn_Regexp = regexp.MustCompile(` [\d-]+:(-):[\d-]+$`)
var errorOptionalIndex_Regexp = regexp.MustCompile(` [\d-]+:[\d-]+:(-)$`)

func parserTest(sourceWant ...string) {
	source, want := "", ""
	if len(sourceWant) == 1 {
		sourceWant := sourceWant[0]
		index := beforeAfterSeparator_Regexp.FindAllStringIndex(sourceWant, -1)
		if index != nil && len(index) > 0 {
			lastIndex := index[len(index)-1]
			source = sourceWant[:lastIndex[0]]
			source = source[:len(source)-1]
			want = sourceWant[lastIndex[1]+1:]
		}
	} else {
		source, want = sourceWant[0], sourceWant[1]
	}

	want = parserTestNormalizeWant(want)
	have, err := parse(source)
	if err == nil {
		Is(have, want)
	} else {
		want := []byte(want)
		switch err := err.(type) {
		case *_syntaxError:
			if match := errorOptionalLine_Regexp.FindSubmatchIndex(want); match != nil {
				want = append(want[:match[2]], append([]byte(fmt.Sprintf("%d", err.Line)), want[match[3]:]...)...)
			}
			if match := errorOptionalColumn_Regexp.FindSubmatchIndex(want); match != nil {
				want = append(want[:match[2]], append([]byte(fmt.Sprintf("%d", err.Column)), want[match[3]:]...)...)
			}
			if match := errorOptionalIndex_Regexp.FindSubmatchIndex(want); match != nil {
				want = append(want[:match[2]], append([]byte(fmt.Sprintf("%d", err.Character)), want[match[3]:]...)...)
			}
			Is(fmt.Sprintf("%s %d:%d:%d", err.Message, err.Line, err.Column, err.Character), string(want))
			// Line:Column:Character
		default:
			Is(fmt.Sprintf("%v", err), string(want))
		}
	}
}

func TestParseSuccess(t *testing.T) {
	Terst(t)

	test := parserTest

	test(`
	xyzzy
	---
	{ @ xyzzy }
	`)

	test(`
	"Nothing ha    ppens."
	---
	{ @ "Nothing ha    ppens." }
	`)

	node := mustParse("xyzzy")
	Is(node, "{ @ xyzzy }")
	Is(node.Body[0].(*_identifierNode).Value, "xyzzy")

	node = mustParse("1")
	Is(node, "{ @ 1 }")
	Is(node.Body[0].(*_valueNode).Value, "1")

	node = mustParse("\"Xyzzy\"")
	Is(node, "{ @ \"Xyzzy\" }")
	Is(node.Body[0].(*_valueNode).Value, "Xyzzy")

	test(`
	xyzzy = 1
	---
	{ @ { = xyzzy 1 } }
	`)

	test(`
	xyzzy = 1 + 2 * 3
	---
	{ @ { = xyzzy { + 1 { * 2 3 } } } }
	`)

	test(`
	xyzzy = 1 + 2 * 3 + 4
	---
	{ @ { = xyzzy { + { + 1 { * 2 3 } } 4 } } }
	`)

	test(`
	xyzzy = 1 + 2 * 3 + 4; 1 + 1
	---
	{ @ { = xyzzy { + { + 1 { * 2 3 } } 4 } } { + 1 1 } }
	`)

	test(`
	xyzzy = test
	---
	{ @ { = xyzzy test } }
	`)

	test(`
	xyzzy = test(1 + 2)
	---
	{ @ { = xyzzy { <call> test { + 1 2 } } } }
	`)

	test(`
	xyzzy = test(1 + 2, 3 * 4)
	---
	{ @ { = xyzzy { <call> test { + 1 2 } { * 3 4 } } } }
	`)

	test(`
	xyzzy = function() {}
	---
	{ @ { = xyzzy { <function> _ } } }
	`)

	test(`
	xyzzy = function() { 1 + 1 }
	---
	{ @ { = xyzzy { <function> { + 1 1 } } } }
	`)

	test(`
	xyzzy = function() { return 1 + 1 }
	---
	{ @ { = xyzzy { <function> { <return> { + 1 1 } } } } }
	`)

	test(`
	xyzzy = function() { return 1 }
	---
	{ @ { = xyzzy { <function> { <return> 1 } } } }
	`)

	test(`
	xyzzy = function() { return apple + 1 }
	---
	{ @ { = xyzzy { <function> { <return> { + apple 1 } } } } }
	`)

	test(`
	if (1) apple
	else banana
	---
	{ @ { <if> 1 apple banana } }
	`)

	test(`
	if (1) { apple } else banana
	---
	{ @ { <if> 1 { apple } banana } }
	`)

	test(`
	if (1) { apple } else { banana }
	---
	{ @
		{ <if> 1
			{ apple }
			{ banana }
		}
	}
	`)

	test(`
	do apple
	while (1 + 1)
	---
	{ @ { <do-while> { + 1 1 } { apple } } }
	`)

	test(`
	while (1 + 1) apple
	---
	{ @ { <while> { + 1 1 } { apple } } }
	`)

	test(`
	do apple; while (1 + 1)
	banana
	---
	{ @ { <do-while> { + 1 1 } { apple } } banana }
	`)

	test(`
	do while (1 + 1) banana; while (1 - 1)
	---
	{ @ { <do-while> { - 1 1 } { { <while> { + 1 1 } { banana } } } } }
	`)

	test(`
	{}
	---
	{ @ {} }
	`)

	test(`
	if (1 + 1) {}
	---
	{ @ { <if> { + 1 1 } {} } }
	`)

	test(`
	var result64
	=
	64
	, result10 =
	10
	---
	{ @ { <var> = result64 64 } { <var> = result10 10 } }
	`)

	test(`
	l0:
	while (1 + 1) {
		banana
	}
	---
	{ @ { <while:l0> { + 1 1 } { banana } } }
	`)

	test(`
	l0:
	result = 0
	l1:
	l0:
	while (1 + 1) {
		banana
	}
	---
	{ @ { = result 0 } { <while:l0:l1> { + 1 1 } { banana } } }
	`)

	test(`
	l0:
	do {
		banana
	} while (1 + 1)
	---
	{ @ { <do-while:l0> { + 1 1 } { banana } } }
	`)

	test(`
	apple = 0
	banana = 1
	while (apple) {
		apple = 2
		if (0) {
		}
		banana = 3
	}
	---
	{ @ { = apple 0 } { = banana 1 } { <while> apple { { = apple 2 } { <if> 0 {} } { = banana 3 } } } }
	`)

	test(`
	with 1 + 1 {
		apple
	}
	---
	{ @ { <with> { + 1 1 } { apple } } }
	`)

	test(`
	with 1 + 1
	apple
	---
	{ @ { <with> { + 1 1 } apple } }
	`)

	test(`
	if (1) {
		result = 1
	}
	else {
		result = 0
	}
	---
	{ @ { <if> 1 { { = result 1 } } { { = result 0 } } } }
	`)

	test(`
	with 1 + 1;
	---
	{ @ { <with> { + 1 1 } ; } }
	`)

	test(`
	if (1)
	;
	else { }
	---
	{ @ { <if> 1 ; {} } }
	`)

	test(`
	while (true) {
		continue
		xyzzy
	}
	---
	{ @ { <while> true { <continue:> xyzzy } } }
	`)

	test(`
	try {
		result = 1
	}
	finally {
		result = 2
	}
	---
	{ @ { <try> { { = result 1 } } <finally> { { = result 2 } } </try> } }
	`)

	test(`
	try {
		result = 1
	}
	catch (xyzzy) {
	}
	finally {
		result = 2
	}
	---
	{ @ { <try> { { = result 1 } } <catch> xyzzy {} <finally> { { = result 2 } } </try> } }
	`)

	test(`
		try {
			result = 1
		}
		catch (xyzzy) {
		}
	---
	{ @ { <try> { { = result 1 } } <catch> xyzzy {} </try> } }
	`)

	test(`
	switch (0 + 0) {
	}
	---
	{ @ { <switch> { + 0 0 } _ } }
	`)

	test(`
	switch (0 + 0) {
	case 1:
	default:
	}
	---
	{ @ { <switch> { + 0 0 } { <case> 1 _ } { <default> _ } } }
	`)

	test(`
	for (;;) {
	}
	---
	{ @ { <for> ; ; ; {} } }
	`)

	test(`
	result = apple[0]
	---
	{ @ { = result { [ apple 0 } } }
	`)

	test(`
	result = apple.banana
	---
	{ @ { = result { . apple banana } } }
	`)

	test(`
	result = { apple: banana }
	---
	{ @ { = result {[ { apple: banana } ]} } }
	`)

	test(`
	result = { apple: banana, 0: 1 }
	---
	{ @ { = result {[ { apple: banana } { 0: 1 } ]} } }
	`)

	test(`
	result = { apple: banana, 0: 1, cherry: {} }
	---
	{ @ { = result {[ { apple: banana } { 0: 1 } { cherry: {[]} } ]} } }
	`)

	test(`
	result = []
	---
	{ @ { = result [] } }
	`)

	test(`
	result = [ apple, banana, 0, 1 ]
	---
	{ @ { = result [ apple banana 0 1 ] } }
	`)

	test(`
	result = 0
	++result
	---
	{ @ { = result 0 } { ++= result } }
	`)

	test(`
	result = 0
	result++
	---
	{ @ { = result 0 } { =++ result } }
	`)

	test(`
	result = 0
	result++
	result
	++result
	---
	{ @ { = result 0 } { =++ result } result { ++= result } }
	`)

	test(`
	result = abc && def || ghi && jkl
	---
	{ @ { = result { || { && abc def } { && ghi jkl } } } }
	`)

	test(`
	result = abc & def - 1 | ghi ^ jkl & mno ^ pqr + 1
	---
	{ @ { = result { | { & abc { - def 1 } } { ^ { ^ ghi { & jkl mno } } { + pqr 1 } } } } }
	`)

	test(`
	result = 0 << 1 >> 2 >>> 3
	---
	{ @ { = result { >>> { >> { << 0 1 } 2 } 3 } } }
	`)

	test(`
	result = 0 instanceof 1
	---
	{ @ { = result { instanceof 0 1 } } }
	`)

	test(`
	result = 0 in 1
	---
	{ @ { = result { in 0 1 } } }
	`)

	test(`
	for (abc in def) {
	}
	---
	{ @ { <for-in> abc in def {} } }
	`)

	test(`
	abc = new String
	def = new Object(0 + 1, 2, 3)
	ghi = new Function()
	---
	{ @ { = abc { <new> String _ } } { = def { <new> Object { + 0 1 } 2 3 } } { = ghi { <new> Function _ } } }
	`)

	test(`
	abc = true ? 1 : 0
	---
	{ @ { = abc { ?: true 1 0 } } }
	`)

	test(`
	abc = [].toString()
	---
	{ @ { = abc { <call> { . [] toString } _ } } }
	`)

	test(`
	Array.prototype.join = function() {}
	---
	{ @ { = { . { . Array prototype } join } { <function> _ } } }
	`)

	test(`
	/abc/ig
	---
	{ @ { /abc/ig } }
	`)

	test(`
	""+/abc/g
	---
	{ @ { + "" { /abc/g } } }
	`)

	test(`
	(function(){})()
	---
	{ @ { <call> { <function> _ } _ } }
	`)

	test(`
	var abc = 1
	var def = 2
	var ghi = def = abc
	---
	{ @ { <var> = abc 1 } { <var> = def 2 } { <var> = ghi { = def abc } } }
	`)

	test(`
	for (var abc = 1, def = 2; ghi < 3; jkl++) {
	}
	---
	{ @ { <for> { <var> = abc 1 } { <var> = def 2 } { < ghi 3 } { =++ jkl } {} } }
	`)

	test(`
    if (!abc && abc.jkl(def) && abc[0] === +abc[0] && abc.length < ghi) {
	}
	---
	{ @ { <if> { && { && { && { ! abc } { <call> { . abc jkl } def } } { === { [ abc 0 } { + { [ abc 0 } } } } { < { . abc length } ghi } } {} } }
	`)

	test(`
	abc = {
		'"': "'",
		"'": '"',
	}
	---
	{ @ { = abc {[ { ": "'" } { ': """ } ]} } }
	`)

	test(`
	for (var abc in def) {
	}
	---
	{ @ { <for-in> { <var> abc } in def {} } }
	`)

	test(`
	({ abc: 'def' })
	---
	{ @ {[ { abc: "def" } ]} }
	`)

	test(`
	// This is not an object, this is a string literal with a label!
	{ abc: 'def' }
	---
	{ @ { "def" } }
	`)

	test(`abc = function() { 'use strict' }
	---
	{ @ { = abc { <function> "use strict" } } }
	`)

	test(`
	"use strict"
	---
	{ @ "use strict" }
	`)

	test(`
	"use strict"
	abc = 1 + 2 + 11
	---
	{ @ "use strict" { = abc { + { + 1 2 } 11 } } }
	`)

	// When run, this will call a type error to be thrown
	// This is essentially the same as:
	//
	// var abc = 1(function(){})()
	//
	test(`
	var abc = 1
	(function(){
	})()
	---
	{ @ { <var> = abc { <call> { <call> 1 { <function> _ } } _ } } }
	`)

	test(`
			xyzzy

	throw new TypeError("Nothing happens.")
	---
	{ @ xyzzy { <throw> { <new> TypeError "Nothing happens." } } }
	`)

	test(`
	/abc/.source
	---
	{ @ { . { /abc/ } source } }
	`)

	//test(`
	///abc/.source
	//--
	//`)

	test(`
	[,]
	---
	{ @ [ ; ] }
	`)

	test(`
	[,,]
	---
	{ @ [ ; ; ] }
	`)

	test(`
    ((x & (x = 1)) !== 0)
    ---
    { @ { !== { & x { = x 1 } } 0 } }
    `)
}

func TestParseFailure(t *testing.T) {
	Terst(t)

	test := parserTest

	test(`{
---
Unexpected end of input
1:-:-
	`)

	test(`}
---
Unexpected token }
1:-:-
	`)

	test(`3ea
---
Unexpected token ILLEGAL (3e)
1:-:-
	`)

	test(`3in []
---
Unexpected token ILLEGAL (3i)
1:-:-
	`)

	test(`3e
---
Unexpected token ILLEGAL (3e)
1:-:-
	`)

	test(`3e+
---
Unexpected token ILLEGAL (3e+)
1:-:-
	`)

	test(`3e-
---
Unexpected token ILLEGAL (3e-)
1:-:-
	`)

	test(`3x
---
Unexpected token ILLEGAL (3x)
1:-:-
	`)

	test(`3x0
---
Unexpected token ILLEGAL (3x)
1:-:-
	`)

	test(`0x
---
Unexpected token ILLEGAL (0x)
1:-:-
	`)

	test(`09
---
Unexpected token ILLEGAL (09)
1:-:-
	`)

	test(`018
---
Unexpected token ILLEGAL (018)
1:-:-
	`)

	test(`01a
---
Unexpected token ILLEGAL (01a)
1:-:-
	`)

	test(`3in[]
---
Unexpected token ILLEGAL (3i)
1:-:-
	`)

	test(`0x3in[]
---
Unexpected token ILLEGAL (0x3i)
1:-:-
	`)

	test(`"Hello
World"
---
Unexpected token ILLEGAL ("Hello)
1:-:-
	`)

	// TODO Make these run again
	if false {
		test(`x\
---
Unexpected token ILLEGAL (x)
1:-:-
	`)

		test(`x\u005c
---
Unexpected token ILLEGAL (x)
1:-:-
	`)

		test(`x\u002a
---
Unexpected token ILLEGAL (x)
1:-:-
	`)
	}

	test("var x = /(s/g", "---\nInvalid regular expression: missing closing ): `(s`\n1:-:-\n")

	test(`/
---
Invalid regular expression
1:-:-
	`)

	test(`3 = 4
---
ReferenceError: Invalid left-hand side in assignment
	`)

	test(`func() = 4
---
ReferenceError: Invalid left-hand side in assignment
	`)

	test(`(1 + 1) = 10
---
ReferenceError: Invalid left-hand side in assignment
	`)

	test(`1++
---
Invalid left-hand side in assignment
1:-:-
	`)

	test(`1--
---
Invalid left-hand side in assignment
1:-:-
	`)

	test(`--1
---
Invalid left-hand side in assignment
1:-:-
	`)

	test(`for((1 + 1) in list) process(x);
---
Invalid left-hand side in for-in
1:-:-
	`)

	test(`[
---
Unexpected end of input
1:-:-
	`)

	test(`[,
---
Unexpected end of input
1:-:-
	`)

	test(`1 + {
---
Unexpected end of input
1:-:-
	`)

	test(`1 + { t:t
---
Unexpected end of input
1:-:-
	`)

	test(`1 + { t:t,
---
Unexpected end of input
1:-:-
	`)

	test("var x = /\n/", `
---
Invalid regular expression
1:-:-
	`)

	test("var x = \"\n", `
---
Unexpected token ILLEGAL (")
1:-:-
	`)

	test(`var if = 42
---
Unexpected token if
1:-:-
	`)

	test(`i + 2 = 42
---
ReferenceError: Invalid left-hand side in assignment
	`)

	test(`+i = 42
---
ReferenceError: Invalid left-hand side in assignment
	`)

	test(`1 + (
---
Unexpected end of input
1:-:-
	`)

	test("\n\n\n{", `
---
Unexpected end of input
4:-:-
	`)

	test("\n/* Some multiline\ncomment */\n)", `
---
Unexpected token )
4:-:-
	`)

	// TODO
	//{ set 1 }
	//{ get 2 }
	//({ set: s(if) { } })
	//({ set s(.) { } })
	//({ set: s() { } })
	//({ set: s(a, b) { } })
	//({ get: g(d) { } })
	//({ get i() { }, i: 42 })
	//({ i: 42, get i() { } })
	//({ set i(x) { }, i: 42 })
	//({ i: 42, set i(x) { } })
	//({ get i() { }, get i() { } })
	//({ set i(x) { }, set i(x) { } })

	test(`function t(if) { }
---
Unexpected token if
1:-:-
	`)

	// TODO This should be "token true"
	test(`function t(true) { }
---
Unexpected token boolean
1:-:-
	`)

	// TODO This should be "token false"
	test(`function t(false) { }
---
Unexpected token boolean
1:-:-
	`)

	test(`function t(null) { }
---
Unexpected token null
1:-:-
	`)

	test(`function null() { }
---
Unexpected token null
1:-:-
	`)

	test(`function true() { }
---
Unexpected token true
1:-:-
	`)

	test(`function false() { }
---
Unexpected token false
1:-:-
	`)

	test(`function if() { }
---
Unexpected token if
1:-:-
	`)

	// TODO Should be Unexpected identifier
	test(`a b;
---
Unexpected token b
1:-:-
	`)

	test(`if.a;
---
Unexpected token .
1:-:-
	`)

	test(`a if;
---
Unexpected token if
1:-:-
	`)

	// TODO Should be Unexpected reserved word
	test(`a class;
---
Unexpected token class
1:-:-
	`)

	test("break\n", `
---
Illegal break statement
2:-:-
	`)

	// TODO Should be Unexpected number
	test(`break 1;
---
Unexpected token 1
1:-:-
	`)

	test("continue\n", `
---
Illegal continue statement
2:-:-
	`)

	// TODO Should be Unexpected number
	test(`continue 2;
---
Unexpected token 2
1:-:-
	`)

	test(`throw
---
Unexpected end of input
1:-:-
	`)

	test(`throw;
---
Unexpected token ;
1:-:-
	`)

	test("throw\n", `
---
Illegal newline after throw
2:-:-
	`)

	test(`for (var i, i2 in {});
---
Unexpected token in
1:-:-
	`)

	test(`for ((i in {}));
---
Unexpected token )
1:-:-
	`)

	test(`for (+i in {});
---
Invalid left-hand side in for-in
1:-:-
	`)

	test(`if(false)
---
Unexpected end of input
1:-:-
	`)

	test(`if(false) doThis(); else
---
Unexpected end of input
1:-:-
	`)

	test(`do
---
Unexpected end of input
1:-:-
	`)

	test(`while(false)
---
Unexpected end of input
1:-:-
	`)

	test(`for(;;)
---
Unexpected end of input
1:-:-
	`)

	test(`with(x)
---
Unexpected end of input
1:-:-
	`)

	test(`try { }
---
Missing catch or finally after try
1:-:-
	`)

	test("\u203f = 10", `
---
Unexpected token ILLEGAL ()
1:-:-
	`)

	// TODO
	// const x = 12, y;
	// const x, y = 12;
	// const x;
	// if(true) let a = 1;
	// if(true) const  a = 1;

	// TODO "Unexpected string"
	test(`new X()."S"
---
Unexpected token string
1:-:-
	`)

	// TODO Incorrect cursor position
	test(`/*
---
Unexpected token ILLEGAL
0:-:-
	`)

	// TODO Incorrect cursor position
	test(`/*



---
Unexpected token ILLEGAL
0:-:-
	`)

	// TODO Incorrect cursor position
	test(`/**
---
Unexpected token ILLEGAL
0:-:-
	`)

	// TODO Incorrect cursor position
	test("/*\n\n*", `
---
Unexpected token ILLEGAL
0:-:-
	`)

	// TODO Incorrect cursor position
	test(`/*hello
---
Unexpected token ILLEGAL
0:-:-
	`)

	// TODO Incorrect cursor position
	test(`/*hello  *
---
Unexpected token ILLEGAL
0:-:-
	`)

	test("\n]", `
---
Unexpected token ]
2:-:-
	`)

	test("\r]", `
---
Unexpected token ]
2:-:-
	`)

	test("\r\n]", `
---
Unexpected token ]
2:-:-
	`)

	test("\n\r]", `
---
Unexpected token ]
3:-:-
	`)

	test("//\r\n]", `
---
Unexpected token ]
2:-:-
	`)

	test("//\n\r]", `
---
Unexpected token ]
3:-:-
	`)

	test("/a\\\n/", `
---
Invalid regular expression
1:-:-
	`)

	test("//\r \n]", `
---
Unexpected token ]
3:-:-
	`)

	test("/*\r\n*/]", `
---
Unexpected token ]
2:-:-
	`)

	test("/*\r \n*/]", `
---
Unexpected token ]
3:-:-
	`)

	test("\\\\", `
---
Unexpected token ILLEGAL ()
1:-:-
	`)

	test("\\u005c", `
---
Unexpected token ILLEGAL ()
1:-:-
	`)

	test("\\x", `
---
Unexpected token ILLEGAL ()
1:-:-
	`)

	test("\\u0000", `
---
Unexpected token ILLEGAL ()
1:-:-
	`)

	test("\\u200c = []", `
---
Unexpected token ILLEGAL ()
1:-:-
	`)

	test("\\u200D = []", `
---
Unexpected token ILLEGAL ()
1:-:-
	`)

	test("\"\\", `
---
Unexpected token ILLEGAL (")
1:-:-
	`)

	test("\"\\u", `
---
Unexpected token ILLEGAL ("\)
1:-:-
	`)

	test("return", `
---
Illegal return statement
1:-:-
	`)

	test("break", `
---
Illegal break statement
1:-:-
	`)

	test("continue", `
---
Illegal continue statement
1:-:-
	`)

	test(`switch (x) { default: continue; }
---
Illegal continue statement
1:-:-
	`)

	test(`do { x } *
---
Unexpected token *
1:-:-
	`)

	test(`while (true) { break x; }
---
Undefined label 'x'
1:-:-
	`)

	test(`while (true) { continue x; }
---
Undefined label 'x'
1:-:-
	`)

	test(`x: while (true) { (function () { break x; }); }
---
Undefined label 'x'
1:-:-
	`)

	test(`x: while (true) { (function () { continue x; }); }
---
Undefined label 'x'
1:-:-
	`)

	test(`x: while (true) { (function () { break; }); }
---
Illegal break statement
1:-:-
	`)

	test(`x: while (true) { (function () { continue; }); }
---
Illegal continue statement
1:-:-
	`)

	test(`x: while (true) { x: while (true) {} }
---
Label 'x' has already been declared
1:-:-
	`)

	// TODO When strict mode is implemented
	if false {
		test(`(function () { 'use strict'; delete i; }())
	---
	Delete of an unqualified identifier in strict mode.
	0:-:-
		`)
	}

	// ----
	// ----
	// ----

	test(`_: _: while (true) {}
---
Label '_' has already been declared
1:-:-
	`)

	test(`
_:
_:
while (1 + 1) {
	banana
}
---
Label '_' has already been declared
3:-:-
	`)

	test(`
_:
    _:
while (apple) {
}
---
Label '_' has already been declared
3:-:-
	`)

	test("/Xyzzy(?!Nothing happens)/", "---\nInvalid regular expression: invalid or unsupported Perl syntax: `(?!`\n1:-:-")

	test(`
	function(){}
	---
	Unexpected token ( 2:-:-
	`)

	test(`
	/*/
	---
	Unexpected token ILLEGAL
	0:0:0
	`)

	test(`
	/*/.source
	---
	Unexpected token ILLEGAL
	0:0:0
	`)

	test("/\\1/.source", "---\nInvalid regular expression: invalid escape sequence: `\\1`\n-:-:-")

	test(`
    var class
    ---
    Unexpected reserved word
    2:14:15
	`)

	test(`
    object Object
    ---
	Unexpected token Object
    2:18:19
    `)

	test(`
    [object Object]
    ---
	Unexpected token Object
    2:19:20
    `)
}

func TestParseComment(t *testing.T) {
	Terst(t)

	test := parserTest

	test(`
	xyzzy // Ignore it
	// Ignore this
	// And this
	/* And all..



	... of this!
	*/
	"Nothing happens."
	// And finally this
	---
	{ @ xyzzy "Nothing happens." }
	`)
}
