// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package bind

import (
	"fmt"
	"go/constant"
	"go/types"
	"math"
	"strings"
	"unicode"
	"unicode/utf8"
)

// TODO(hyangah): handle method name conflicts.
//   - struct with SetF method and exported F field.
//   - method names conflicting with NSObject methods. e.g. Init
//   - interface type with InitWithRef.

// TODO(hyangah): error code/domain propagation

type objcGen struct {
	prefix string // prefix arg passed by flag.

	// fields set by init.
	namePrefix string

	*generator
}

type interfaceInfo struct {
	obj     *types.TypeName
	t       *types.Interface
	summary ifaceSummary
}

type structInfo struct {
	obj *types.TypeName
	t   *types.Struct
}

func (g *objcGen) init() {
	g.generator.init()
	g.namePrefix = g.namePrefixOf(g.pkg)
}

func (g *objcGen) namePrefixOf(pkg *types.Package) string {
	p := g.prefix
	if p == "" {
		p = "Go"
	}
	return p + strings.Title(pkg.Name())
}

func (g *objcGen) genGoH() error {
	g.Printf(objcPreamble, g.pkg.Path(), g.gobindOpts(), g.pkg.Path())
	g.Printf("#ifndef __%s_H__\n", g.pkgName)
	g.Printf("#define __%s_H__\n\n", g.pkgName)
	g.Printf("#include <stdint.h>\n")
	g.Printf("#include <objc/objc.h>\n")

	for _, i := range g.interfaces {
		if !i.summary.implementable {
			continue
		}
		for _, m := range i.summary.callable {
			if !g.isSigSupported(m.Type()) {
				g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", i.obj.Name(), m.Name())
				continue
			}
			g.genInterfaceMethodSignature(m, i.obj.Name(), true)
			g.Printf("\n")
		}
	}

	g.Printf("#endif\n")

	if len(g.err) > 0 {
		return g.err
	}
	return nil
}

func (g *objcGen) genH() error {
	g.Printf(objcPreamble, g.pkg.Path(), g.gobindOpts(), g.pkg.Path())
	g.Printf("#ifndef __%s_H__\n", g.namePrefix)
	g.Printf("#define __%s_H__\n", g.namePrefix)
	g.Printf("\n")
	g.Printf("#include <Foundation/Foundation.h>\n")
	for _, pkg := range g.pkg.Imports() {
		if g.validPkg(pkg) {
			g.Printf("#include %q\n", g.namePrefixOf(pkg)+".h")
		}
	}
	g.Printf("\n")

	// Forward declaration of @class and @protocol
	for _, s := range g.structs {
		g.Printf("@class %s%s;\n", g.namePrefix, s.obj.Name())
	}
	for _, i := range g.interfaces {
		g.Printf("@protocol %s%s;\n", g.namePrefix, i.obj.Name())
		if i.summary.implementable {
			g.Printf("@class %s%s;\n", g.namePrefix, i.obj.Name())
			// Forward declaration for other cases will be handled at the beginning of genM.
		}
	}
	if len(g.structs) > 0 || len(g.interfaces) > 0 {
		g.Printf("\n")
	}

	// @interfaces
	for _, s := range g.structs {
		g.genStructH(s.obj, s.t)
		g.Printf("\n")
	}
	for _, i := range g.interfaces {
		g.genInterfaceH(i.obj, i.t)
		g.Printf("\n")
	}

	// const
	// TODO: prefix with k?, or use a class method?
	for _, obj := range g.constants {
		if _, ok := obj.Type().(*types.Basic); !ok {
			g.Printf("// skipped const %s with unsupported type: %T\n\n", obj.Name(), obj)
			continue
		}
		switch b := obj.Type().(*types.Basic); b.Kind() {
		case types.String, types.UntypedString:
			g.Printf("FOUNDATION_EXPORT NSString* const %s%s;\n", g.namePrefix, obj.Name())
		default:
			g.Printf("FOUNDATION_EXPORT const %s %s%s;\n", g.objcType(obj.Type()), g.namePrefix, obj.Name())
		}
	}
	if len(g.constants) > 0 {
		g.Printf("\n")
	}

	// var
	if len(g.vars) > 0 {
		g.Printf("@interface %s : NSObject\n", g.namePrefix)
		for _, obj := range g.vars {
			if t := obj.Type(); !g.isSupported(t) {
				g.Printf("// skipped variable %s with unsupported type: %T\n\n", obj.Name(), t)
				continue
			}
			objcType := g.objcType(obj.Type())
			g.Printf("+ (%s) %s;\n", objcType, lowerFirst(obj.Name()))
			g.Printf("+ (void) set%s:(%s)v;\n", obj.Name(), objcType)
			g.Printf("\n")
		}
		g.Printf("@end\n\n")
	}

	// static functions.
	for _, obj := range g.funcs {
		g.genFuncH(obj)
		g.Printf("\n")
	}

	for _, i := range g.interfaces {
		if i.summary.implementable {
			g.Printf("@class %s%s;\n\n", g.namePrefix, i.obj.Name())
		}
	}
	for _, i := range g.interfaces {
		if i.summary.implementable {
			// @interface Interface -- similar to what genStructH does.
			g.genInterfaceInterface(i.obj, i.summary, true)
			g.Printf("\n")
		}
	}

	g.Printf("#endif\n")

	if len(g.err) > 0 {
		return g.err
	}
	return nil
}

