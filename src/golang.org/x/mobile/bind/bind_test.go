package bind

import (
	"bytes"
	"flag"
	"go/ast"
	"go/parser"
	"go/token"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	_ "golang.org/x/tools/go/gcimporter"
	"golang.org/x/tools/go/types"
)

var updateFlag = flag.Bool("update", false, "Update the golden files.")

var tests = []string{
	"testdata/basictypes.go",
	"testdata/structs.go",
	"testdata/interfaces.go",
}

var fset = token.NewFileSet()

func typeCheck(t *testing.T, filename string) *types.Package {
	f, err := parser.ParseFile(fset, filename, nil, parser.AllErrors)
	if err != nil {
		t.Fatalf("%s: %v", filename, err)
	}

	pkgName := filepath.Base(filename)
	pkgName = strings.TrimSuffix(pkgName, ".go")

	// typecheck and collect typechecker errors
	var conf types.Config
	conf.Error = func(err error) {
		t.Error(err)
	}
	pkg, err := conf.Check(pkgName, fset, []*ast.File{f}, nil)
	if err != nil {
		t.Fatal(err)
	}
	return pkg
}

// diff runs the command "diff a b" and returns its output
func diff(a, b string) string {
	var buf bytes.Buffer
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "plan9":
		cmd = exec.Command("/bin/diff", "-c", a, b)
	default:
		cmd = exec.Command("/usr/bin/diff", "-u", a, b)
	}
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	cmd.Run()
	return buf.String()
}

func writeTempFile(t *testing.T, name string, contents []byte) string {
	f, err := ioutil.TempFile("", name)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.Write(contents); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	return f.Name()
}

func TestGenJava(t *testing.T) {
	for _, filename := range tests {
		var buf bytes.Buffer
		pkg := typeCheck(t, filename)
		if err := GenJava(&buf, fset, pkg); err != nil {
			t.Errorf("%s: %v", filename, err)
			continue
		}
		out := writeTempFile(t, "java", buf.Bytes())
		defer os.Remove(out)
		golden := filename[:len(filename)-len(".go")] + ".java.golden"
		if diffstr := diff(golden, out); diffstr != "" {
			t.Errorf("%s: does not match Java golden:\n%s", filename, diffstr)

			if *updateFlag {
				t.Logf("Updating %s...", golden)
				if err := exec.Command("/bin/cp", out, golden).Run(); err != nil {
					t.Errorf("Update failed: %s", err)
				}
			}

		}
	}
}

func TestGenGo(t *testing.T) {
	for _, filename := range tests {
		var buf bytes.Buffer
		pkg := typeCheck(t, filename)
		if err := GenGo(&buf, fset, pkg); err != nil {
			t.Errorf("%s: %v", filename, err)
			continue
		}
		out := writeTempFile(t, "go", buf.Bytes())
		defer os.Remove(out)
		golden := filename + ".golden"
		if diffstr := diff(golden, out); diffstr != "" {
			t.Errorf("%s: does not match Java golden:\n%s", filename, diffstr)

			if *updateFlag {
				t.Logf("Updating %s...", golden)
				if err := exec.Command("/bin/cp", out, golden).Run(); err != nil {
					t.Errorf("Update failed: %s", err)
				}
			}
		}
	}
}
