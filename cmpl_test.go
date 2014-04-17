package otto

import (
	. "./terst"
	"testing"

	"github.com/robertkrimen/otto/parser"
)

func Test_cmpl(t *testing.T) {
	Terst(t)

	vm := New()

	test := func(src string, expect ...interface{}) {
		program, err := parser.ParseFile(nil, "", src, 0)
		Is(err, nil)
		{
			program := cmpl_parse(program)
			value := vm.runtime.cmpl_evaluate_nodeProgram(program)
			if len(expect) > 0 {
				is(value, expect[0])
			}
		}
	}

	test(``, Value{})

	test(`var abc = 1; abc;`, 1)

	test(`var abc = 1 + 1; abc;`, 2)

	test(`1 + 2;`, 3)
}

func TestParse_cmpl(t *testing.T) {
	Terst(t)

	test := func(src string) {
		program, err := parser.ParseFile(nil, "", src, 0)
		Is(err, nil)
		IsNot(cmpl_parse(program), nil)
	}

	test(``)

	test(`var abc = 1; abc;`)

	test(`
        function abc() {
            return;
        }
    `)
}