func (g *objcGen) gobindOpts() string {
	opts := []string{"-lang=objc"}
	if g.prefix != "" {
		opts = append(opts, "-prefix="+g.prefix)
	}
	return strings.Join(opts, " ")
}

func (g *objcGen) genM() error {
	g.Printf(objcPreamble, g.pkg.Path(), g.gobindOpts(), g.pkg.Path())
	g.Printf("#include <Foundation/Foundation.h>\n")
	g.Printf("#include \"seq.h\"\n")
	g.Printf("#include \"_cgo_export.h\"\n")
	g.Printf("#include %q\n", g.namePrefix+".h")
	g.Printf("\n")
	g.Printf("static NSString* errDomain = @\"go.%s\";\n", g.pkg.Path())
	g.Printf("\n")

	// struct
	for _, s := range g.structs {
		g.genStructM(s.obj, s.t)
		g.Printf("\n")
	}

	// interface
	var needProxy []*types.TypeName
	for _, i := range g.interfaces {
		if g.genInterfaceM(i.obj, i.t) {
			needProxy = append(needProxy, i.obj)
		}
		g.Printf("\n")
	}

	// const
	for _, o := range g.constants {
		g.genConstM(o)
	}
	if len(g.constants) > 0 {
		g.Printf("\n")
	}

	// vars
	if len(g.vars) > 0 {
		g.Printf("@implementation %s\n", g.namePrefix)
		for _, o := range g.vars {
			g.genVarM(o)
		}
		g.Printf("@end\n\n")
	}

	g.Printf("\n")

	for _, obj := range g.funcs {
		if !g.isSigSupported(obj.Type()) {
			g.Printf("// skipped function %s with unsupported parameter or return types\n\n", obj.Name())
			continue
		}
		g.genFuncM(obj)
		g.Printf("\n")
	}

	for _, i := range g.interfaces {
		for _, m := range i.summary.callable {
			if !g.isSigSupported(m.Type()) {
				g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", i.obj.Name(), m.Name())
				continue
			}
			g.genInterfaceMethodProxy(i.obj, m)
		}
	}

	g.Printf("__attribute__((constructor)) static void init() {\n")
	g.Indent()
	g.Printf("init_seq();\n")
	g.Outdent()
	g.Printf("}\n")

	if len(g.err) > 0 {
		return g.err
	}

	return nil
}

func (g *objcGen) genVarM(o *types.Var) {
	if t := o.Type(); !g.isSupported(t) {
		g.Printf("// skipped variable %s with unsupported type: %T\n\n", o.Name(), t)
		return
	}
	objcType := g.objcType(o.Type())

	// setter
	g.Printf("+ (void) set%s:(%s)v {\n", o.Name(), objcType)
	g.Indent()
	g.genWrite("v", o.Type(), modeRetained)
	g.Printf("var_set%s_%s(_v);\n", g.pkgPrefix, o.Name())
	g.genRelease("v", o.Type(), modeRetained)
	g.Outdent()
	g.Printf("}\n\n")

	// getter
	g.Printf("+ (%s) %s {\n", objcType, lowerFirst(o.Name()))
	g.Indent()
	g.Printf("%s r0 = ", g.cgoType(o.Type()))
	g.Printf("var_get%s_%s();\n", g.pkgPrefix, o.Name())
	g.genRead("_r0", "r0", o.Type(), modeRetained)
	g.Printf("return _r0;\n")
	g.Outdent()
	g.Printf("}\n\n")
}

