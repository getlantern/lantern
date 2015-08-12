// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package bind

import (
	"bytes"
	"fmt"
	"go/token"
	"go/types"
	"io"
	"regexp"
	"unicode"
	"unicode/utf8"
)

// TODO(crawshaw): disallow basic android java type names in exported symbols.
// TODO(crawshaw): generate all relevant "implements" relationships for interfaces.
// TODO(crawshaw): consider introducing Java functions for casting to and from interfaces at runtime.

type ErrorList []error

func (list ErrorList) Error() string {
	buf := new(bytes.Buffer)
	for i, err := range list {
		if i > 0 {
			buf.WriteRune('\n')
		}
		io.WriteString(buf, err.Error())
	}
	return buf.String()
}

type javaGen struct {
	*printer
	fset *token.FileSet
	pkg  *types.Package
	err  ErrorList
}

func (g *javaGen) genStruct(obj *types.TypeName, T *types.Struct) {
	fields := exportedFields(T)
	methods := exportedMethodSet(types.NewPointer(obj.Type()))

	g.Printf("public static final class %s implements go.Seq.Object {\n", obj.Name())
	g.Indent()
	g.Printf("private static final String DESCRIPTOR = \"go.%s.%s\";\n", g.pkg.Name(), obj.Name())
	for i, f := range fields {
		g.Printf("private static final int FIELD_%s_GET = 0x%x0f;\n", f.Name(), i)
		g.Printf("private static final int FIELD_%s_SET = 0x%x1f;\n", f.Name(), i)
	}
	for i, m := range methods {
		g.Printf("private static final int CALL_%s = 0x%x0c;\n", m.Name(), i)
	}
	g.Printf("\n")

	g.Printf("private go.Seq.Ref ref;\n\n")

	n := obj.Name()
	g.Printf("private %s(go.Seq.Ref ref) { this.ref = ref; }\n\n", n)
	g.Printf(`public go.Seq.Ref ref() { return ref; }

public void call(int code, go.Seq in, go.Seq out) {
    throw new RuntimeException("internal error: cycle: cannot call concrete proxy");
}

`)

	for _, f := range fields {
		g.Printf("public %s get%s() {\n", g.javaType(f.Type()), f.Name())
		g.Indent()
		g.Printf("Seq in = new Seq();\n")
		g.Printf("Seq out = new Seq();\n")
		g.Printf("in.writeRef(ref);\n")
		g.Printf("Seq.send(DESCRIPTOR, FIELD_%s_GET, in, out);\n", f.Name())
		if seqType(f.Type()) == "Ref" {
			g.Printf("return new %s(out.read%s);\n", g.javaType(f.Type()), seqRead(f.Type()))
		} else {
			g.Printf("return out.read%s;\n", seqRead(f.Type()))
		}
		g.Outdent()
		g.Printf("}\n\n")

		g.Printf("public void set%s(%s v) {\n", f.Name(), g.javaType(f.Type()))
		g.Indent()
		g.Printf("Seq in = new Seq();\n")
		g.Printf("Seq out = new Seq();\n")
		g.Printf("in.writeRef(ref);\n")
		g.Printf("in.write%s;\n", seqWrite(f.Type(), "v"))
		g.Printf("Seq.send(DESCRIPTOR, FIELD_%s_SET, in, out);\n", f.Name())
		g.Outdent()
		g.Printf("}\n\n")
	}

	for _, m := range methods {
		g.genFunc(m, true)
	}

	g.Printf("@Override public boolean equals(Object o) {\n")
	g.Indent()
	g.Printf("if (o == null || !(o instanceof %s)) {\n    return false;\n}\n", n)
	g.Printf("%s that = (%s)o;\n", n, n)
	for _, f := range fields {
		nf := f.Name()
		g.Printf("%s this%s = get%s();\n", g.javaType(f.Type()), nf, nf)
		g.Printf("%s that%s = that.get%s();\n", g.javaType(f.Type()), nf, nf)
		if isJavaPrimitive(f.Type()) {
			g.Printf("if (this%s != that%s) {\n    return false;\n}\n", nf, nf)
		} else {
			g.Printf("if (this%s == null) {\n", nf)
			g.Indent()
			g.Printf("if (that%s != null) {\n    return false;\n}\n", nf)
			g.Outdent()
			g.Printf("} else if (!this%s.equals(that%s)) {\n    return false;\n}\n", nf, nf)
		}
	}
	g.Printf("return true;\n")
	g.Outdent()
	g.Printf("}\n\n")

	g.Printf("@Override public int hashCode() {\n")
	g.Printf("    return java.util.Arrays.hashCode(new Object[] {")
	for i, f := range fields {
		if i > 0 {
			g.Printf(", ")
		}
		g.Printf("get%s()", f.Name())
	}
	g.Printf("});\n")
	g.Printf("}\n\n")

	// TODO(crawshaw): use String() string if it is defined.
	g.Printf("@Override public String toString() {\n")
	g.Indent()
	g.Printf("StringBuilder b = new StringBuilder();\n")
	g.Printf(`b.append("%s").append("{");`, obj.Name())
	g.Printf("\n")
	for _, f := range fields {
		n := f.Name()
		g.Printf(`b.append("%s:").append(get%s()).append(",");`, n, n)
		g.Printf("\n")
	}
	g.Printf(`return b.append("}").toString();`)
	g.Printf("\n")
	g.Outdent()
	g.Printf("}\n\n")

	g.Outdent()
	g.Printf("}\n\n")
}

