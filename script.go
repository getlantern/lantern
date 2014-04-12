package otto

import (
	"github.com/robertkrimen/otto/ast"
	"github.com/robertkrimen/otto/parser"
)

// Script is a handle for some (reusable) JavaScript.
// Passing a Script value to a run method will evaluate the JavaScript.
//
type Script struct {
	program  *ast.Program
	filename string
	src      string
}

// Compile will parse the given source and return a Script value or nil and
// an error if there was a problem during compilation.
//
//      script, err := vm.Compile("", `var abc; if (!abc) abc = 0; abc += 2; abc;`)
//      vm.Run(script)
//
func (self *Otto) Compile(filename string, src interface{}) (*Script, error) {
	{
		src, err := parser.ReadSource(filename, src)
		if err != nil {
			return nil, err
		}

		program, err := self.runtime.parse(filename, src)
		if err != nil {
			return nil, err
		}

		script := &Script{
			program:  program,
			filename: filename,
			src:      string(src),
		}

		return script, nil
	}
}

func (self *Script) String() string {
	return "// " + self.filename + "\n" + self.src
}