func (g *objcGen) genConstM(o *types.Const) {
	if _, ok := o.Type().(*types.Basic); !ok {
		g.Printf("// skipped const %s with unsupported type: %T\n\n", o.Name(), o)
		return
	}
	cName := fmt.Sprintf("%s%s", g.namePrefix, o.Name())
	objcType := g.objcType(o.Type())

	switch b := o.Type().(*types.Basic); b.Kind() {
	case types.Bool, types.UntypedBool:
		v := "NO"
		if constant.BoolVal(o.Val()) {
			v = "YES"
		}
		g.Printf("const BOOL %s = %s;\n", cName, v)

	case types.String, types.UntypedString:
		g.Printf("NSString* const %s = @%s;\n", cName, constExactString(o))

	case types.Int, types.Int8, types.Int16, types.Int32:
		g.Printf("const %s %s = %s;\n", objcType, cName, o.Val())

	case types.Int64, types.UntypedInt:
		i, exact := constant.Int64Val(o.Val())
		if !exact {
			g.errorf("const value %s for %s cannot be represented as %s", o.Val(), o.Name(), objcType)
			return
		}
		if i == math.MinInt64 {
			// -9223372036854775808LL does not work because 922337203685477508 is
			// larger than max int64.
			g.Printf("const int64_t %s = %dLL-1;\n", cName, i+1)
		} else {
			g.Printf("const int64_t %s = %dLL;\n", cName, i)
		}

	case types.Float32, types.Float64, types.UntypedFloat:
		f, _ := constant.Float64Val(o.Val())
		if math.IsInf(f, 0) || math.Abs(f) > math.MaxFloat64 {
			g.errorf("const value %s for %s cannot be represented as double", o.Val(), o.Name())
			return
		}
		g.Printf("const %s %s = %g;\n", objcType, cName, f)

	default:
		g.errorf("unsupported const type %s for %s", b, o.Name())
	}
}

type funcSummary struct {
	name              string
	ret               string
	sig               *types.Signature
	params, retParams []paramInfo
}

type paramInfo struct {
	typ  types.Type
	name string
}

func (g *objcGen) funcSummary(obj *types.Func) *funcSummary {
	sig := obj.Type().(*types.Signature)
	s := &funcSummary{name: obj.Name(), sig: sig}

	params := sig.Params()
	for i := 0; i < params.Len(); i++ {
		p := params.At(i)
		v := paramInfo{
			typ:  p.Type(),
			name: paramName(params, i),
		}
		s.params = append(s.params, v)
	}

	res := sig.Results()
	switch res.Len() {
	case 0:
		s.ret = "void"
	case 1:
		p := res.At(0)
		if isErrorType(p.Type()) {
			s.retParams = append(s.retParams, paramInfo{
				typ:  p.Type(),
				name: "error",
			})
			s.ret = "BOOL"
		} else {
			name := p.Name()
			if name == "" || paramRE.MatchString(name) {
				name = "ret0_"
			}
			typ := p.Type()
			s.retParams = append(s.retParams, paramInfo{typ: typ, name: name})
			s.ret = g.objcType(typ)
		}
	case 2:
		name := res.At(0).Name()
		if name == "" || paramRE.MatchString(name) {
			name = "ret0_"
		}
		s.retParams = append(s.retParams, paramInfo{
			typ:  res.At(0).Type(),
			name: name,
		})

		if !isErrorType(res.At(1).Type()) {
			g.errorf("second result value must be of type error: %s", obj)
			return nil
		}
		s.retParams = append(s.retParams, paramInfo{
			typ:  res.At(1).Type(),
			name: "error", // TODO(hyangah): name collision check.
		})
		s.ret = "BOOL"
	default:
		// TODO(hyangah): relax the constraint on multiple return params.
		g.errorf("too many result values: %s", obj)
		return nil
	}

	return s
}

func (s *funcSummary) asFunc(g *objcGen) string {
	var params []string
	for _, p := range s.params {
		params = append(params, g.objcType(p.typ)+" "+p.name)
	}
	if !s.returnsVal() {
		for _, p := range s.retParams {
			params = append(params, g.objcType(p.typ)+"* "+p.name)
		}
	}
	return fmt.Sprintf("%s %s%s(%s)", s.ret, g.namePrefix, s.name, strings.Join(params, ", "))
}

func (s *funcSummary) asMethod(g *objcGen) string {
	var params []string
	for i, p := range s.params {
		var key string
		if i != 0 {
			key = p.name
		}
		params = append(params, fmt.Sprintf("%s:(%s)%s", key, g.objcType(p.typ), p.name))
	}
	if !s.returnsVal() {
		for _, p := range s.retParams {
			var key string
			if len(params) > 0 {
				key = p.name
			}
			params = append(params, fmt.Sprintf("%s:(%s)%s", key, g.objcType(p.typ)+"*", p.name))
		}
	}
	return fmt.Sprintf("(%s)%s%s", s.ret, lowerFirst(s.name), strings.Join(params, " "))
}