func (g *javaGen) genInterfaceStub(o *types.TypeName, m *types.Interface) {
	g.Printf("public static abstract class Stub implements %s {\n", o.Name())
	g.Indent()

	g.Printf("static final String DESCRIPTOR = \"go.%s.%s\";\n\n", g.pkg.Name(), o.Name())
	g.Printf("private final go.Seq.Ref ref;\n")
	g.Printf("public Stub() {\n    ref = go.Seq.createRef(this);\n}\n\n")
	g.Printf("public go.Seq.Ref ref() { return ref; }\n\n")

	g.Printf("public void call(int code, go.Seq in, go.Seq out) {\n")
	g.Indent()
	g.Printf("switch (code) {\n")

	for i := 0; i < m.NumMethods(); i++ {
		f := m.Method(i)
		g.Printf("case Proxy.CALL_%s: {\n", f.Name())
		g.Indent()

		sig := f.Type().(*types.Signature)
		params := sig.Params()
		for i := 0; i < params.Len(); i++ {
			p := sig.Params().At(i)
			jt := g.javaType(p.Type())
			g.Printf("%s param_%s;\n", jt, paramName(params, i))
			g.genRead("param_"+paramName(params, i), "in", p.Type())
		}

		res := sig.Results()
		var returnsError bool
		var numRes = res.Len()
		if (res.Len() == 1 && isErrorType(res.At(0).Type())) ||
			(res.Len() == 2 && isErrorType(res.At(1).Type())) {
			numRes -= 1
			returnsError = true
		}

		if returnsError {
			g.Printf("try {\n")
			g.Indent()
		}

		if numRes > 0 {
			g.Printf("%s result = ", g.javaType(res.At(0).Type()))
		}

		g.Printf("this.%s(", f.Name())
		for i := 0; i < params.Len(); i++ {
			if i > 0 {
				g.Printf(", ")
			}
			g.Printf("param_%s", paramName(params, i))
		}
		g.Printf(");\n")

		if numRes > 0 {
			g.Printf("out.write%s;\n", seqWrite(res.At(0).Type(), "result"))
		}
		if returnsError {
			g.Printf("out.writeString(null);\n")
			g.Outdent()
			g.Printf("} catch (Exception e) {\n")
			g.Indent()
			if numRes > 0 {
				resTyp := res.At(0).Type()
				g.Printf("%s result = %s;\n", g.javaType(resTyp), g.javaTypeDefault(resTyp))
				g.Printf("out.write%s;\n", seqWrite(resTyp, "result"))
			}
			g.Printf("out.writeString(e.getMessage());\n")
			g.Outdent()
			g.Printf("}\n")
		}
		g.Printf("return;\n")
		g.Outdent()
		g.Printf("}\n")
	}

	g.Printf("default:\n    throw new RuntimeException(\"unknown code: \"+ code);\n")
	g.Printf("}\n")
	g.Outdent()
	g.Printf("}\n")

	g.Outdent()
	g.Printf("}\n\n")
}

const javaProxyPreamble = `static final class Proxy implements %s {
    static final String DESCRIPTOR = Stub.DESCRIPTOR;

    private go.Seq.Ref ref;

    Proxy(go.Seq.Ref ref) { this.ref = ref; }

    public go.Seq.Ref ref() { return ref; }

    public void call(int code, go.Seq in, go.Seq out) {
        throw new RuntimeException("cycle: cannot call proxy");
    }

`

func (g *javaGen) genInterface(o *types.TypeName) {
	iface := o.Type().(*types.Named).Underlying().(*types.Interface)

	g.Printf("public interface %s extends go.Seq.Object {\n", o.Name())
	g.Indent()

	methodSigErr := false
	for i := 0; i < iface.NumMethods(); i++ {
		if err := g.funcSignature(iface.Method(i), false); err != nil {
			methodSigErr = true
			g.errorf("%v", err)
		}
		g.Printf(";\n\n")
	}
	if methodSigErr {
		return // skip stub generation, more of the same errors
	}

	g.genInterfaceStub(o, iface)

	g.Printf(javaProxyPreamble, o.Name())
	g.Indent()

	for i := 0; i < iface.NumMethods(); i++ {
		g.genFunc(iface.Method(i), true)
	}
	for i := 0; i < iface.NumMethods(); i++ {
		g.Printf("static final int CALL_%s = 0x%x0a;\n", iface.Method(i).Name(), i+1)
	}

	g.Outdent()
	g.Printf("}\n")

	g.Outdent()
	g.Printf("}\n\n")
}

