// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package bind

import (
	"fmt"
	"go/types"
	"log"
)

type ifaceSummary struct {
	iface         *types.Interface
	callable      []*types.Func
	implementable bool
}

func makeIfaceSummary(iface *types.Interface) ifaceSummary {
	summary := ifaceSummary{
		iface:         iface,
		implementable: true,
	}
	methodset := types.NewMethodSet(iface)
	for i := 0; i < methodset.Len(); i++ {
		obj := methodset.At(i).Obj()
		if !obj.Exported() {
			summary.implementable = false
			continue
		}
		m, ok := obj.(*types.Func)
		if !ok {
			log.Panicf("unexpected methodset obj: %s (%T)", obj, obj)
		}
		if !isImplementable(m.Type().(*types.Signature)) {
			summary.implementable = false
		}
		if isCallable(m) {
			summary.callable = append(summary.callable, m)
		}
	}
	return summary
}

func isCallable(t *types.Func) bool {
	// TODO(crawshaw): functions that are not implementable from
	// another language may still be callable (for example, a
	// returned value with an unexported type can be treated as
	// an opaque value by the caller). This restriction could be
	// lifted.
	return isImplementable(t.Type().(*types.Signature))
}

func isImplementable(sig *types.Signature) bool {
	params := sig.Params()
	for i := 0; i < params.Len(); i++ {
		if !isExported(params.At(i).Type()) {
			return false
		}
	}
	res := sig.Results()
	for i := 0; i < res.Len(); i++ {
		if !isExported(res.At(i).Type()) {
			return false
		}
	}
	return true
}

func exportedMethodSet(T types.Type) []*types.Func {
	var methods []*types.Func
	methodset := types.NewMethodSet(T)
	for i := 0; i < methodset.Len(); i++ {
		obj := methodset.At(i).Obj()
		if !obj.Exported() {
			continue
		}
		switch obj := obj.(type) {
		case *types.Func:
			methods = append(methods, obj)
		default:
			log.Panicf("unexpected methodset obj: %s", obj)
		}
	}
	return methods
}

func exportedFields(T *types.Struct) []*types.Var {
	var fields []*types.Var
	for i := 0; i < T.NumFields(); i++ {
		f := T.Field(i)
		if !f.Exported() {
			continue
		}
		fields = append(fields, f)
	}
	return fields
}

func isErrorType(t types.Type) bool {
	return types.Identical(t, types.Universe.Lookup("error").Type())
}

func isExported(t types.Type) bool {
	if isErrorType(t) {
		return true
	}
	switch t := t.(type) {
	case *types.Basic:
		return true
	case *types.Named:
		return t.Obj().Exported()
	case *types.Pointer:
		return isExported(t.Elem())
	default:
		return true
	}
}

func isRefType(t types.Type) bool {
	if isErrorType(t) {
		return false
	}
	switch t := t.(type) {
	case *types.Named:
		switch u := t.Underlying().(type) {
		case *types.Interface:
			return true
		default:
			panic(fmt.Sprintf("unsupported named type: %s / %T", u, u))
		}
	case *types.Pointer:
		return isRefType(t.Elem())
	default:
		return false
	}
}
