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
	clone := &_clone{
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

	return self
}
func (clone *_clone) object(self0 *_object) *_object {
	if self1, exists := clone._object[self0]; exists {
		return self1
	}
	self1 := &_object{}
	clone._object[self0] = self1
	return self0.objectClass.clone(self0, self1, clone)
}

func (clone *_clone) dclStash(self0 *_dclStash) (*_dclStash, bool) {
	if self1, exists := clone._dclStash[self0]; exists {
		return self1, true
	}
	self1 := &_dclStash{}
	clone._dclStash[self0] = self1
	return self1, false
}

func (clone *_clone) objectStash(self0 *_objectStash) (*_objectStash, bool) {
	if self1, exists := clone._objectStash[self0]; exists {
		return self1, true
	}
	self1 := &_objectStash{}
	clone._objectStash[self0] = self1
	return self1, false
}

func (clone *_clone) value(self0 Value) Value {
	self1 := self0
	switch value := self0.value.(type) {
	case *_object:
		self1.value = clone.object(value)
	}
	return self1
}

func (clone *_clone) valueArray(self0 []Value) []Value {
	self1 := make([]Value, len(self0))
	for index, value := range self0 {
		self1[index] = clone.value(value)
	}
	return self1
}

func (clone *_clone) stash(in _stash) _stash {
	if in == nil {
		return nil
	}
	return in.clone(clone)
}

func (clone *_clone) property(self0 _property) _property {
	self1 := self0
	if value, valid := self0.value.(Value); valid {
		self1.value = clone.value(value)
	} else {
		panic(fmt.Errorf("self0.value.(Value) != true"))
	}
	return self1
}

func (clone *_clone) dclProperty(self0 _dclProperty) _dclProperty {
	self1 := self0
	self1.value = clone.value(self0.value)
	return self1
}