func isErrorType(T types.Type) bool {
	return T == types.Universe.Lookup("error").Type()
}

func isJavaPrimitive(T types.Type) bool {
	b, ok := T.(*types.Basic)
	if !ok {
		return false
	}
	switch b.Kind() {
	case types.Bool, types.Uint8, types.Float32, types.Float64,
		types.Int, types.Int8, types.Int16, types.Int32, types.Int64:
		return true
	}
	return false
}

// javaType returns a string that can be used as a Java type.
func (g *javaGen) javaType(T types.Type) string {
	switch T := T.(type) {
	case *types.Basic:
		switch T.Kind() {
		case types.Bool:
			return "boolean"
		case types.Int:
			return "long"
		case types.Int8:
			return "byte"
		case types.Int16:
			return "short"
		case types.Int32:
			return "int"
		case types.Int64:
			return "long"
		case types.Uint8:
			// TODO(crawshaw): Java bytes are signed, so this is
			// questionable, but vital.
			return "byte"
		// TODO(crawshaw): case types.Uint, types.Uint16, types.Uint32, types.Uint64:
		case types.Float32:
			return "float"
		case types.Float64:
			return "double"
		case types.String:
			return "String"
		default:
			g.errorf("unsupported return type: %s", T)
			return "TODO"
		}
	case *types.Slice:
		elem := g.javaType(T.Elem())
		return elem + "[]"

	case *types.Pointer:
		if _, ok := T.Elem().(*types.Named); ok {
			return g.javaType(T.Elem())
		}
		panic(fmt.Sprintf("unsupporter pointer to type: %s", T))
	case *types.Named:
		n := T.Obj()
		if n.Pkg() != g.pkg {
			panic(fmt.Sprintf("type %s is in package %s, must be defined in package %s", n.Name(), n.Pkg().Name(), g.pkg.Name()))
		}
		// TODO(crawshaw): more checking here
		return n.Name()
	default:
		g.errorf("unsupported javaType: %#+v, %s\n", T, T)
		return "TODO"
	}
}

// javaTypeDefault returns a string that represents the default value of the mapped java type.
// TODO(hyangah): Combine javaType and javaTypeDefault?
func (g *javaGen) javaTypeDefault(T types.Type) string {
	switch T := T.(type) {
	case *types.Basic:
		switch T.Kind() {
		case types.Bool:
			return "false"
		case types.Int, types.Int8, types.Int16, types.Int32,
			types.Int64, types.Uint8, types.Float32, types.Float64:
			return "0"
		case types.String:
			return "null"
		default:
			g.errorf("unsupported return type: %s", T)
			return "TODO"
		}
	case *types.Slice, *types.Pointer, *types.Named:
		return "null"

	default:
		g.errorf("unsupported javaType: %#+v, %s\n", T, T)
		return "TODO"
	}
}

var paramRE = regexp.MustCompile(`^p[0-9]*$`)

// paramName replaces incompatible name with a p0-pN name.
// Missing names, or existing names of the form p[0-9] are incompatible.
// TODO(crawshaw): Replace invalid unicode names.
func paramName(params *types.Tuple, pos int) string {
	name := params.At(pos).Name()
	if name == "" || name == "_" || paramRE.MatchString(name) {
		name = fmt.Sprintf("p%d", pos)
	}
	return name
}

func (g *javaGen) funcSignature(o *types.Func, static bool) error {
	sig := o.Type().(*types.Signature)
	res := sig.Results()

	var returnsError bool
	var ret string
	switch res.Len() {
	case 2:
		if !isErrorType(res.At(1).Type()) {
			return fmt.Errorf("second result value must be of type error: %s", o)
		}
		returnsError = true
		ret = g.javaType(res.At(0).Type())
	case 1:
		if isErrorType(res.At(0).Type()) {
			returnsError = true
			ret = "void"
		} else {
			ret = g.javaType(res.At(0).Type())
		}
	case 0:
		ret = "void"
	default:
		return fmt.Errorf("too many result values: %s", o)
	}

	g.Printf("public ")
	if static {
		g.Printf("static ")
	}
	g.Printf("%s %s(", ret, o.Name())
	params := sig.Params()
	for i := 0; i < params.Len(); i++ {
		if i > 0 {
			g.Printf(", ")
		}
		v := sig.Params().At(i)
		name := paramName(params, i)
		jt := g.javaType(v.Type())
		g.Printf("%s %s", jt, name)
	}
	g.Printf(")")
	if returnsError {
		g.Printf(" throws Exception")
	}
	return nil
}

