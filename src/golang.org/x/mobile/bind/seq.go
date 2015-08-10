package bind

import (
	"fmt"
	"go/types"
)

// seqType returns a string that can be used for reading and writing a
// type using the seq library.
// TODO(hyangah): avoid panic; gobind needs to output the problematic code location.
func seqType(t types.Type) string {
	if isErrorType(t) {
		return "String"
	}
	switch t := t.(type) {
	case *types.Basic:
		switch t.Kind() {
		case types.Bool:
			return "Bool"
		case types.Int:
			return "Int"
		case types.Int8:
			return "Int8"
		case types.Int16:
			return "Int16"
		case types.Int32:
			return "Int32"
		case types.Int64:
			return "Int64"
		case types.Uint8: // Byte.
			// TODO(crawshaw): questionable, but vital?
			return "Byte"
		// TODO(crawshaw): case types.Uint, types.Uint16, types.Uint32, types.Uint64:
		case types.Float32:
			return "Float32"
		case types.Float64:
			return "Float64"
		case types.String:
			return "String"
		default:
			// Should be caught earlier in processing.
			panic(fmt.Sprintf("unsupported basic seqType: %s", t))
		}
	case *types.Named:
		switch u := t.Underlying().(type) {
		case *types.Interface:
			return "Ref"
		default:
			panic(fmt.Sprintf("unsupported named seqType: %s / %T", u, u))
		}
	case *types.Slice:
		switch e := t.Elem().(type) {
		case *types.Basic:
			switch e.Kind() {
			case types.Uint8: // Byte.
				return "ByteArray"
			default:
				panic(fmt.Sprintf("unsupported seqType: %s(%s) / %T(%T)", t, e, t, e))
			}
		default:
			panic(fmt.Sprintf("unsupported seqType: %s(%s) / %T(%T)", t, e, t, e))
		}
	// TODO: let the types.Array case handled like types.Slice?
	case *types.Pointer:
		if _, ok := t.Elem().(*types.Named); ok {
			return "Ref"
		}
		panic(fmt.Sprintf("not supported yet, pointer type: %s / %T", t, t))

	default:
		panic(fmt.Sprintf("unsupported seqType: %s / %T", t, t))
	}
}

func seqRead(o types.Type) string {
	t := seqType(o)
	return t + "()"
}

func seqWrite(o types.Type, name string) string {
	t := seqType(o)
	if t == "Ref" {
		// TODO(crawshaw): do something cleaner, i.e. genWrite.
		return t + "(" + name + ".ref())"
	}
	return t + "(" + name + ")"
}
