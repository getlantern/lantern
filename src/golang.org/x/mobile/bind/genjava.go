// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package bind

import (
	"fmt"
	"go/constant"
	"go/types"
	"math"
	"strings"
)

// TODO(crawshaw): disallow basic android java type names in exported symbols.
// TODO(crawshaw): consider introducing Java functions for casting to and from interfaces at runtime.

type javaGen struct {
	// javaPkg is the custom name of the Java pkg that contains the generated classes. If empty,
	// use a package name generated from the Go package name.
	javaPkg string

	*generator
}

func (g *javaGen) genStruct(obj *types.TypeName, T *types.Struct) {
	fields := exportedFields(T)
	methods := exportedMethodSet(types.NewPointer(obj.Type()))

	var impls []string
	pT := types.NewPointer(obj.Type())
	for _, iface := range g.allIntf {
		if types.AssignableTo(pT, iface.obj.Type()) {
			n := iface.obj.Name()
			if p := iface.obj.Pkg(); p != g.pkg {
				n = fmt.Sprintf("%s.%s.%s", g.javaPkgName(p), className(p), n)
			}
			impls = append(impls, n)
		}
	}
	g.Printf("public static final class %s extends Seq.Proxy", obj.Name())
	if len(impls) > 0 {
		g.Printf(" implements %s", strings.Join(impls, ", "))
	}
	g.Printf(" {\n")
	g.Indent()

	n := obj.Name()
	g.Printf("private %s(go.Seq.Ref ref) { super(ref); }\n\n", n)

	for _, f := range fields {
		if t := f.Type(); !g.isSupported(t) {
			g.Printf("// skipped field %s.%s with unsupported type: %T\n\n", n, f.Name(), t)
			continue
		}
		g.Printf("public final native %s get%s();\n", g.javaType(f.Type()), f.Name())
		g.Printf("public final native void set%s(%s v);\n\n", f.Name(), g.javaType(f.Type()))
	}

	var isStringer bool
	for _, m := range methods {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", obj.Name(), m.Name())
			continue
		}
		g.genFuncSignature(m, false, false)
		t := m.Type().(*types.Signature)
		isStringer = isStringer || (m.Name() == "String" && t.Params().Len() == 0 && t.Results().Len() == 1 &&
			types.Identical(t.Results().At(0).Type(), types.Typ[types.String]))
	}

	g.Printf("@Override public boolean equals(Object o) {\n")
	g.Indent()
	g.Printf("if (o == null || !(o instanceof %s)) {\n    return false;\n}\n", n)
	g.Printf("%s that = (%s)o;\n", n, n)
	for _, f := range fields {
		if t := f.Type(); !g.isSupported(t) {
			g.Printf("// skipped field %s.%s with unsupported type: %T\n\n", n, f.Name(), t)
			continue
		}
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
	idx := 0
	for _, f := range fields {
		if t := f.Type(); !g.isSupported(t) {
			continue
		}
		if idx > 0 {
			g.Printf(", ")
		}
		idx++
		g.Printf("get%s()", f.Name())
	}
	g.Printf("});\n")
	g.Printf("}\n\n")

	g.Printf("@Override public String toString() {\n")
	g.Indent()
	if isStringer {
		g.Printf("return String();\n")
	} else {
		g.Printf("StringBuilder b = new StringBuilder();\n")
		g.Printf(`b.append("%s").append("{");`, obj.Name())
		g.Printf("\n")
		for _, f := range fields {
			if t := f.Type(); !g.isSupported(t) {
				continue
			}
			n := f.Name()
			g.Printf(`b.append("%s:").append(get%s()).append(",");`, n, n)
			g.Printf("\n")
		}
		g.Printf(`return b.append("}").toString();`)
		g.Printf("\n")
	}
	g.Outdent()
	g.Printf("}\n")

	g.Outdent()
	g.Printf("}\n\n")
}

func (g *javaGen) genInterface(iface interfaceInfo) {
	var exts []string
	numM := iface.t.NumMethods()
	for _, other := range g.allIntf {
		// Only extend interfaces with fewer methods to avoid circular references
		if other.t.NumMethods() < numM && types.AssignableTo(iface.t, other.t) {
			n := other.obj.Name()
			if p := other.obj.Pkg(); p != g.pkg {
				n = fmt.Sprintf("%s.%s.%s", g.javaPkgName(p), className(p), n)
			}
			exts = append(exts, n)
		}
	}
	g.Printf("public interface %s", iface.obj.Name())
	if len(exts) > 0 {
		g.Printf(" extends %s", strings.Join(exts, ", "))
	}
	g.Printf(" {\n")
	g.Indent()

	for _, m := range iface.summary.callable {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", iface.obj.Name(), m.Name())
			continue
		}
		g.genFuncSignature(m, false, true)
	}

	g.Outdent()
	g.Printf("}\n")

	g.Printf("\n")
	g.Printf(javaProxyPreamble, iface.obj.Name())
	g.Indent()

	for _, m := range iface.summary.callable {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", iface.obj.Name(), m.Name())
			continue
		}
		g.genFuncSignature(m, false, false)
	}

	g.Outdent()
	g.Printf("}\n\n")
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