func (s *funcSummary) callMethod(g *objcGen) string {
	var params []string
	for i, p := range s.params {
		var key string
		if i != 0 {
			key = p.name
		}
		params = append(params, fmt.Sprintf("%s:_%s", key, p.name))
	}
	if !s.returnsVal() {
		for _, p := range s.retParams {
			var key string
			if len(params) > 0 {
				key = p.name
			}
			params = append(params, fmt.Sprintf("%s:&%s", key, p.name))
		}
	}
	return fmt.Sprintf("%s%s", lowerFirst(s.name), strings.Join(params, " "))
}

func (s *funcSummary) returnsVal() bool {
	return len(s.retParams) == 1 && !isErrorType(s.retParams[0].typ)
}

func (g *objcGen) genFuncH(obj *types.Func) {
	if !g.isSigSupported(obj.Type()) {
		g.Printf("// skipped function %s with unsupported parameter or return types\n\n", obj.Name())
		return
	}
	if s := g.funcSummary(obj); s != nil {
		g.Printf("FOUNDATION_EXPORT %s;\n", s.asFunc(g))
	}
}

func (g *objcGen) genFuncM(obj *types.Func) {
	s := g.funcSummary(obj)
	if s == nil {
		return
	}
	g.Printf("%s {\n", s.asFunc(g))
	g.Indent()
	g.genFunc(s, "")
	g.Outdent()
	g.Printf("}\n")
}

func (g *objcGen) genGetter(oName string, f *types.Var) {
	t := f.Type()
	if isErrorType(t) {
		t = types.Typ[types.String]
	}
	g.Printf("- (%s)%s {\n", g.objcType(t), lowerFirst(f.Name()))
	g.Indent()
	g.Printf("int32_t refnum = go_seq_go_to_refnum(self._ref);\n")
	g.Printf("%s r0 = ", g.cgoType(f.Type()))
	g.Printf("proxy%s_%s_%s_Get(refnum);\n", g.pkgPrefix, oName, f.Name())
	g.genRead("_r0", "r0", f.Type(), modeRetained)
	g.Printf("return _r0;\n")
	g.Outdent()
	g.Printf("}\n\n")
}

func (g *objcGen) genSetter(oName string, f *types.Var) {
	t := f.Type()
	if isErrorType(t) {
		t = types.Typ[types.String]
	}

	g.Printf("- (void)set%s:(%s)v {\n", f.Name(), g.objcType(t))
	g.Indent()
	g.Printf("int32_t refnum = go_seq_go_to_refnum(self._ref);\n")
	g.genWrite("v", f.Type(), modeRetained)
	g.Printf("proxy%s_%s_%s_Set(refnum, _v);\n", g.pkgPrefix, oName, f.Name())
	g.genRelease("v", f.Type(), modeRetained)
	g.Outdent()
	g.Printf("}\n\n")
}

func (g *objcGen) genWrite(varName string, t types.Type, mode varMode) {
	if isErrorType(t) {
		g.genWrite(varName, types.Typ[types.String], mode)
		return
	}
	switch t := t.(type) {
	case *types.Basic:
		switch t.Kind() {
		case types.String:
			g.Printf("nstring _%s = go_seq_from_objc_string(%s);\n", varName, varName)
		default:
			g.Printf("%s _%s = (%s)%s;\n", g.cgoType(t), varName, g.cgoType(t), varName)
		}
	case *types.Slice:
		switch e := t.Elem().(type) {
		case *types.Basic:
			switch e.Kind() {
			case types.Uint8: // Byte.
				g.Printf("nbyteslice _%s = go_seq_from_objc_bytearray(%s, %d);\n", varName, varName, g.toCFlag(mode == modeRetained))
			default:
				g.errorf("unsupported type: %s", t)
			}
		default:
			g.errorf("unsupported type: %s", t)
		}
	case *types.Named:
		switch u := t.Underlying().(type) {
		case *types.Interface:
			g.genRefWrite(varName, t)
		default:
			g.errorf("unsupported named type: %s / %T", u, u)
		}
	case *types.Pointer:
		g.genRefWrite(varName, t)
	default:
		g.Printf("%s _%s = (%s)%s;\n", g.cgoType(t), varName, g.cgoType(t), varName)
	}
}

