package otto

import (
	"fmt"
	"strings"
    "testing"
    . "github.com/robertkrimen/terst"
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

func lexerCollectAndTest(input string, arguments... string){
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

func TestLexer(t *testing.T) {
	Terst(t)

	test := lexerCollectAndTest

	test("",
		"EOF")

	test("1",
		"number 1",
		"EOF")

	test(".0",
		"number .0",
		"EOF")

	test("xyzzy",
		"identifier xyzzy",
		"EOF")

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

}