// jniType returns a string that can be used as a JNI type.
func (g *javaGen) jniType(T types.Type) string {
	if isErrorType(T) {
		// The error type is usually translated into an exception in
		// Java, however the type can be exposed in other ways, such
		// as an exported field.
		return g.jniType(types.Typ[types.String])
	}
	switch T := T.(type) {
	case *types.Basic:
		switch T.Kind() {
		case types.Bool, types.UntypedBool:
			return "jboolean"
		case types.Int:
			return "jlong"
		case types.Int8:
			return "jbyte"
		case types.Int16:
			return "jshort"
		case types.Int32, types.UntypedRune: // types.Rune
			return "jint"
		case types.Int64, types.UntypedInt:
			return "jlong"
		case types.Uint8: // types.Byte
			// TODO(crawshaw): Java bytes are signed, so this is
			// questionable, but vital.
			return "jbyte"
		// TODO(crawshaw): case types.Uint, types.Uint16, types.Uint32, types.Uint64:
		case types.Float32:
			return "jfloat"
		case types.Float64, types.UntypedFloat:
			return "jdouble"
		case types.String, types.UntypedString:
			return "jstring"
		default:
			g.errorf("unsupported basic type: %s", T)
			return "TODO"
		}
	case *types.Slice:
		return "jbyteArray"

	case *types.Pointer:
		if _, ok := T.Elem().(*types.Named); ok {
			return g.jniType(T.Elem())
		}
		g.errorf("unsupported pointer to type: %s", T)
	case *types.Named:
		return "jobject"
	default:
		g.errorf("unsupported jniType: %#+v, %s\n", T, T)
	}
	return "TODO"
}

func (g *javaGen) javaBasicType(T *types.Basic) string {
	switch T.Kind() {
	case types.Bool, types.UntypedBool:
		return "boolean"
	case types.Int:
		return "long"
	case types.Int8:
		return "byte"
	case types.Int16:
		return "short"
	case types.Int32, types.UntypedRune: // types.Rune
		return "int"
	case types.Int64, types.UntypedInt:
		return "long"
	case types.Uint8: // types.Byte
		// TODO(crawshaw): Java bytes are signed, so this is
		// questionable, but vital.
		return "byte"
	// TODO(crawshaw): case types.Uint, types.Uint16, types.Uint32, types.Uint64:
	case types.Float32:
		return "float"
	case types.Float64, types.UntypedFloat:
		return "double"
	case types.String, types.UntypedString:
		return "String"
	default:
		g.errorf("unsupported basic type: %s", T)
		return "TODO"
	}
}

// javaType returns a string that can be used as a Java type.
func (g *javaGen) javaType(T types.Type) string {
	if isErrorType(T) {
		// The error type is usually translated into an exception in
		// Java, however the type can be exposed in other ways, such
		// as an exported field.
		return "String"
	}
	switch T := T.(type) {
	case *types.Basic:
		return g.javaBasicType(T)
	case *types.Slice:
		elem := g.javaType(T.Elem())
		return elem + "[]"

	case *types.Pointer:
		if _, ok := T.Elem().(*types.Named); ok {
			return g.javaType(T.Elem())
		}
		g.errorf("unsupported pointer to type: %s", T)
	case *types.Named:
		n := T.Obj()
		nPkg := n.Pkg()
		if !g.validPkg(nPkg) {
			g.errorf("type %s is in %s, which is not bound", n.Name(), nPkg)
			break
		}
		// TODO(crawshaw): more checking here
		if nPkg != g.pkg {
			return fmt.Sprintf("%s.%s.%s", g.javaPkgName(nPkg), className(nPkg), n.Name())
		} else {
			return n.Name()
		}
	default:
		g.errorf("unsupported javaType: %#+v, %s\n", T, T)
	}
	return "TODO"
}