func (g *objcGen) genRefWrite(varName string, t types.Type) {
	g.Printf("int32_t _%s;\n", varName)
	g.Printf("if ([(id<NSObject>)(%s) isKindOfClass:[%s class]]) {\n", varName, g.refTypeBase(t))
	g.Indent()
	g.Printf("id<goSeqRefInterface> %[1]s_proxy = (id<goSeqRefInterface>)(%[1]s);\n", varName)
	g.Printf("_%s = go_seq_go_to_refnum(%s_proxy._ref);\n", varName, varName)
	g.Outdent()
	g.Printf("} else {\n")
	g.Indent()
	g.Printf("_%s = go_seq_to_refnum(%s);\n", varName, varName)
	g.Outdent()
	g.Printf("}\n")
}

func (g *objcGen) genRefRead(toName, fromName string, t types.Type) {
	ptype := g.objcType(t)
	g.Printf("%s %s = nil;\n", ptype, toName)
	g.Printf("GoSeqRef* %s_ref = go_seq_from_refnum(%s);\n", toName, fromName)
	g.Printf("if (%s_ref != NULL) {\n", toName)
	g.Printf("	%s = %s_ref.obj;\n", toName, toName)
	g.Printf("	if (%s == nil) {\n", toName)
	g.Printf("		%s = [[%s alloc] initWithRef:%s_ref];\n", toName, g.refTypeBase(t), toName)
	g.Printf("	}\n")
	g.Printf("}\n")
}

func (g *objcGen) genRead(toName, fromName string, t types.Type, mode varMode) {
	if isErrorType(t) {
		g.genRead(toName, fromName, types.Typ[types.String], mode)
		return
	}
	switch t := t.(type) {
	case *types.Basic:
		switch t.Kind() {
		case types.String:
			g.Printf("NSString *%s = go_seq_to_objc_string(%s);\n", toName, fromName)
		case types.Bool:
			g.Printf("BOOL %s = %s ? YES : NO;\n", toName, fromName)
		default:
			g.Printf("%s %s = (%s)%s;\n", g.objcType(t), toName, g.objcType(t), fromName)
		}
	case *types.Slice:
		switch e := t.Elem().(type) {
		case *types.Basic:
			switch e.Kind() {
			case types.Uint8: // Byte.
				g.Printf("NSData *%s = go_seq_to_objc_bytearray(%s, %d);\n", toName, fromName, g.toCFlag(mode == modeRetained))
			default:
				g.errorf("unsupported type: %s", t)
			}
		default:
			g.errorf("unsupported type: %s", t)
		}
	case *types.Pointer:
		switch t := t.Elem().(type) {
		case *types.Named:
			g.genRefRead(toName, fromName, types.NewPointer(t))
		default:
			g.errorf("unsupported type %s", t)
		}
	case *types.Named:
		switch t.Underlying().(type) {
		case *types.Interface, *types.Pointer:
			g.genRefRead(toName, fromName, t)
		default:
			g.errorf("unsupported, direct named type %s", t)
		}
	default:
		g.Printf("%s %s = (%s)%s;\n", g.objcType(t), toName, g.objcType(t), fromName)
	}
}

func (g *objcGen) genFunc(s *funcSummary, objName string) {
	if objName != "" {
		g.Printf("int32_t refnum = go_seq_go_to_refnum(self._ref);\n")
	}
	for _, p := range s.params {
		g.genWrite(p.name, p.typ, modeTransient)
	}
	resPrefix := ""
	if len(s.retParams) > 0 {
		if len(s.retParams) == 1 {
			g.Printf("%s r0 = ", g.cgoType(s.retParams[0].typ))
		} else {
			resPrefix = "res."
			g.Printf("struct proxy%s_%s_%s_return res = ", g.pkgPrefix, objName, s.name)
		}
	}
	g.Printf("proxy%s_%s_%s(", g.pkgPrefix, objName, s.name)
	if objName != "" {
		g.Printf("refnum")
	}
	for i, p := range s.params {
		if i > 0 || objName != "" {
			g.Printf(", ")
		}
		g.Printf("_%s", p.name)
	}
	g.Printf(");\n")
	for _, p := range s.params {
		g.genRelease(p.name, p.typ, modeTransient)
	}

	for i, r := range s.retParams {
		g.genRead("_"+r.name, fmt.Sprintf("%sr%d", resPrefix, i), r.typ, modeRetained)
	}

	if !s.returnsVal() {
		for _, p := range s.retParams {
			if isErrorType(p.typ) {
				g.Printf("if ([_%s length] != 0 && %s != nil) {\n", p.name, p.name)
				g.Indent()
				g.Printf("NSMutableDictionary* details = [NSMutableDictionary dictionary];\n")
				g.Printf("[details setValue:_%s forKey:NSLocalizedDescriptionKey];\n", p.name)
				g.Printf("*%s = [NSError errorWithDomain:errDomain code:1 userInfo:details];\n", p.name)
				g.Outdent()
				g.Printf("}\n")
			} else {
				g.Printf("*%s = _%s;\n", p.name, p.name)
			}
		}
	}

	if n := len(s.retParams); n > 0 {
		p := s.retParams[n-1]
		if isErrorType(p.typ) {
			g.Printf("return ([_%s length] == 0);\n", p.name)
		} else {
			g.Printf("return _%s;\n", p.name)
		}
	}
}

