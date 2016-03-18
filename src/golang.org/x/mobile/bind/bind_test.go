package bind

import (
	"bytes"
	"flag"
	"go/ast"
	"go/parser"
	"go/token"
	"go/types"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func init() {
	log.SetFlags(log.Lshortfile)
}

var updateFlag = flag.Bool("update", false, "Update the golden files.")

var tests = []string{
	"testdata/basictypes.go",
	"testdata/structs.go",
	"testdata/interfaces.go",
	"testdata/issue10788.go",
	"testdata/issue12328.go",
	"testdata/issue12403.go",
	"testdata/try.go",
	"testdata/vars.go",
	"testdata/ignore.go",
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

func TestGenObjc(t *testing.T) {
	var suffixes = map[fileType]string{
		ObjcH:   ".objc.h.golden",
		ObjcM:   ".objc.m.golden",
		ObjcGoH: ".objc.go.h.golden",
	}

	for _, filename := range tests {
		pkg := typeCheck(t, filename)

		for typ, suffix := range suffixes {
			var buf bytes.Buffer
			conf := &GeneratorConfig{
				Writer: &buf,
				Fset:   fset,
				Pkg:    pkg,
				AllPkg: []*types.Package{pkg},
			}
			if err := GenObjc(conf, "", typ); err != nil {
				t.Errorf("%s: %v", filename, err)
				continue
			}
			out := writeTempFile(t, "generated"+suffix, buf.Bytes())
			defer os.Remove(out)
			golden := filename[:len(filename)-len(".go")] + suffix
			if diffstr := diff(golden, out); diffstr != "" {
				t.Errorf("%s: does not match Objective-C golden:\n%s", filename, diffstr)
				if *updateFlag {
					t.Logf("Updating %s...", golden)
					err := exec.Command("/bin/cp", out, golden).Run()
					if err != nil {
						t.Errorf("Update failed: %s", err)
					}
				}
			}
		}
	}
}

func TestGenJava(t *testing.T) {
	var suffixes = map[fileType]string{
		Java:  ".java.golden",
		JavaC: ".java.c.golden",
		JavaH: ".java.h.golden",
	}

	for _, filename := range tests {
		pkg := typeCheck(t, filename)
		for typ, suffix := range suffixes {
			var buf bytes.Buffer
			conf := &GeneratorConfig{
				Writer: &buf,
				Fset:   fset,
				Pkg:    pkg,
				AllPkg: []*types.Package{pkg},
			}
			if err := GenJava(conf, "", typ); err != nil {
				t.Errorf("%s: %v", filename, err)
				continue
			}
			out := writeTempFile(t, "generated"+suffix, buf.Bytes())
			defer os.Remove(out)
			golden := filename[:len(filename)-len(".go")] + suffix
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
}

func TestGenGo(t *testing.T) {
	for _, filename := range tests {
		var buf bytes.Buffer
		pkg := typeCheck(t, filename)
		conf := &GeneratorConfig{
			Writer: &buf,
			Fset:   fset,
			Pkg:    pkg,
			AllPkg: []*types.Package{pkg},
		}
		if err := GenGo(conf); err != nil {
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

func TestCustomPrefix(t *testing.T) {
	const datafile = "testdata/customprefix.go"
	const isHeader = true
	pkg := typeCheck(t, datafile)

	conf := &GeneratorConfig{
		Fset:   fset,
		Pkg:    pkg,
		AllPkg: []*types.Package{pkg},
	}
	testCases := []struct {
		golden string
		gen    func(w io.Writer) error
	}{
		{
			"testdata/customprefix.java.golden",
			func(w io.Writer) error { conf.Writer = w; return GenJava(conf, "com.example", Java) },
		},
		{
			"testdata/customprefix.java.h.golden",
			func(w io.Writer) error { conf.Writer = w; return GenJava(conf, "com.example", JavaH) },
		},
		{
			"testdata/customprefix.java.c.golden",
			func(w io.Writer) error { conf.Writer = w; return GenJava(conf, "com.example", JavaC) },
		},
		{
			"testdata/customprefix.objc.go.h.golden",
			func(w io.Writer) error { conf.Writer = w; return GenObjc(conf, "EX", ObjcGoH) },
		},
		{
			"testdata/customprefix.objc.h.golden",
			func(w io.Writer) error { conf.Writer = w; return GenObjc(conf, "EX", ObjcH) },
		},
		{
			"testdata/customprefix.objc.m.golden",
			func(w io.Writer) error { conf.Writer = w; return GenObjc(conf, "EX", ObjcM) },
		},
	}

	for _, tc := range testCases {
		var buf bytes.Buffer
		if err := tc.gen(&buf); err != nil {
			t.Errorf("generating %s: %v", tc.golden, err)
			continue
		}
		out := writeTempFile(t, "generated", buf.Bytes())
		defer os.Remove(out)
		if diffstr := diff(tc.golden, out); diffstr != "" {
			t.Errorf("%s: generated file does not match:\b%s", tc.golden, diffstr)
			if *updateFlag {
				t.Logf("Updating %s...", tc.golden)
				err := exec.Command("/bin/cp", out, tc.golden).Run()
				if err != nil {
					t.Errorf("Update failed: %s", err)
				}
			}
		}
	}
}

func TestLowerFirst(t *testing.T) {
	testCases := []struct {
		in, want string
	}{
		{"", ""},
		{"Hello", "hello"},
		{"HelloGopher", "helloGopher"},
		{"hello", "hello"},
		{"ID", "id"},
		{"IDOrName", "idOrName"},
		{"ΓειαΣας", "γειαΣας"},
	}

	for _, tc := range testCases {
		if got := lowerFirst(tc.in); got != tc.want {
			t.Errorf("lowerFirst(%q) = %q; want %q", tc.in, got, tc.want)
		}
	}
}