func (g *javaGen) genJNIFuncSignature(o *types.Func, sName string, proxy bool) {
	sig := o.Type().(*types.Signature)
	res := sig.Results()

	var ret string
	switch res.Len() {
	case 2:
		ret = g.jniType(res.At(0).Type())
	case 1:
		if isErrorType(res.At(0).Type()) {
			ret = "void"
		} else {
			ret = g.jniType(res.At(0).Type())
		}
	case 0:
		ret = "void"
	default:
		g.errorf("too many result values: %s", o)
		return
	}

	g.Printf("JNIEXPORT %s JNICALL\n", ret)
	g.Printf("Java_%s_%s", g.jniPkgName(), g.className())
	if sName != "" {
		// 0024 is the mangled form of $, for naming inner classes.
		g.Printf("_00024")
		if proxy {
			g.Printf("proxy")
		}
		g.Printf("%s", sName)
	}
	g.Printf("_%s(JNIEnv* env, ", o.Name())
	if sName != "" {
		g.Printf("jobject this")
	} else {
		g.Printf("jclass clazz")
	}
	params := sig.Params()
	for i := 0; i < params.Len(); i++ {
		g.Printf(", ")
		v := sig.Params().At(i)
		name := paramName(params, i)
		jt := g.jniType(v.Type())
		g.Printf("%s %s", jt, name)
	}
	g.Printf(")")
}

func (g *javaGen) jniPkgName() string {
	return strings.Replace(g.javaPkgName(g.pkg), ".", "_", -1)
}