func (g *objcGen) genInterfaceInterface(obj *types.TypeName, summary ifaceSummary, isProtocol bool) {
	g.Printf("@interface %[1]s%[2]s : NSObject", g.namePrefix, obj.Name())
	if isProtocol {
		g.Printf(" <%[1]s%[2]s>", g.namePrefix, obj.Name())
	}
	g.Printf(" {\n}\n")
	g.Printf("@property(strong, readonly) id _ref;\n")
	g.Printf("\n")
	g.Printf("- (id)initWithRef:(id)ref;\n")
	for _, m := range summary.callable {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", obj.Name(), m.Name())
			return
		}
		s := g.funcSummary(m)
		g.Printf("- %s;\n", s.asMethod(g))
	}
	g.Printf("@end\n")
}

func (g *objcGen) genInterfaceH(obj *types.TypeName, t *types.Interface) {
	summary := makeIfaceSummary(t)
	if !summary.implementable {
		g.genInterfaceInterface(obj, summary, false)
		return
	}
	g.Printf("@protocol %s%s\n", g.namePrefix, obj.Name())
	for _, m := range makeIfaceSummary(t).callable {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", obj.Name(), m.Name())
			continue
		}
		s := g.funcSummary(m)
		g.Printf("- %s;\n", s.asMethod(g))
	}
	g.Printf("@end\n")
}

func (g *objcGen) genInterfaceM(obj *types.TypeName, t *types.Interface) bool {
	summary := makeIfaceSummary(t)

	// @implementation Interface -- similar to what genStructM does.
	g.Printf("@implementation %s%s {\n", g.namePrefix, obj.Name())
	g.Printf("}\n")
	g.Printf("\n")
	g.Printf("- (id)initWithRef:(id)ref {\n")
	g.Indent()
	g.Printf("self = [super init];\n")
	g.Printf("if (self) { __ref = ref; }\n")
	g.Printf("return self;\n")
	g.Outdent()
	g.Printf("}\n")
	g.Printf("\n")

	for _, m := range summary.callable {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", obj.Name(), m.Name())
			continue
		}
		s := g.funcSummary(m)
		g.Printf("- %s {\n", s.asMethod(g))
		g.Indent()
		g.genFunc(s, obj.Name())
		g.Outdent()
		g.Printf("}\n\n")
	}
	g.Printf("@end\n")
	g.Printf("\n")

	return summary.implementable
}

