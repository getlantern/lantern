package otto

import (
	. "./terst"
	"fmt"
	"strings"
	"testing"
)

func lexerCollect(source string) (result []_token) {
	parser := newParser()
	parser.lexer.Source = source
	for {
		token := parser.Next()
		result = append(result, token)
		if token.Error || token.Kind == "EOF" {
			break
		}
	}
	return
}

func lexerCollectAndTest(input string, arguments ...string) {
	result := lexerCollect(input)
	for index, expect := range arguments {
		result := result[index]
		got := result.Kind
		if strings.Contains(expect, " ") {
			got = fmt.Sprintf("%s %s", result.Kind, result.Text)
		}
		Is(got, expect)
	}
}

func testLexerRead(lexer *_lexer, count int, wantRead []rune, wantWord string, wantFound, wantWidth int) {
	haveRead, haveWord, haveFound, haveWidth := lexer.read(count)
	Is(haveRead, wantRead)
	Is(haveWord, wantWord)
	Is(haveFound, wantFound)
	Is(haveWidth, wantWidth)
}

func TestLexer(t *testing.T) {
	Terst(t)

	{
		lexer := newLexer("")
		token := lexer.Scan()
		Is(token.Kind, "EOF")

		lexer = newLexer("1")
		token = lexer.Scan()
		Is(token.Kind, "number")
	}

	{
		test := testLexerRead

		lexer := newLexer("")
		test(&lexer, 1, []rune{-1}, "", 0, 0)
		lexer.next()
		test(&lexer, 1, []rune{-1}, "", 0, 0)

		lexer = newLexer("1")
		test(&lexer, 1, []rune{49}, "1", 1, 1)
		lexer.next()
		test(&lexer, 1, []rune{-1}, "", 0, 0)
		lexer.next()
		test(&lexer, 1, []rune{-1}, "", 0, 0)

		lexer = newLexer("abc")
		test(&lexer, 2, []rune{97, 98}, "ab", 2, 2)
		lexer.next()
		test(&lexer, 2, []rune{98, 99}, "bc", 2, 2)
		lexer.next()
		test(&lexer, 2, []rune{99, -1}, "c", 1, 1)
		lexer.next()
		test(&lexer, 2, []rune{-1, -1}, "", 0, 0)

		lexer = newLexer("abcdef")
		lexer.next()
		lexer.next()
		test(&lexer, 8, []rune{99, 100, 101, 102, -1, -1, -1, -1}, "cdef", 4, 4)
		lexer.back()
		test(&lexer, 8, []rune{98, 99, 100, 101, 102, -1, -1, -1}, "bcdef", 5, 5)
		for limit := 8; limit > 0; limit-- {
			lexer.back()
		}
		test(&lexer, 2, []rune{97, 98}, "ab", 2, 2)
		// Should get the same thing twice.
		test(&lexer, 2, []rune{97, 98}, "ab", 2, 2)
		lexer.next()
		test(&lexer, 2, []rune{98, 99}, "bc", 2, 2)
		lexer.skip(1)
		test(&lexer, 2, []rune{99, 100}, "cd", 2, 2)
		lexer.skip(3)
		test(&lexer, 2, []rune{102, -1}, "f", 1, 1)
	}
}

func TestParserLexer(t *testing.T) {
	Terst(t)

	test := lexerCollectAndTest

	test("",
		"EOF",
	)

	test("1",
		"number 1",
		"EOF",
	)

	test(".0",
		"number .0",
		"EOF",
	)

	test("xyzzy",
		"identifier xyzzy",
		"EOF",
	)

	test("xyzzy(1)",
		"identifier xyzzy",
		"(",
		"number 1",
		")",
		"EOF")

	test(".",
		".",
		"EOF")

	test(".0",
		"number .0",
		"EOF")

	test("===.",
		"===",
		".",
		"EOF")

	test(">>>=",
		">>>=",
		"EOF")

	test(">>>=.0",
		">>>=",
		"number .0",
		"EOF")

	test(">>>=0.0.",
		">>>=",
		"number 0.0",
		".",
		"EOF")

	test("\"Xyzzy\"",
		"string Xyzzy",
		"EOF")

	test("xyzzy = //",
		"identifier xyzzy",
		"=",
		"EOF")

	test("xyzzy = 1 / 2",
		"identifier xyzzy",
		"=",
		"number 1",
		"/",
		"number 2",
		"EOF")

	test("xyzzy = 'Nothing happens.'",
		"identifier xyzzy",
		"=",
		"string Nothing happens.",
		"EOF")

	test("xyzzy = !false",
		"identifier xyzzy",
		"=",
		"!",
		"boolean false",
		"EOF")

	test("xyzzy = !!true",
		"identifier xyzzy",
		"=",
		"!",
		"!",
		"boolean true",
		"EOF")

	test("xyzzy *= 1",
		"identifier xyzzy",
		"*=",
		"number 1",
		"EOF")

	test("if 1 else",
		"if",
		"number 1",
		"else",
		"EOF")

	test("null",
		"null",
		"EOF")

	test("3ea",
		"illegal 3e",
	)

	test("3in",
		"illegal 3i",
	)

	test(`"\u007a\x79\u000a\x78"`,
		"string zy\nx",
	)

	test(`
	"[First line \
Second line \
 Third line\
.     ]"
	`,
		"string [First line Second line  Third line.     ]",
	)

	test("/",
		"/",
		"EOF",
	)

	test("var abc = \"abc\uFFFFabc\"",
		"var",
		"identifier abc",
		"=",
		"string abc\uFFFFabc",
		"EOF",
	)

	test(`'\t' === '\r'`,
		"string \t",
		"===",
		"string \r",
		"EOF",
	)

	test("\"Hello\nWorld\"",
		"illegal \"Hello",
	)

	test("\u203f = 10",
		"illegal",
	)

	test(`var \u0024 = 1`,
		"var",
		"identifier $",
		"=",
		"number 1",
		"EOF",
	)

	test("10e10000",
		"number 10e10000",
	)

	test(`"\x0G"`,
		"illegal",
	)

	test(`var if var class`,
		"var",
		"if",
		"var",
		"class",
	)

	test(`-0`,
		"-",
		"number 0",
	)

	test(`.01`,
		"number .01",
	)

	test(`.01e+2`,
		"number .01e+2",
	)

}