func (g *javaGen) genFuncSignature(o *types.Func, static, header bool) {
	sig := o.Type().(*types.Signature)
	res := sig.Results()

	var returnsError bool
	var ret string
	switch res.Len() {
	case 2:
		if !isErrorType(res.At(1).Type()) {
			g.errorf("second result value must be of type error: %s", o)
			return
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
		g.errorf("too many result values: %s", o)
		return
	}

	g.Printf("public ")
	if static {
		g.Printf("static ")
	}
	if !header {
		g.Printf("native ")
	}
	oName := o.Name()
	g.Printf("%s %s(", ret, oName)
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
	g.Printf(";\n")
}

func (g *javaGen) genVar(o *types.Var) {
	if t := o.Type(); !g.isSupported(t) {
		g.Printf("// skipped variable %s with unsupported type: %T\n\n", o.Name(), t)
		return
	}
	jType := g.javaType(o.Type())

	// setter
	g.Printf("public static native void set%s(%s v);\n", o.Name(), jType)

	// getter
	g.Printf("public static native %s get%s();\n\n", jType, o.Name())
}

func (g *javaGen) genJavaToC(varName string, t types.Type, mode varMode) {
	if isErrorType(t) {
		g.genJavaToC(varName, types.Typ[types.String], mode)
		return
	}
	switch t := t.(type) {
	case *types.Basic:
		switch t.Kind() {
		case types.String:
			g.Printf("nstring _%s = go_seq_from_java_string(env, %s);\n", varName, varName)
		default:
			g.Printf("%s _%s = (%s)%s;\n", g.cgoType(t), varName, g.cgoType(t), varName)
		}
	case *types.Slice:
		switch e := t.Elem().(type) {
		case *types.Basic:
			switch e.Kind() {
			case types.Uint8: // Byte.
				g.Printf("nbyteslice _%s = go_seq_from_java_bytearray(env, %s, %d);\n", varName, varName, g.toCFlag(mode == modeRetained))
			default:
				g.errorf("unsupported type: %s", t)
			}
		default:
			g.errorf("unsupported type: %s", t)
		}
	case *types.Named:
		switch u := t.Underlying().(type) {
		case *types.Interface:
			g.Printf("int32_t _%s = go_seq_to_refnum(env, %s);\n", varName, varName)
		default:
			g.errorf("unsupported named type: %s / %T", u, u)
		}
	case *types.Pointer:
		g.Printf("int32_t _%s = go_seq_to_refnum(env, %s);\n", varName, varName)
	default:
		g.Printf("%s _%s = (%s)%s;\n", g.cgoType(t), varName, g.cgoType(t), varName)
	}
}

func (g *javaGen) genCToJava(toName, fromName string, t types.Type, mode varMode) {
	if isErrorType(t) {
		g.genCToJava(toName, fromName, types.Typ[types.String], mode)
		return
	}
	switch t := t.(type) {
	case *types.Basic:
		switch t.Kind() {
		case types.String:
			g.Printf("jstring %s = go_seq_to_java_string(env, %s);\n", toName, fromName)
		case types.Bool:
			g.Printf("jboolean %s = %s ? JNI_TRUE : JNI_FALSE;\n", toName, fromName)
		default:
			g.Printf("%s %s = (%s)%s;\n", g.jniType(t), toName, g.jniType(t), fromName)
		}
	case *types.Slice:
		switch e := t.Elem().(type) {
		case *types.Basic:
			switch e.Kind() {
			case types.Uint8: // Byte.
				g.Printf("jbyteArray %s = go_seq_to_java_bytearray(env, %s, %d);\n", toName, fromName, g.toCFlag(mode == modeRetained))
			default:
				g.errorf("unsupported type: %s", t)
			}
		default:
			g.errorf("unsupported type: %s", t)
		}
	case *types.Pointer:
		// TODO(crawshaw): test *int
		// TODO(crawshaw): test **Generator
		switch t := t.Elem().(type) {
		case *types.Named:
			g.genFromRefnum(toName, fromName, t, t.Obj())
		default:
			g.errorf("unsupported type %s", t)
		}
	case *types.Named:
		switch t.Underlying().(type) {
		case *types.Interface, *types.Pointer:
			g.genFromRefnum(toName, fromName, t, t.Obj())
		default:
			g.errorf("unsupported, direct named type %s", t)
		}
	default:
		g.Printf("%s %s = (%s)%s;\n", g.jniType(t), toName, g.jniType(t), fromName)
	}
}

func (g *javaGen) genFromRefnum(toName, fromName string, t types.Type, o *types.TypeName) {
	oPkg := o.Pkg()
	if !g.validPkg(oPkg) {
		g.errorf("type %s is defined in package %s, which is not bound", t, oPkg)
		return
	}
	p := pkgPrefix(oPkg)
	g.Printf("jobject %s = go_seq_from_refnum(env, %s, proxy_class_%s_%s, proxy_class_%s_%s_cons);\n", toName, fromName, p, o.Name(), p, o.Name())
}

func (g *javaGen) gobindOpts() string {
	opts := []string{"-lang=java"}
	if g.javaPkg != "" {
		opts = append(opts, "-javapkg="+g.javaPkg)
	}
	return strings.Join(opts, " ")
}

var javaNameReplacer = strings.NewReplacer(
	"-", "_",
	".", "_",
)

func (g *javaGen) javaPkgName(pkg *types.Package) string {
	if g.javaPkg != "" {
		return g.javaPkg
	}
	s := javaNameReplacer.Replace(pkg.Name())
	// Look for Java keywords that are not Go keywords, and avoid using
	// them as a package name.
	//
	// This is not a problem for normal Go identifiers as we only expose
	// exported symbols. The upper case first letter saves everything
	// from accidentally matching except for the package name.
	//
	// Note that basic type names (like int) are not keywords in Go.
	switch s {
	case "abstract", "assert", "boolean", "byte", "catch", "char", "class",
		"do", "double", "enum", "extends", "final", "finally", "float",
		"implements", "instanceof", "int", "long", "native", "private",
		"protected", "public", "short", "static", "strictfp", "super",
		"synchronized", "this", "throw", "throws", "transient", "try",
		"void", "volatile", "while":
		s += "_"
	}
	return "go." + s
}

func (g *javaGen) className() string {
	return className(g.pkg)
}

func className(pkg *types.Package) string {
	return strings.Title(javaNameReplacer.Replace(pkg.Name()))
}

func (g *javaGen) genConst(o *types.Const) {
	if _, ok := o.Type().(*types.Basic); !ok {
		g.Printf("// skipped const %s with unsupported type: %T\n\n", o.Name(), o)
		return
	}
	// TODO(hyangah): should const names use upper cases + "_"?
	// TODO(hyangah): check invalid names.
	jType := g.javaType(o.Type())
	val := constExactString(o)
	switch b := o.Type().(*types.Basic); b.Kind() {
	case types.Int64, types.UntypedInt:
		i, exact := constant.Int64Val(o.Val())
		if !exact {
			g.errorf("const value %s for %s cannot be represented as %s", val, o.Name(), jType)
			return
		}
		val = fmt.Sprintf("%dL", i)

	case types.Float32:
		f, _ := constant.Float32Val(o.Val())
		val = fmt.Sprintf("%gf", f)

	case types.Float64, types.UntypedFloat:
		f, _ := constant.Float64Val(o.Val())
		if math.IsInf(f, 0) || math.Abs(f) > math.MaxFloat64 {
			g.errorf("const value %s for %s cannot be represented as %s", val, o.Name(), jType)
			return
		}
		val = fmt.Sprintf("%g", f)
	}
	g.Printf("public static final %s %s = %s;\n", g.javaType(o.Type()), o.Name(), val)
}

func (g *javaGen) genJNIField(o *types.TypeName, f *types.Var) {
	if t := f.Type(); !g.isSupported(t) {
		g.Printf("// skipped field %s with unsupported type: %T\n\n", o.Name(), t)
		return
	}
	// setter
	g.Printf("JNIEXPORT void JNICALL\n")
	g.Printf("Java_%s_%s_00024%s_set%s(JNIEnv *env, jobject this, %s v) {\n", g.jniPkgName(), g.className(), o.Name(), f.Name(), g.jniType(f.Type()))
	g.Indent()
	g.Printf("int32_t o = go_seq_to_refnum(env, this);\n")
	g.genJavaToC("v", f.Type(), modeRetained)
	g.Printf("proxy%s_%s_%s_Set(o, _v);\n", g.pkgPrefix, o.Name(), f.Name())
	g.genRelease("v", f.Type(), modeRetained)
	g.Outdent()
	g.Printf("}\n\n")

	// getter
	g.Printf("JNIEXPORT %s JNICALL\n", g.jniType(f.Type()))
	g.Printf("Java_%s_%s_00024%s_get%s(JNIEnv *env, jobject this) {\n", g.jniPkgName(), g.className(), o.Name(), f.Name())
	g.Indent()
	g.Printf("int32_t o = go_seq_to_refnum(env, this);\n")
	g.Printf("%s r0 = ", g.cgoType(f.Type()))
	g.Printf("proxy%s_%s_%s_Get(o);\n", g.pkgPrefix, o.Name(), f.Name())
	g.genCToJava("_r0", "r0", f.Type(), modeRetained)
	g.Printf("return _r0;\n")
	g.Outdent()
	g.Printf("}\n\n")
}

func (g *javaGen) genJNIVar(o *types.Var) {
	if t := o.Type(); !g.isSupported(t) {
		g.Printf("// skipped variable %s with unsupported type: %T\n\n", o.Name(), t)
		return
	}
	// setter
	g.Printf("JNIEXPORT void JNICALL\n")
	g.Printf("Java_%s_%s_set%s(JNIEnv *env, jclass clazz, %s v) {\n", g.jniPkgName(), g.className(), o.Name(), g.jniType(o.Type()))
	g.Indent()
	g.genJavaToC("v", o.Type(), modeRetained)
	g.Printf("var_set%s_%s(_v);\n", g.pkgPrefix, o.Name())
	g.genRelease("v", o.Type(), modeRetained)
	g.Outdent()
	g.Printf("}\n\n")

	// getter
	g.Printf("JNIEXPORT %s JNICALL\n", g.jniType(o.Type()))
	g.Printf("Java_%s_%s_get%s(JNIEnv *env, jclass clazz) {\n", g.jniPkgName(), g.className(), o.Name())
	g.Indent()
	g.Printf("%s r0 = ", g.cgoType(o.Type()))
	g.Printf("var_get%s_%s();\n", g.pkgPrefix, o.Name())
	g.genCToJava("_r0", "r0", o.Type(), modeRetained)
	g.Printf("return _r0;\n")
	g.Outdent()
	g.Printf("}\n\n")
}

func (g *javaGen) genJNIFunc(o *types.Func, sName string, proxy bool) {
	if !g.isSigSupported(o.Type()) {
		n := o.Name()
		if sName != "" {
			n = sName + "." + n
		}
		g.Printf("// skipped function %s with unsupported parameter or return types\n\n", o.Name())
		return
	}
	g.genJNIFuncSignature(o, sName, proxy)
	sig := o.Type().(*types.Signature)
	res := sig.Results()

	g.Printf(" {\n")
	g.Indent()

	if sName != "" {
		g.Printf("int32_t o = go_seq_to_refnum(env, this);\n")
	}
	params := sig.Params()
	for i := 0; i < params.Len(); i++ {
		name := paramName(params, i)
		g.genJavaToC(name, params.At(i).Type(), modeTransient)
	}
	resPrefix := ""
	if res.Len() > 0 {
		if res.Len() == 1 {
			g.Printf("%s r0 = ", g.cgoType(res.At(0).Type()))
		} else {
			resPrefix = "res."
			g.Printf("struct proxy%s_%s_%s_return res = ", g.pkgPrefix, sName, o.Name())
		}
	}
	g.Printf("proxy%s_%s_%s(", g.pkgPrefix, sName, o.Name())
	if sName != "" {
		g.Printf("o")
	}
	for i := 0; i < params.Len(); i++ {
		if i > 0 || sName != "" {
			g.Printf(", ")
		}
		g.Printf("_%s", paramName(params, i))
	}
	g.Printf(");\n")
	for i := 0; i < params.Len(); i++ {
		g.genRelease(paramName(params, i), params.At(i).Type(), modeTransient)
	}
	for i := 0; i < res.Len(); i++ {
		tn := fmt.Sprintf("_r%d", i)
		t := res.At(i).Type()
		g.genCToJava(tn, fmt.Sprintf("%sr%d", resPrefix, i), t, modeRetained)
	}
	// Go backwards so that any exception is thrown before
	// the return.
	for i := res.Len() - 1; i >= 0; i-- {
		t := res.At(i).Type()
		if !isErrorType(t) {
			g.Printf("return _r%d;\n", i)
		} else {
			g.Printf("go_seq_maybe_throw_exception(env, _r%d);\n", i)
		}
	}
	g.Outdent()
	g.Printf("}\n\n")
}

// genRelease cleans up arguments that weren't copied in genJavaToC.
func (g *javaGen) genRelease(varName string, t types.Type, mode varMode) {
	if isErrorType(t) {
		g.genRelease(varName, types.Typ[types.String], mode)
		return
	}
	switch t := t.(type) {
	case *types.Basic:
	case *types.Slice:
		switch e := t.Elem().(type) {
		case *types.Basic:
			switch e.Kind() {
			case types.Uint8: // Byte.
				if mode == modeTransient {
					g.Printf("if (_%s.ptr != NULL) {\n", varName)
					g.Printf("  (*env)->ReleaseByteArrayElements(env, %s, _%s.ptr, 0);\n", varName, varName)
					g.Printf("}\n")
				}
			}
		}
	}
}

func (g *javaGen) genMethodInterfaceProxy(oName string, m *types.Func) {
	if !g.isSigSupported(m.Type()) {
		g.Printf("// skipped method %s with unsupported parameter or return types\n\n", oName)
		return
	}
	sig := m.Type().(*types.Signature)
	params := sig.Params()
	res := sig.Results()
	g.genInterfaceMethodSignature(m, oName, false)
	g.Indent()
	// Push a JNI reference frame with a conservative capacity of two for each per parameter (Seq.Ref and Seq.Object),
	// plus extra space for the receiver, the return value, and exception (if any).
	g.Printf("JNIEnv *env = go_seq_push_local_frame(%d);\n", 2*params.Len()+10)
	g.Printf("jobject o = go_seq_from_refnum(env, refnum, proxy_class_%s_%s, proxy_class_%s_%s_cons);\n", g.pkgPrefix, oName, g.pkgPrefix, oName)
	for i := 0; i < params.Len(); i++ {
		pn := paramName(params, i)
		g.genCToJava("_"+pn, pn, params.At(i).Type(), modeTransient)
	}
	if res.Len() > 0 && !isErrorType(res.At(0).Type()) {
		t := res.At(0).Type()
		g.Printf("%s res = (*env)->Call%sMethod(env, o, ", g.jniType(t), g.jniCallType(t))
	} else {
		g.Printf("(*env)->CallVoidMethod(env, o, ")
	}
	g.Printf("mid_%s_%s", oName, m.Name())
	for i := 0; i < params.Len(); i++ {
		g.Printf(", _%s", paramName(params, i))
	}
	g.Printf(");\n")
	var retName string
	if res.Len() > 0 {
		var rets []string
		t := res.At(0).Type()
		if !isErrorType(t) {
			g.genJavaToC("res", t, modeRetained)
			retName = "_res"
			rets = append(rets, retName)
		}
		if res.Len() == 2 || isErrorType(t) {
			g.Printf("jstring exc = go_seq_get_exception_message(env);\n")
			st := types.Typ[types.String]
			g.genJavaToC("exc", st, modeRetained)
			retName = "_exc"
			rets = append(rets, "_exc")
		}

		if res.Len() > 1 {
			g.Printf("cproxy%s_%s_%s_return sres = {\n", g.pkgPrefix, oName, m.Name())
			g.Printf("	%s\n", strings.Join(rets, ", "))
			g.Printf("};\n")
			retName = "sres"
		}
	}
	g.Printf("go_seq_pop_local_frame(env);\n")
	if retName != "" {
		g.Printf("return %s;\n", retName)
	}
	g.Outdent()
	g.Printf("}\n\n")
}

func (g *javaGen) genH() error {
	g.Printf(hPreamble, g.gobindOpts(), g.pkg.Path(), g.className())
	for _, iface := range g.interfaces {
		g.Printf("extern jclass proxy_class_%s_%s;\n", g.pkgPrefix, iface.obj.Name())
		g.Printf("extern jmethodID proxy_class_%s_%s_cons;\n", g.pkgPrefix, iface.obj.Name())
		g.Printf("\n")
		for _, m := range iface.summary.callable {
			if !g.isSigSupported(m.Type()) {
				g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", iface.obj.Name(), m.Name())
				continue
			}
			g.genInterfaceMethodSignature(m, iface.obj.Name(), true)
			g.Printf("\n")
		}
	}
	for _, s := range g.structs {
		g.Printf("extern jclass proxy_class_%s_%s;\n", g.pkgPrefix, s.obj.Name())
		g.Printf("extern jmethodID proxy_class_%s_%s_cons;\n", g.pkgPrefix, s.obj.Name())
	}
	g.Printf("#endif\n")
	if len(g.err) > 0 {
		return g.err
	}
	return nil
}

func (g *javaGen) jniCallType(t types.Type) string {
	if isErrorType(t) {
		return g.jniCallType(types.Typ[types.String])
	}
	switch t := t.(type) {
	case *types.Basic:
		switch t.Kind() {
		case types.Bool, types.UntypedBool:
			return "Boolean"
		case types.Int:
			return "Long"
		case types.Int8, types.Uint8: // types.Byte
			return "Byte"
		case types.Int16:
			return "Short"
		case types.Int32, types.UntypedRune: // types.Rune
			return "Int"
		case types.Int64, types.UntypedInt:
			return "Long"
		case types.Float32:
			return "Float"
		case types.Float64, types.UntypedFloat:
			return "Double"
		case types.String, types.UntypedString:
			return "Object"
		default:
			g.errorf("unsupported basic type: %s", t)
		}
	case *types.Slice:
		return "Object"
	case *types.Pointer:
		if _, ok := t.Elem().(*types.Named); ok {
			return g.jniCallType(t.Elem())
		}
		g.errorf("unsupported pointer to type: %s", t)
	case *types.Named:
		return "Object"
	default:
		return "Object"
	}
	return "TODO"
}

func (g *javaGen) jniClassSigPrefix(pkg *types.Package) string {
	return strings.Replace(g.javaPkgName(pkg), ".", "/", -1) + "/" + className(pkg) + "$"
}

func (g *javaGen) jniSigType(T types.Type) string {
	if isErrorType(T) {
		return g.jniSigType(types.Typ[types.String])
	}
	switch T := T.(type) {
	case *types.Basic:
		switch T.Kind() {
		case types.Bool, types.UntypedBool:
			return "Z"
		case types.Int:
			return "J"
		case types.Int8:
			return "B"
		case types.Int16:
			return "S"
		case types.Int32, types.UntypedRune: // types.Rune
			return "I"
		case types.Int64, types.UntypedInt:
			return "J"
		case types.Uint8: // types.Byte
			return "B"
		case types.Float32:
			return "F"
		case types.Float64, types.UntypedFloat:
			return "D"
		case types.String, types.UntypedString:
			return "Ljava/lang/String;"
		default:
			g.errorf("unsupported basic type: %s", T)
			return "TODO"
		}
	case *types.Slice:
		return "[" + g.jniSigType(T.Elem())
	case *types.Pointer:
		if _, ok := T.Elem().(*types.Named); ok {
			return g.jniSigType(T.Elem())
		}
		g.errorf("unsupported pointer to type: %s", T)
	case *types.Named:
		return "L" + g.jniClassSigPrefix(T.Obj().Pkg()) + T.Obj().Name() + ";"
	default:
		g.errorf("unsupported jniType: %#+v, %s\n", T, T)
	}
	return "TODO"
}

func (g *javaGen) genC() error {
	g.Printf(cPreamble, g.gobindOpts(), g.pkg.Path(), g.pkg.Name())
	g.Printf("#include %q\n", g.pkg.Name()+".h")
	for _, pkg := range g.pkg.Imports() {
		if g.validPkg(pkg) {
			g.Printf("#include \"%s.h\"\n", pkg.Name())
		}
	}
	g.Printf("\n")

	for _, iface := range g.interfaces {
		g.Printf("jclass proxy_class_%s_%s;\n", g.pkgPrefix, iface.obj.Name())
		g.Printf("jmethodID proxy_class_%s_%s_cons;\n", g.pkgPrefix, iface.obj.Name())
		for _, m := range iface.summary.callable {
			if !g.isSigSupported(m.Type()) {
				g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", iface.obj.Name(), m.Name())
				continue
			}
			g.Printf("static jmethodID mid_%s_%s;\n", iface.obj.Name(), m.Name())
		}
	}
	for _, s := range g.structs {
		g.Printf("jclass proxy_class_%s_%s;\n", g.pkgPrefix, s.obj.Name())
		g.Printf("jmethodID proxy_class_%s_%s_cons;\n", g.pkgPrefix, s.obj.Name())
	}
	g.Printf("\n")
	g.Printf("JNIEXPORT void JNICALL\n")
	g.Printf("Java_%s_%s_init(JNIEnv *env, jclass _unused) {\n", g.jniPkgName(), g.className())
	g.Indent()
	g.Printf("jclass clazz;\n")
	for _, s := range g.structs {
		g.Printf("clazz = (*env)->FindClass(env, %q);\n", g.jniClassSigPrefix(s.obj.Pkg())+s.obj.Name())
		g.Printf("proxy_class_%s_%s = (*env)->NewGlobalRef(env, clazz);\n", g.pkgPrefix, s.obj.Name())
		g.Printf("proxy_class_%s_%s_cons = (*env)->GetMethodID(env, clazz, \"<init>\", \"(Lgo/Seq$Ref;)V\");\n", g.pkgPrefix, s.obj.Name())
	}
	for _, iface := range g.interfaces {
		g.Printf("clazz = (*env)->FindClass(env, %q);\n", g.jniClassSigPrefix(iface.obj.Pkg())+"proxy"+iface.obj.Name())
		g.Printf("proxy_class_%s_%s = (*env)->NewGlobalRef(env, clazz);\n", g.pkgPrefix, iface.obj.Name())
		g.Printf("proxy_class_%s_%s_cons = (*env)->GetMethodID(env, clazz, \"<init>\", \"(Lgo/Seq$Ref;)V\");\n", g.pkgPrefix, iface.obj.Name())
		g.Printf("clazz = (*env)->FindClass(env, %q);\n", g.jniClassSigPrefix(iface.obj.Pkg())+iface.obj.Name())
		for _, m := range iface.summary.callable {
			if !g.isSigSupported(m.Type()) {
				g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", iface.obj.Name(), m.Name())
				continue
			}
			sig := m.Type().(*types.Signature)
			res := sig.Results()
			retSig := "V"
			if res.Len() > 0 {
				if t := res.At(0).Type(); !isErrorType(t) {
					retSig = g.jniSigType(t)
				}
			}
			var jniParams string
			params := sig.Params()
			for i := 0; i < params.Len(); i++ {
				jniParams += g.jniSigType(params.At(i).Type())
			}
			g.Printf("mid_%s_%s = (*env)->GetMethodID(env, clazz, %q, \"(%s)%s\");\n",
				iface.obj.Name(), m.Name(), m.Name(), jniParams, retSig)
		}
		g.Printf("\n")
	}
	g.Outdent()
	g.Printf("}\n\n")
	for _, f := range g.funcs {
		g.genJNIFunc(f, "", false)
	}
	for _, s := range g.structs {
		sName := s.obj.Name()
		for _, m := range exportedMethodSet(types.NewPointer(s.obj.Type())) {
			g.genJNIFunc(m, sName, false)
		}
		for _, f := range exportedFields(s.t) {
			g.genJNIField(s.obj, f)
		}
	}
	for _, iface := range g.interfaces {
		for _, m := range iface.summary.callable {
			g.genJNIFunc(m, iface.obj.Name(), true)
			g.genMethodInterfaceProxy(iface.obj.Name(), m)
		}
	}
	for _, v := range g.vars {
		g.genJNIVar(v)
	}
	if len(g.err) > 0 {
		return g.err
	}
	return nil
}

func (g *javaGen) genJava() error {
	g.Printf(javaPreamble, g.javaPkgName(g.pkg), g.className(), g.gobindOpts(), g.pkg.Path())

	g.Printf("public abstract class %s {\n", g.className())
	g.Indent()
	g.Printf("static {\n")
	g.Indent()
	g.Printf("Seq.touch(); // for loading the native library\n")
	for _, p := range g.pkg.Imports() {
		if g.validPkg(p) {
			g.Printf("%s.%s.touch();\n", g.javaPkgName(p), className(p))
		}
	}
	g.Printf("init();\n")
	g.Outdent()
	g.Printf("}\n\n")
	g.Printf("private %s() {} // uninstantiable\n\n", g.className())
	g.Printf("// touch is called from other bound packages to initialize this package\n")
	g.Printf("public static void touch() {}\n\n")
	g.Printf("private static native void init();\n\n")

	for _, s := range g.structs {
		g.genStruct(s.obj, s.t)
	}
	for _, iface := range g.interfaces {
		g.genInterface(iface)
	}
	for _, c := range g.constants {
		g.genConst(c)
	}
	g.Printf("\n")
	for _, v := range g.vars {
		g.genVar(v)
	}
	for _, f := range g.funcs {
		if !g.isSigSupported(f.Type()) {
			g.Printf("// skipped function %s with unsupported parameter or return types\n\n", f.Name())
			continue
		}
		g.genFuncSignature(f, true, false)
	}

	g.Outdent()
	g.Printf("}\n")

	if len(g.err) > 0 {
		return g.err
	}
	return nil
}

const (
	javaProxyPreamble = `private static final class proxy%[1]s extends Seq.Proxy implements %[1]s {
    proxy%[1]s(Seq.Ref ref) { super(ref); }

`
	javaPreamble = `// Java class %[1]s.%[2]s is a proxy for talking to a Go program.
//   gobind %[3]s %[4]s
//
// File is generated by gobind. Do not edit.
package %[1]s;

import go.Seq;

`
	cPreamble = `// JNI functions for the Go <=> Java bridge.
//   gobind %[1]s %[2]s
//
// File is generated by gobind. Do not edit.

#include <android/log.h>
#include <stdint.h>
#include "seq.h"
#include "_cgo_export.h"
`

	hPreamble = `// JNI function headers for the Go <=> Java bridge.
//   gobind %[1]s %[2]s
//
// File is generated by gobind. Do not edit.

#ifndef __%[3]s_H__
#define __%[3]s_H__

#include <jni.h>

`
)