func (g *objcGen) genInterfaceMethodProxy(obj *types.TypeName, m *types.Func) {
	oName := obj.Name()
	s := g.funcSummary(m)
	g.genInterfaceMethodSignature(m, oName, false)
	g.Indent()
	g.Printf("@autoreleasepool {\n")
	g.Indent()
	g.Printf("%s o = go_seq_objc_from_refnum(refnum);\n", g.objcType(obj.Type()))
	for _, p := range s.params {
		g.genRead("_"+p.name, p.name, p.typ, modeTransient)
	}

	// call method
	if !s.returnsVal() {
		for _, p := range s.retParams {
			if isErrorType(p.typ) {
				g.Printf("NSError* %s = nil;\n", p.name)
			} else {
				g.Printf("%s %s;\n", g.objcType(p.typ), p.name)
			}
		}
	}

	if s.ret == "void" {
		g.Printf("[o %s];\n", s.callMethod(g))
	} else {
		g.Printf("%s returnVal = [o %s];\n", s.ret, s.callMethod(g))
	}

	if len(s.retParams) > 0 {
		if s.returnsVal() { // len(s.retParams) == 1 && s.retParams[0] != error
			p := s.retParams[0]
			g.genWrite("returnVal", p.typ, modeRetained)
			g.Printf("return _returnVal;\n")
		} else {
			var rets []string
			for i, p := range s.retParams {
				if isErrorType(p.typ) {
					g.Printf("NSString *%s_str = nil;\n", p.name)
					if i == len(s.retParams)-1 { // last param.
						g.Printf("if (!returnVal) {\n")
					} else {
						g.Printf("if (%s != nil) {\n", p.name)
					}
					g.Indent()
					g.Printf("%[1]s_str = [%[1]s localizedDescription];\n", p.name)
					g.Printf("if (%[1]s_str == nil || %[1]s_str.length == 0) {\n", p.name)
					g.Indent()
					g.Printf("%[1]s_str = @\"gobind: unknown error\";\n", p.name)
					g.Outdent()
					g.Printf("}\n")
					g.Outdent()
					g.Printf("}\n")
					g.genWrite(p.name+"_str", p.typ, modeRetained)
					rets = append(rets, fmt.Sprintf("_%s_str", p.name))
				} else {
					g.genWrite(p.name, p.typ, modeRetained)
					rets = append(rets, "_"+p.name)
				}
			}
			if len(rets) > 1 {
				g.Printf("cproxy%s_%s_%s_return _sres = {\n", g.pkgPrefix, oName, m.Name())
				g.Printf("  %s\n", strings.Join(rets, ", "))
				g.Printf("};\n")
				g.Printf("return _sres;\n")
			} else {
				g.Printf("return %s;\n", rets[0])
			}
		}
	}
	g.Outdent()
	g.Printf("}\n")
	g.Outdent()
	g.Printf("}\n\n")
}

// genRelease cleans up arguments that weren't copied in genWrite.
func (g *objcGen) genRelease(varName string, t types.Type, mode varMode) {
	if isErrorType(t) {
		g.genRelease(varName, types.Typ[types.String], mode)
		return
	}
	switch t := t.(type) {
	case *types.Slice:
		switch e := t.Elem().(type) {
		case *types.Basic:
			switch e.Kind() {
			case types.Uint8: // Byte.
				if mode == modeTransient {
					// If the argument was not mutable, go_seq_from_objc_bytearray created a copy.
					// Free it here.
					g.Printf("if (![%s isKindOfClass:[NSMutableData class]]) {\n", varName)
					g.Printf("  free(_%s.ptr);\n", varName)
					g.Printf("}\n")
				}
			}
		}
	}
}

func (g *objcGen) genStructH(obj *types.TypeName, t *types.Struct) {
	g.Printf("@interface %s%s : NSObject {\n", g.namePrefix, obj.Name())
	g.Printf("}\n")
	g.Printf("@property(strong, readonly) id _ref;\n")
	g.Printf("\n")
	g.Printf("- (id)initWithRef:(id)ref;\n")

	// accessors to exported fields.
	for _, f := range exportedFields(t) {
		if t := f.Type(); !g.isSupported(t) {
			g.Printf("// skipped field %s.%s with unsupported type: %T\n\n", obj.Name(), f.Name(), t)
			continue
		}
		name, typ := f.Name(), g.objcFieldType(f.Type())
		g.Printf("- (%s)%s;\n", typ, lowerFirst(name))
		g.Printf("- (void)set%s:(%s)v;\n", name, typ)
	}

	// exported methods
	for _, m := range exportedMethodSet(types.NewPointer(obj.Type())) {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", obj.Name(), m.Name())
			continue
		}
		s := g.funcSummary(m)
		g.Printf("- %s;\n", lowerFirst(s.asMethod(g)))
	}
	g.Printf("@end\n")
}

func (g *objcGen) genStructM(obj *types.TypeName, t *types.Struct) {
	fields := exportedFields(t)
	methods := exportedMethodSet(types.NewPointer(obj.Type()))

	g.Printf("\n")
	g.Printf("@implementation %s%s {\n", g.namePrefix, obj.Name())
	g.Printf("}\n\n")
	g.Printf("- (id)initWithRef:(id)ref {\n")
	g.Indent()
	g.Printf("self = [super init];\n")
	g.Printf("if (self) { __ref = ref; }\n")
	g.Printf("return self;\n")
	g.Outdent()
	g.Printf("}\n\n")

	for _, f := range fields {
		if !g.isSupported(f.Type()) {
			g.Printf("// skipped unsupported field %s with type %T\n\n", f.Name(), f)
			continue
		}
		g.genGetter(obj.Name(), f)
		g.genSetter(obj.Name(), f)
	}

	for _, m := range methods {
		if !g.isSigSupported(m.Type()) {
			g.Printf("// skipped method %s.%s with unsupported parameter or return types\n\n", obj.Name(), m.Name())
			continue
		}
		s := g.funcSummary(m)
		g.Printf("- %s {\n", s.asMethod(g))
		g.Indent()
		g.genFunc(s, obj.Name())
		g.Outdent()
		g.Printf("}\n\n")
	}
	g.Printf("@end\n")
}