func (g *javaGen) genFunc(o *types.Func, method bool) {
	if err := g.funcSignature(o, !method); err != nil {
		g.errorf("%v", err)
		return
	}
	sig := o.Type().(*types.Signature)
	res := sig.Results()

	g.Printf(" {\n")
	g.Indent()
	g.Printf("go.Seq _in = new go.Seq();\n")
	g.Printf("go.Seq _out = new go.Seq();\n")

	returnsError := false
	var resultType types.Type
	if res.Len() > 0 {
		if !isErrorType(res.At(0).Type()) {
			resultType = res.At(0).Type()
		}
		if res.Len() > 1 || isErrorType(res.At(0).Type()) {
			returnsError = true
		}
	}
	if resultType != nil {
		t := g.javaType(resultType)
		g.Printf("%s _result;\n", t)
	}

	if method {
		g.Printf("_in.writeRef(ref);\n")
	}
	params := sig.Params()
	for i := 0; i < params.Len(); i++ {
		p := params.At(i)
		g.Printf("_in.write%s;\n", seqWrite(p.Type(), paramName(params, i)))
	}
	g.Printf("Seq.send(DESCRIPTOR, CALL_%s, _in, _out);\n", o.Name())
	if resultType != nil {
		g.genRead("_result", "_out", resultType)
	}
	if returnsError {
		g.Printf(`String _err = _out.readString();
if (_err != null) {
    throw new Exception(_err);
}
`)
	}
	if resultType != nil {
		g.Printf("return _result;\n")
	}
	g.Outdent()
	g.Printf("}\n\n")
}

func (g *javaGen) genRead(resName, seqName string, T types.Type) {
	switch T := T.(type) {
	case *types.Pointer:
		// TODO(crawshaw): test *int
		// TODO(crawshaw): test **Generator
		switch T := T.Elem().(type) {
		case *types.Named:
			o := T.Obj()
			if o.Pkg() != g.pkg {
				g.errorf("type %s not defined in package %s", T, g.pkg)
				return
			}
			g.Printf("%s = new %s(%s.readRef());\n", resName, o.Name(), seqName)
		default:
			g.errorf("unsupported type %s", T)
		}
	case *types.Named:
		switch T.Underlying().(type) {
		case *types.Interface, *types.Pointer:
			o := T.Obj()
			if o.Pkg() != g.pkg {
				g.errorf("type %s not defined in package %s", T, g.pkg)
				return
			}
			g.Printf("%s = new %s.Proxy(%s.readRef());\n", resName, o.Name(), seqName)
		default:
			g.errorf("unsupported, direct named type %s", T)
		}
	default:
		g.Printf("%s = %s.read%s();\n", resName, seqName, seqType(T))
	}
}

func (g *javaGen) errorf(format string, args ...interface{}) {
	g.err = append(g.err, fmt.Errorf(format, args...))
}

const javaPreamble = `// Java Package %s is a proxy for talking to a Go program.
//   gobind -lang=java %s
//
// File is generated by gobind. Do not edit.
package go.%s;

import go.Seq;

`

func (g *javaGen) gen() error {
	g.Printf(javaPreamble, g.pkg.Name(), g.pkg.Path(), g.pkg.Name())

	firstRune, size := utf8.DecodeRuneInString(g.pkg.Name())
	className := string(unicode.ToUpper(firstRune)) + g.pkg.Name()[size:]

	g.Printf("public abstract class %s {\n", className)
	g.Indent()
	g.Printf("private %s() {} // uninstantiable\n\n", className)
	scope := g.pkg.Scope()
	names := scope.Names()
	var funcs []string
	for _, name := range names {
		obj := scope.Lookup(name)
		if !obj.Exported() {
			continue
		}

		switch o := obj.(type) {
		// TODO(crawshaw): case *types.Const:
		// TODO(crawshaw): case *types.Var:
		case *types.Func:
			g.genFunc(o, false)
			funcs = append(funcs, o.Name())
		case *types.TypeName:
			named := o.Type().(*types.Named)
			switch t := named.Underlying().(type) {
			case *types.Struct:
				g.genStruct(o, t)
			case *types.Interface:
				g.genInterface(o)
			default:
				g.errorf("%s: cannot generate binding for %s: %T", g.fset.Position(o.Pos()), o.Name(), t)
				continue
			}
		default:
			g.errorf("unsupported exported type: ", obj)
		}
	}

	for i, name := range funcs {
		g.Printf("private static final int CALL_%s = %d;\n", name, i+1)
	}

	g.Printf("private static final String DESCRIPTOR = %q;\n", g.pkg.Name())
	g.Outdent()
	g.Printf("}\n")

	if len(g.err) > 0 {
		return g.err
	}
	return nil
}
