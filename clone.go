package otto

import (
	"fmt"
)

type _clone struct {
	runtime      *_runtime
	_object      map[*_object]*_object
	_objectStash map[*_objectStash]*_objectStash
	_dclStash    map[*_dclStash]*_dclStash
}

func (runtime *_runtime) clone() *_runtime {

	self := &_runtime{}
	clone := _clone{
		runtime:      self,
		_object:      make(map[*_object]*_object),
		_objectStash: make(map[*_objectStash]*_objectStash),
		_dclStash:    make(map[*_dclStash]*_dclStash),
	}

	globalObject := clone.object(runtime.globalObject)
	self.globalStash = self.newObjectStash(globalObject, nil)
	self.globalObject = globalObject
	self.global = _global{
		clone.object(runtime.global.Object),
		clone.object(runtime.global.Function),
		clone.object(runtime.global.Array),
		clone.object(runtime.global.String),
		clone.object(runtime.global.Boolean),
		clone.object(runtime.global.Number),
		clone.object(runtime.global.Math),
		clone.object(runtime.global.Date),
		clone.object(runtime.global.RegExp),
		clone.object(runtime.global.Error),
		clone.object(runtime.global.EvalError),
		clone.object(runtime.global.TypeError),
		clone.object(runtime.global.RangeError),
		clone.object(runtime.global.ReferenceError),
		clone.object(runtime.global.SyntaxError),
		clone.object(runtime.global.URIError),
		clone.object(runtime.global.JSON),

		clone.object(runtime.global.ObjectPrototype),
		clone.object(runtime.global.FunctionPrototype),
		clone.object(runtime.global.ArrayPrototype),
		clone.object(runtime.global.StringPrototype),
		clone.object(runtime.global.BooleanPrototype),
		clone.object(runtime.global.NumberPrototype),
		clone.object(runtime.global.DatePrototype),
		clone.object(runtime.global.RegExpPrototype),
		clone.object(runtime.global.ErrorPrototype),
		clone.object(runtime.global.EvalErrorPrototype),
		clone.object(runtime.global.TypeErrorPrototype),
		clone.object(runtime.global.RangeErrorPrototype),
		clone.object(runtime.global.ReferenceErrorPrototype),
		clone.object(runtime.global.SyntaxErrorPrototype),
		clone.object(runtime.global.URIErrorPrototype),
	}

	self.enterGlobalScope()

	self.eval = self.globalObject.property["eval"].value.(Value).value.(*_object)
	self.globalObject.prototype = self.global.ObjectPrototype

	// Not sure if this is necessary, but give some help to the GC
	clone.runtime = nil
	clone._object = nil
	clone._objectStash = nil
	clone._dclStash = nil

	return self
}

func (clone *_clone) object(in *_object) *_object {
	if out, exists := clone._object[in]; exists {
		return out
	}
	out := &_object{}
	clone._object[in] = out
	return in.objectClass.clone(in, out, clone)
}

func (clone *_clone) dclStash(in *_dclStash) (*_dclStash, bool) {
	if out, exists := clone._dclStash[in]; exists {
		return out, true
	}
	out := &_dclStash{}
	clone._dclStash[in] = out
	return out, false
}

func (clone *_clone) objectStash(in *_objectStash) (*_objectStash, bool) {
	if out, exists := clone._objectStash[in]; exists {
		return out, true
	}
	out := &_objectStash{}
	clone._objectStash[in] = out
	return out, false
}

func (clone *_clone) value(in Value) Value {
	out := in
	switch value := in.value.(type) {
	case *_object:
		out.value = clone.object(value)
	}
	return out
}

func (clone *_clone) valueArray(in []Value) []Value {
	out := make([]Value, len(in))
	for index, value := range in {
		out[index] = clone.value(value)
	}
	return out
}

func (clone *_clone) stash(in _stash) _stash {
	if in == nil {
		return nil
	}
	return in.clone(clone)
}

func (clone *_clone) property(in _property) _property {
	out := in
	if value, valid := in.value.(Value); valid {
		out.value = clone.value(value)
	} else {
		panic(fmt.Errorf("in.value.(Value) != true"))
	}
	return out
}

func (clone *_clone) dclProperty(in _dclProperty) _dclProperty {
	out := in
	out.value = clone.value(in.value)
	return out
}