func (g *objcGen) errorf(format string, args ...interface{}) {
	g.err = append(g.err, fmt.Errorf(format, args...))
}

func (g *objcGen) refTypeBase(typ types.Type) string {
	switch typ := typ.(type) {
	case *types.Pointer:
		if _, ok := typ.Elem().(*types.Named); ok {
			return g.objcType(typ.Elem())
		}
	case *types.Named:
		n := typ.Obj()
		if g.validPkg(n.Pkg()) {
			switch typ.Underlying().(type) {
			case *types.Interface, *types.Struct:
				return g.namePrefixOf(n.Pkg()) + n.Name()
			}
		}
	}

	// fallback to whatever objcType returns. This must not happen.
	return g.objcType(typ)
}

func (g *objcGen) objcFieldType(t types.Type) string {
	if isErrorType(t) {
		return "NSString*"
	}
	return g.objcType(t)
}

func (g *objcGen) objcType(typ types.Type) string {
	if isErrorType(typ) {
		return "NSError*"
	}

	switch typ := typ.(type) {
	case *types.Basic:
		switch typ.Kind() {
		case types.Bool, types.UntypedBool:
			return "BOOL"
		case types.Int:
			return "int"
		case types.Int8:
			return "int8_t"
		case types.Int16:
			return "int16_t"
		case types.Int32, types.UntypedRune: // types.Rune
			return "int32_t"
		case types.Int64, types.UntypedInt:
			return "int64_t"
		case types.Uint8:
			// byte is an alias of uint8, and the alias is lost.
			return "byte"
		case types.Uint16:
			return "uint16_t"
		case types.Uint32:
			return "uint32_t"
		case types.Uint64:
			return "uint64_t"
		case types.Float32:
			return "float"
		case types.Float64, types.UntypedFloat:
			return "double"
		case types.String, types.UntypedString:
			return "NSString*"
		default:
			g.errorf("unsupported type: %s", typ)
			return "TODO"
		}
	case *types.Slice:
		elem := g.objcType(typ.Elem())
		// Special case: NSData seems to be a better option for byte slice.
		if elem == "byte" {
			return "NSData*"
		}
		// TODO(hyangah): support other slice types: NSArray or CFArrayRef.
		// Investigate the performance implication.
		g.errorf("unsupported type: %s", typ)
		return "TODO"
	case *types.Pointer:
		if _, ok := typ.Elem().(*types.Named); ok {
			return g.objcType(typ.Elem()) + "*"
		}
		g.errorf("unsupported pointer to type: %s", typ)
		return "TODO"
	case *types.Named:
		n := typ.Obj()
		if !g.validPkg(n.Pkg()) {
			g.errorf("type %s is in package %s, which is not bound", n.Name(), n.Pkg().Name())
			return "TODO"
		}
		switch t := typ.Underlying().(type) {
		case *types.Interface:
			if makeIfaceSummary(t).implementable {
				return "id<" + g.namePrefixOf(n.Pkg()) + n.Name() + ">"
			} else {
				return g.namePrefixOf(n.Pkg()) + n.Name() + "*"
			}
		case *types.Struct:
			return g.namePrefixOf(n.Pkg()) + n.Name()
		}
		g.errorf("unsupported, named type %s", typ)
		return "TODO"
	default:
		g.errorf("unsupported type: %#+v, %s", typ, typ)
		return "TODO"
	}
}

func lowerFirst(s string) string {
	if s == "" {
		return ""
	}

	var conv []rune
	for len(s) > 0 {
		r, n := utf8.DecodeRuneInString(s)
		if !unicode.IsUpper(r) {
			if l := len(conv); l > 1 {
				conv[l-1] = unicode.ToUpper(conv[l-1])
			}
			return string(conv) + s
		}
		conv = append(conv, unicode.ToLower(r))
		s = s[n:]
	}
	return string(conv)
}

const (
	objcPreamble = `// Objective-C API for talking to %[1]s Go package.
//   gobind %[2]s %[3]s
//
// File is generated by gobind. Do not edit.

`
)
