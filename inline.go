package otto

import (
	"math"
)

func _newContext(runtime *_runtime) {
	{
		runtime.Global.ObjectPrototype = &_object{
			runtime:     runtime,
			class:       "Object",
			objectClass: _classObject,
			prototype:   nil,
			extensible:  true,
			value:       prototypeValueObject,
		}
	}
	{
		runtime.Global.FunctionPrototype = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       prototypeValueFunction,
		}
	}
	{
		valueOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_valueOf),
			},
		}
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_toString),
			},
		}
		toLocaleString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_toLocaleString),
			},
		}
		hasOwnProperty_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_hasOwnProperty),
			},
		}
		isPrototypeOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_isPrototypeOf),
			},
		}
		propertyIsEnumerable_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_propertyIsEnumerable),
			},
		}
		runtime.Global.ObjectPrototype.property = map[string]_property{
			"valueOf": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      valueOf_function,
				},
			},
			"toString": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      toString_function,
				},
			},
			"toLocaleString": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      toLocaleString_function,
				},
			},
			"hasOwnProperty": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      hasOwnProperty_function,
				},
			},
			"isPrototypeOf": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      isPrototypeOf_function,
				},
			},
			"propertyIsEnumerable": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      propertyIsEnumerable_function,
				},
			},
			"constructor": _property{
				mode:  0101,
				value: Value{},
			},
		}
		runtime.Global.ObjectPrototype.propertyOrder = []string{
			"valueOf",
			"toString",
			"toLocaleString",
			"hasOwnProperty",
			"isPrototypeOf",
			"propertyIsEnumerable",
			"constructor",
		}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinFunction_toString),
			},
		}
		apply_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinFunction_apply),
			},
		}
		call_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinFunction_call),
			},
		}
		bind_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinFunction_bind),
			},
		}
		runtime.Global.FunctionPrototype.property = map[string]_property{
			"toString": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      toString_function,
				},
			},
			"apply": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      apply_function,
				},
			},
			"call": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      call_function,
				},
			},
			"bind": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      bind_function,
				},
			},
			"constructor": _property{
				mode:  0101,
				value: Value{},
			},
			"length": _property{
				mode: 0,
				value: Value{
					_valueType: valueNumber,
					value:      0,
				},
			},
		}
		runtime.Global.FunctionPrototype.propertyOrder = []string{
			"toString",
			"apply",
			"call",
			"bind",
			"constructor",
			"length",
		}
	}
	{
		getPrototypeOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_getPrototypeOf),
			},
		}
		getOwnPropertyDescriptor_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_getOwnPropertyDescriptor),
			},
		}
		defineProperty_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      3,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_defineProperty),
			},
		}
		defineProperties_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_defineProperties),
			},
		}
		create_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_create),
			},
		}
		isExtensible_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_isExtensible),
			},
		}
		preventExtensions_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_preventExtensions),
			},
		}
		isSealed_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_isSealed),
			},
		}
		seal_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_seal),
			},
		}
		isFrozen_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_isFrozen),
			},
		}
		freeze_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_freeze),
			},
		}
		keys_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_keys),
			},
		}
		getOwnPropertyNames_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinObject_getOwnPropertyNames),
			},
		}
		runtime.Global.Object = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinObject),
				construct: builtinNewObject,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.ObjectPrototype,
					},
				},
				"getPrototypeOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getPrototypeOf_function,
					},
				},
				"getOwnPropertyDescriptor": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getOwnPropertyDescriptor_function,
					},
				},
				"defineProperty": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      defineProperty_function,
					},
				},
				"defineProperties": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      defineProperties_function,
					},
				},
				"create": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      create_function,
					},
				},
				"isExtensible": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      isExtensible_function,
					},
				},
				"preventExtensions": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      preventExtensions_function,
					},
				},
				"isSealed": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      isSealed_function,
					},
				},
				"seal": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      seal_function,
					},
				},
				"isFrozen": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      isFrozen_function,
					},
				},
				"freeze": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      freeze_function,
					},
				},
				"keys": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      keys_function,
					},
				},
				"getOwnPropertyNames": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getOwnPropertyNames_function,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
				"getPrototypeOf",
				"getOwnPropertyDescriptor",
				"defineProperty",
				"defineProperties",
				"create",
				"isExtensible",
				"preventExtensions",
				"isSealed",
				"seal",
				"isFrozen",
				"freeze",
				"keys",
				"getOwnPropertyNames",
			},
		}
		runtime.Global.ObjectPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Object,
				},
			}
	}
	{
		Function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinFunction),
				construct: builtinNewFunction,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.FunctionPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.Function = Function
		runtime.Global.FunctionPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Function,
				},
			}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_toString),
			},
		}
		toLocaleString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_toLocaleString),
			},
		}
		concat_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_concat),
			},
		}
		join_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_join),
			},
		}
		splice_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_splice),
			},
		}
		shift_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_shift),
			},
		}
		pop_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_pop),
			},
		}
		push_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_push),
			},
		}
		slice_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_slice),
			},
		}
		unshift_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_unshift),
			},
		}
		reverse_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_reverse),
			},
		}
		sort_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_sort),
			},
		}
		indexOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_indexOf),
			},
		}
		lastIndexOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_lastIndexOf),
			},
		}
		every_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_every),
			},
		}
		some_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_some),
			},
		}
		forEach_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_forEach),
			},
		}
		map_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_map),
			},
		}
		filter_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_filter),
			},
		}
		reduce_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_reduce),
			},
		}
		reduceRight_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_reduceRight),
			},
		}
		isArray_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinArray_isArray),
			},
		}
		runtime.Global.ArrayPrototype = &_object{
			runtime:     runtime,
			class:       "Array",
			objectClass: _classArray,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"length": _property{
					mode: 0100,
					value: Value{
						_valueType: valueNumber,
						value:      uint32(0),
					},
				},
				"toString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toString_function,
					},
				},
				"toLocaleString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLocaleString_function,
					},
				},
				"concat": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      concat_function,
					},
				},
				"join": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      join_function,
					},
				},
				"splice": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      splice_function,
					},
				},
				"shift": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      shift_function,
					},
				},
				"pop": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      pop_function,
					},
				},
				"push": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      push_function,
					},
				},
				"slice": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      slice_function,
					},
				},
				"unshift": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      unshift_function,
					},
				},
				"reverse": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      reverse_function,
					},
				},
				"sort": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      sort_function,
					},
				},
				"indexOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      indexOf_function,
					},
				},
				"lastIndexOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      lastIndexOf_function,
					},
				},
				"every": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      every_function,
					},
				},
				"some": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      some_function,
					},
				},
				"forEach": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      forEach_function,
					},
				},
				"map": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      map_function,
					},
				},
				"filter": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      filter_function,
					},
				},
				"reduce": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      reduce_function,
					},
				},
				"reduceRight": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      reduceRight_function,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"toString",
				"toLocaleString",
				"concat",
				"join",
				"splice",
				"shift",
				"pop",
				"push",
				"slice",
				"unshift",
				"reverse",
				"sort",
				"indexOf",
				"lastIndexOf",
				"every",
				"some",
				"forEach",
				"map",
				"filter",
				"reduce",
				"reduceRight",
			},
		}
		runtime.Global.Array = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinArray),
				construct: builtinNewArray,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.ArrayPrototype,
					},
				},
				"isArray": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      isArray_function,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
				"isArray",
			},
		}
		runtime.Global.ArrayPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Array,
				},
			}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_toString),
			},
		}
		valueOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_valueOf),
			},
		}
		charAt_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_charAt),
			},
		}
		charCodeAt_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_charCodeAt),
			},
		}
		concat_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_concat),
			},
		}
		indexOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_indexOf),
			},
		}
		lastIndexOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_lastIndexOf),
			},
		}
		match_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_match),
			},
		}
		replace_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_replace),
			},
		}
		search_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_search),
			},
		}
		split_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_split),
			},
		}
		slice_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_slice),
			},
		}
		substring_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_substring),
			},
		}
		toLowerCase_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_toLowerCase),
			},
		}
		toUpperCase_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_toUpperCase),
			},
		}
		substr_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_substr),
			},
		}
		trim_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_trim),
			},
		}
		trimLeft_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_trimLeft),
			},
		}
		trimRight_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_trimRight),
			},
		}
		localeCompare_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_localeCompare),
			},
		}
		toLocaleLowerCase_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_toLocaleLowerCase),
			},
		}
		toLocaleUpperCase_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_toLocaleUpperCase),
			},
		}
		fromCharCode_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinString_fromCharCode),
			},
		}
		runtime.Global.StringPrototype = &_object{
			runtime:     runtime,
			class:       "String",
			objectClass: _classString,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       prototypeValueString,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      int(0),
					},
				},
				"toString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toString_function,
					},
				},
				"valueOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      valueOf_function,
					},
				},
				"charAt": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      charAt_function,
					},
				},
				"charCodeAt": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      charCodeAt_function,
					},
				},
				"concat": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      concat_function,
					},
				},
				"indexOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      indexOf_function,
					},
				},
				"lastIndexOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      lastIndexOf_function,
					},
				},
				"match": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      match_function,
					},
				},
				"replace": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      replace_function,
					},
				},
				"search": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      search_function,
					},
				},
				"split": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      split_function,
					},
				},
				"slice": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      slice_function,
					},
				},
				"substring": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      substring_function,
					},
				},
				"toLowerCase": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLowerCase_function,
					},
				},
				"toUpperCase": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toUpperCase_function,
					},
				},
				"substr": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      substr_function,
					},
				},
				"trim": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      trim_function,
					},
				},
				"trimLeft": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      trimLeft_function,
					},
				},
				"trimRight": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      trimRight_function,
					},
				},
				"localeCompare": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      localeCompare_function,
					},
				},
				"toLocaleLowerCase": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLocaleLowerCase_function,
					},
				},
				"toLocaleUpperCase": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLocaleUpperCase_function,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"toString",
				"valueOf",
				"charAt",
				"charCodeAt",
				"concat",
				"indexOf",
				"lastIndexOf",
				"match",
				"replace",
				"search",
				"split",
				"slice",
				"substring",
				"toLowerCase",
				"toUpperCase",
				"substr",
				"trim",
				"trimLeft",
				"trimRight",
				"localeCompare",
				"toLocaleLowerCase",
				"toLocaleUpperCase",
			},
		}
		runtime.Global.String = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinString),
				construct: builtinNewString,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.StringPrototype,
					},
				},
				"fromCharCode": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      fromCharCode_function,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
				"fromCharCode",
			},
		}
		runtime.Global.StringPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.String,
				},
			}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinBoolean_toString),
			},
		}
		valueOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinBoolean_valueOf),
			},
		}
		runtime.Global.BooleanPrototype = &_object{
			runtime:     runtime,
			class:       "Boolean",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       prototypeValueBoolean,
			property: map[string]_property{
				"toString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toString_function,
					},
				},
				"valueOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      valueOf_function,
					},
				},
			},
			propertyOrder: []string{
				"toString",
				"valueOf",
			},
		}
		runtime.Global.Boolean = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinBoolean),
				construct: builtinNewBoolean,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.BooleanPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.BooleanPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Boolean,
				},
			}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinNumber_toString),
			},
		}
		valueOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinNumber_valueOf),
			},
		}
		toFixed_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinNumber_toFixed),
			},
		}
		toExponential_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinNumber_toExponential),
			},
		}
		toPrecision_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinNumber_toPrecision),
			},
		}
		toLocaleString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinNumber_toLocaleString),
			},
		}
		runtime.Global.NumberPrototype = &_object{
			runtime:     runtime,
			class:       "Number",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       prototypeValueNumber,
			property: map[string]_property{
				"toString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toString_function,
					},
				},
				"valueOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      valueOf_function,
					},
				},
				"toFixed": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toFixed_function,
					},
				},
				"toExponential": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toExponential_function,
					},
				},
				"toPrecision": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toPrecision_function,
					},
				},
				"toLocaleString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLocaleString_function,
					},
				},
			},
			propertyOrder: []string{
				"toString",
				"valueOf",
				"toFixed",
				"toExponential",
				"toPrecision",
				"toLocaleString",
			},
		}
		runtime.Global.Number = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinNumber),
				construct: builtinNewNumber,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.NumberPrototype,
					},
				},
				"MAX_VALUE": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.MaxFloat64,
					},
				},
				"MIN_VALUE": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.SmallestNonzeroFloat64,
					},
				},
				"NaN": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.NaN(),
					},
				},
				"NEGATIVE_INFINITY": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Inf(-1),
					},
				},
				"POSITIVE_INFINITY": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Inf(+1),
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
				"MAX_VALUE",
				"MIN_VALUE",
				"NaN",
				"NEGATIVE_INFINITY",
				"POSITIVE_INFINITY",
			},
		}
		runtime.Global.NumberPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Number,
				},
			}
	}
	{
		abs_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_abs),
			},
		}
		acos_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_acos),
			},
		}
		asin_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_asin),
			},
		}
		atan_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_atan),
			},
		}
		atan2_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_atan2),
			},
		}
		ceil_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_ceil),
			},
		}
		cos_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_cos),
			},
		}
		exp_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_exp),
			},
		}
		floor_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_floor),
			},
		}
		log_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_log),
			},
		}
		max_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_max),
			},
		}
		min_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_min),
			},
		}
		pow_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_pow),
			},
		}
		random_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_random),
			},
		}
		round_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_round),
			},
		}
		sin_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_sin),
			},
		}
		sqrt_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_sqrt),
			},
		}
		tan_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinMath_tan),
			},
		}
		runtime.Global.Math = &_object{
			runtime:     runtime,
			class:       "Math",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			property: map[string]_property{
				"abs": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      abs_function,
					},
				},
				"acos": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      acos_function,
					},
				},
				"asin": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      asin_function,
					},
				},
				"atan": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      atan_function,
					},
				},
				"atan2": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      atan2_function,
					},
				},
				"ceil": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      ceil_function,
					},
				},
				"cos": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      cos_function,
					},
				},
				"exp": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      exp_function,
					},
				},
				"floor": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      floor_function,
					},
				},
				"log": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      log_function,
					},
				},
				"max": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      max_function,
					},
				},
				"min": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      min_function,
					},
				},
				"pow": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      pow_function,
					},
				},
				"random": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      random_function,
					},
				},
				"round": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      round_function,
					},
				},
				"sin": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      sin_function,
					},
				},
				"sqrt": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      sqrt_function,
					},
				},
				"tan": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      tan_function,
					},
				},
				"E": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.E,
					},
				},
				"LN10": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Ln10,
					},
				},
				"LN2": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Ln2,
					},
				},
				"LOG2E": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Log2E,
					},
				},
				"LOG10E": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Log10E,
					},
				},
				"PI": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Pi,
					},
				},
				"SQRT1_2": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      sqrt1_2,
					},
				},
				"SQRT2": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      math.Sqrt2,
					},
				},
			},
			propertyOrder: []string{
				"abs",
				"acos",
				"asin",
				"atan",
				"atan2",
				"ceil",
				"cos",
				"exp",
				"floor",
				"log",
				"max",
				"min",
				"pow",
				"random",
				"round",
				"sin",
				"sqrt",
				"tan",
				"E",
				"LN10",
				"LN2",
				"LOG2E",
				"LOG10E",
				"PI",
				"SQRT1_2",
				"SQRT2",
			},
		}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toString),
			},
		}
		toDateString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toDateString),
			},
		}
		toTimeString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toTimeString),
			},
		}
		toUTCString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toUTCString),
			},
		}
		toISOString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toISOString),
			},
		}
		toJSON_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toJSON),
			},
		}
		toGMTString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toGMTString),
			},
		}
		toLocaleString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toLocaleString),
			},
		}
		toLocaleDateString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toLocaleDateString),
			},
		}
		toLocaleTimeString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_toLocaleTimeString),
			},
		}
		valueOf_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_valueOf),
			},
		}
		getTime_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getTime),
			},
		}
		getYear_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getYear),
			},
		}
		getFullYear_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getFullYear),
			},
		}
		getUTCFullYear_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCFullYear),
			},
		}
		getMonth_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getMonth),
			},
		}
		getUTCMonth_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCMonth),
			},
		}
		getDate_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getDate),
			},
		}
		getUTCDate_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCDate),
			},
		}
		getDay_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getDay),
			},
		}
		getUTCDay_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCDay),
			},
		}
		getHours_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getHours),
			},
		}
		getUTCHours_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCHours),
			},
		}
		getMinutes_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getMinutes),
			},
		}
		getUTCMinutes_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCMinutes),
			},
		}
		getSeconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getSeconds),
			},
		}
		getUTCSeconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCSeconds),
			},
		}
		getMilliseconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getMilliseconds),
			},
		}
		getUTCMilliseconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getUTCMilliseconds),
			},
		}
		getTimezoneOffset_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_getTimezoneOffset),
			},
		}
		setTime_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setTime),
			},
		}
		setMilliseconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setMilliseconds),
			},
		}
		setUTCMilliseconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setUTCMilliseconds),
			},
		}
		setSeconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setSeconds),
			},
		}
		setUTCSeconds_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setUTCSeconds),
			},
		}
		setMinutes_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      3,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setMinutes),
			},
		}
		setUTCMinutes_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      3,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setUTCMinutes),
			},
		}
		setHours_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      4,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setHours),
			},
		}
		setUTCHours_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      4,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setUTCHours),
			},
		}
		setDate_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setDate),
			},
		}
		setUTCDate_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setUTCDate),
			},
		}
		setMonth_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setMonth),
			},
		}
		setUTCMonth_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setUTCMonth),
			},
		}
		setYear_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setYear),
			},
		}
		setFullYear_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      3,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setFullYear),
			},
		}
		setUTCFullYear_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      3,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_setUTCFullYear),
			},
		}
		parse_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_parse),
			},
		}
		UTC_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      7,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_UTC),
			},
		}
		now_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinDate_now),
			},
		}
		runtime.Global.DatePrototype = &_object{
			runtime:     runtime,
			class:       "Date",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       prototypeValueDate,
			property: map[string]_property{
				"toString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toString_function,
					},
				},
				"toDateString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toDateString_function,
					},
				},
				"toTimeString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toTimeString_function,
					},
				},
				"toUTCString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toUTCString_function,
					},
				},
				"toISOString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toISOString_function,
					},
				},
				"toJSON": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toJSON_function,
					},
				},
				"toGMTString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toGMTString_function,
					},
				},
				"toLocaleString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLocaleString_function,
					},
				},
				"toLocaleDateString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLocaleDateString_function,
					},
				},
				"toLocaleTimeString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toLocaleTimeString_function,
					},
				},
				"valueOf": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      valueOf_function,
					},
				},
				"getTime": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getTime_function,
					},
				},
				"getYear": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getYear_function,
					},
				},
				"getFullYear": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getFullYear_function,
					},
				},
				"getUTCFullYear": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCFullYear_function,
					},
				},
				"getMonth": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getMonth_function,
					},
				},
				"getUTCMonth": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCMonth_function,
					},
				},
				"getDate": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getDate_function,
					},
				},
				"getUTCDate": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCDate_function,
					},
				},
				"getDay": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getDay_function,
					},
				},
				"getUTCDay": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCDay_function,
					},
				},
				"getHours": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getHours_function,
					},
				},
				"getUTCHours": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCHours_function,
					},
				},
				"getMinutes": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getMinutes_function,
					},
				},
				"getUTCMinutes": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCMinutes_function,
					},
				},
				"getSeconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getSeconds_function,
					},
				},
				"getUTCSeconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCSeconds_function,
					},
				},
				"getMilliseconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getMilliseconds_function,
					},
				},
				"getUTCMilliseconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getUTCMilliseconds_function,
					},
				},
				"getTimezoneOffset": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      getTimezoneOffset_function,
					},
				},
				"setTime": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setTime_function,
					},
				},
				"setMilliseconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setMilliseconds_function,
					},
				},
				"setUTCMilliseconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setUTCMilliseconds_function,
					},
				},
				"setSeconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setSeconds_function,
					},
				},
				"setUTCSeconds": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setUTCSeconds_function,
					},
				},
				"setMinutes": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setMinutes_function,
					},
				},
				"setUTCMinutes": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setUTCMinutes_function,
					},
				},
				"setHours": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setHours_function,
					},
				},
				"setUTCHours": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setUTCHours_function,
					},
				},
				"setDate": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setDate_function,
					},
				},
				"setUTCDate": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setUTCDate_function,
					},
				},
				"setMonth": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setMonth_function,
					},
				},
				"setUTCMonth": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setUTCMonth_function,
					},
				},
				"setYear": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setYear_function,
					},
				},
				"setFullYear": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setFullYear_function,
					},
				},
				"setUTCFullYear": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      setUTCFullYear_function,
					},
				},
			},
			propertyOrder: []string{
				"toString",
				"toDateString",
				"toTimeString",
				"toUTCString",
				"toISOString",
				"toJSON",
				"toGMTString",
				"toLocaleString",
				"toLocaleDateString",
				"toLocaleTimeString",
				"valueOf",
				"getTime",
				"getYear",
				"getFullYear",
				"getUTCFullYear",
				"getMonth",
				"getUTCMonth",
				"getDate",
				"getUTCDate",
				"getDay",
				"getUTCDay",
				"getHours",
				"getUTCHours",
				"getMinutes",
				"getUTCMinutes",
				"getSeconds",
				"getUTCSeconds",
				"getMilliseconds",
				"getUTCMilliseconds",
				"getTimezoneOffset",
				"setTime",
				"setMilliseconds",
				"setUTCMilliseconds",
				"setSeconds",
				"setUTCSeconds",
				"setMinutes",
				"setUTCMinutes",
				"setHours",
				"setUTCHours",
				"setDate",
				"setUTCDate",
				"setMonth",
				"setUTCMonth",
				"setYear",
				"setFullYear",
				"setUTCFullYear",
			},
		}
		runtime.Global.Date = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinDate),
				construct: builtinNewDate,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      7,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.DatePrototype,
					},
				},
				"parse": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      parse_function,
					},
				},
				"UTC": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      UTC_function,
					},
				},
				"now": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      now_function,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
				"parse",
				"UTC",
				"now",
			},
		}
		runtime.Global.DatePrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Date,
				},
			}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinRegExp_toString),
			},
		}
		exec_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinRegExp_exec),
			},
		}
		test_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinRegExp_test),
			},
		}
		compile_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinRegExp_compile),
			},
		}
		runtime.Global.RegExpPrototype = &_object{
			runtime:     runtime,
			class:       "RegExp",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       prototypeValueRegExp,
			property: map[string]_property{
				"toString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toString_function,
					},
				},
				"exec": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      exec_function,
					},
				},
				"test": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      test_function,
					},
				},
				"compile": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      compile_function,
					},
				},
			},
			propertyOrder: []string{
				"toString",
				"exec",
				"test",
				"compile",
			},
		}
		runtime.Global.RegExp = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinRegExp),
				construct: builtinNewRegExp,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.RegExpPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.RegExpPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.RegExp,
				},
			}
	}
	{
		toString_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinError_toString),
			},
		}
		runtime.Global.ErrorPrototype = &_object{
			runtime:     runtime,
			class:       "Error",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"toString": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      toString_function,
					},
				},
				"name": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "Error",
					},
				},
				"message": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "",
					},
				},
			},
			propertyOrder: []string{
				"toString",
				"name",
				"message",
			},
		}
		runtime.Global.Error = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinError),
				construct: builtinNewError,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.ErrorPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.ErrorPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Error,
				},
			}
	}
	{
		runtime.Global.EvalErrorPrototype = &_object{
			runtime:     runtime,
			class:       "EvalError",
			objectClass: _classObject,
			prototype:   runtime.Global.ErrorPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"name": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "EvalError",
					},
				},
			},
			propertyOrder: []string{
				"name",
			},
		}
		runtime.Global.EvalError = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinEvalError),
				construct: builtinNewEvalError,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.EvalErrorPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.EvalErrorPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.EvalError,
				},
			}
	}
	{
		runtime.Global.TypeErrorPrototype = &_object{
			runtime:     runtime,
			class:       "TypeError",
			objectClass: _classObject,
			prototype:   runtime.Global.ErrorPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"name": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "TypeError",
					},
				},
			},
			propertyOrder: []string{
				"name",
			},
		}
		runtime.Global.TypeError = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinTypeError),
				construct: builtinNewTypeError,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.TypeErrorPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.TypeErrorPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.TypeError,
				},
			}
	}
	{
		runtime.Global.RangeErrorPrototype = &_object{
			runtime:     runtime,
			class:       "RangeError",
			objectClass: _classObject,
			prototype:   runtime.Global.ErrorPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"name": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "RangeError",
					},
				},
			},
			propertyOrder: []string{
				"name",
			},
		}
		runtime.Global.RangeError = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinRangeError),
				construct: builtinNewRangeError,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.RangeErrorPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.RangeErrorPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.RangeError,
				},
			}
	}
	{
		runtime.Global.ReferenceErrorPrototype = &_object{
			runtime:     runtime,
			class:       "ReferenceError",
			objectClass: _classObject,
			prototype:   runtime.Global.ErrorPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"name": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "ReferenceError",
					},
				},
			},
			propertyOrder: []string{
				"name",
			},
		}
		runtime.Global.ReferenceError = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinReferenceError),
				construct: builtinNewReferenceError,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.ReferenceErrorPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.ReferenceErrorPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.ReferenceError,
				},
			}
	}
	{
		runtime.Global.SyntaxErrorPrototype = &_object{
			runtime:     runtime,
			class:       "SyntaxError",
			objectClass: _classObject,
			prototype:   runtime.Global.ErrorPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"name": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "SyntaxError",
					},
				},
			},
			propertyOrder: []string{
				"name",
			},
		}
		runtime.Global.SyntaxError = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinSyntaxError),
				construct: builtinNewSyntaxError,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.SyntaxErrorPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.SyntaxErrorPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.SyntaxError,
				},
			}
	}
	{
		runtime.Global.URIErrorPrototype = &_object{
			runtime:     runtime,
			class:       "URIError",
			objectClass: _classObject,
			prototype:   runtime.Global.ErrorPrototype,
			extensible:  true,
			value:       nil,
			property: map[string]_property{
				"name": _property{
					mode: 0101,
					value: Value{
						_valueType: valueString,
						value:      "URIError",
					},
				},
			},
			propertyOrder: []string{
				"name",
			},
		}
		runtime.Global.URIError = &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			value: _functionObject{
				call:      _nativeCallFunction(builtinURIError),
				construct: builtinNewURIError,
			},
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
				"prototype": _property{
					mode: 0,
					value: Value{
						_valueType: valueObject,
						value:      runtime.Global.URIErrorPrototype,
					},
				},
			},
			propertyOrder: []string{
				"length",
				"prototype",
			},
		}
		runtime.Global.URIErrorPrototype.property["constructor"] =
			_property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.URIError,
				},
			}
	}
	{
		parse_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinJSON_parse),
			},
		}
		stringify_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      3,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinJSON_stringify),
			},
		}
		runtime.Global.JSON = &_object{
			runtime:     runtime,
			class:       "JSON",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			property: map[string]_property{
				"parse": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      parse_function,
					},
				},
				"stringify": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      stringify_function,
					},
				},
			},
			propertyOrder: []string{
				"parse",
				"stringify",
			},
		}
	}
	{
		eval_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_eval),
			},
		}
		parseInt_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      2,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_parseInt),
			},
		}
		parseFloat_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_parseFloat),
			},
		}
		isNaN_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_isNaN),
			},
		}
		isFinite_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_isFinite),
			},
		}
		decodeURI_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_decodeURI),
			},
		}
		decodeURIComponent_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_decodeURIComponent),
			},
		}
		encodeURI_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_encodeURI),
			},
		}
		encodeURIComponent_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_encodeURIComponent),
			},
		}
		escape_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_escape),
			},
		}
		unescape_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      1,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinGlobal_unescape),
			},
		}
		runtime.GlobalObject.property = map[string]_property{
			"eval": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      eval_function,
				},
			},
			"parseInt": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      parseInt_function,
				},
			},
			"parseFloat": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      parseFloat_function,
				},
			},
			"isNaN": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      isNaN_function,
				},
			},
			"isFinite": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      isFinite_function,
				},
			},
			"decodeURI": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      decodeURI_function,
				},
			},
			"decodeURIComponent": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      decodeURIComponent_function,
				},
			},
			"encodeURI": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      encodeURI_function,
				},
			},
			"encodeURIComponent": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      encodeURIComponent_function,
				},
			},
			"escape": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      escape_function,
				},
			},
			"unescape": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      unescape_function,
				},
			},
			"Object": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Object,
				},
			},
			"Function": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Function,
				},
			},
			"Array": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Array,
				},
			},
			"String": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.String,
				},
			},
			"Boolean": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Boolean,
				},
			},
			"Number": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Number,
				},
			},
			"Math": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Math,
				},
			},
			"Date": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Date,
				},
			},
			"RegExp": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.RegExp,
				},
			},
			"Error": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.Error,
				},
			},
			"EvalError": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.EvalError,
				},
			},
			"TypeError": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.TypeError,
				},
			},
			"RangeError": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.RangeError,
				},
			},
			"ReferenceError": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.ReferenceError,
				},
			},
			"SyntaxError": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.SyntaxError,
				},
			},
			"URIError": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.URIError,
				},
			},
			"JSON": _property{
				mode: 0101,
				value: Value{
					_valueType: valueObject,
					value:      runtime.Global.JSON,
				},
			},
			"undefined": _property{
				mode: 0,
				value: Value{
					_valueType: valueUndefined,
				},
			},
			"NaN": _property{
				mode: 0,
				value: Value{
					_valueType: valueNumber,
					value:      math.NaN(),
				},
			},
			"Infinity": _property{
				mode: 0,
				value: Value{
					_valueType: valueNumber,
					value:      math.Inf(+1),
				},
			},
		}
		runtime.GlobalObject.propertyOrder = []string{
			"eval",
			"parseInt",
			"parseFloat",
			"isNaN",
			"isFinite",
			"decodeURI",
			"decodeURIComponent",
			"encodeURI",
			"encodeURIComponent",
			"escape",
			"unescape",
			"Object",
			"Function",
			"Array",
			"String",
			"Boolean",
			"Number",
			"Math",
			"Date",
			"RegExp",
			"Error",
			"EvalError",
			"TypeError",
			"RangeError",
			"ReferenceError",
			"SyntaxError",
			"URIError",
			"JSON",
			"undefined",
			"NaN",
			"Infinity",
		}
	}
}

func newConsoleObject(runtime *_runtime) *_object {
	{
		log_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_log),
			},
		}
		debug_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_log),
			},
		}
		info_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_log),
			},
		}
		error_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_error),
			},
		}
		warn_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_error),
			},
		}
		dir_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_dir),
			},
		}
		time_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_time),
			},
		}
		timeEnd_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_timeEnd),
			},
		}
		trace_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_trace),
			},
		}
		assert_function := &_object{
			runtime:     runtime,
			class:       "Function",
			objectClass: _classObject,
			prototype:   runtime.Global.FunctionPrototype,
			extensible:  true,
			property: map[string]_property{
				"length": _property{
					mode: 0,
					value: Value{
						_valueType: valueNumber,
						value:      0,
					},
				},
			},
			propertyOrder: []string{
				"length",
			},
			value: _functionObject{
				call: _nativeCallFunction(builtinConsole_assert),
			},
		}
		return &_object{
			runtime:     runtime,
			class:       "Object",
			objectClass: _classObject,
			prototype:   runtime.Global.ObjectPrototype,
			extensible:  true,
			property: map[string]_property{
				"log": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      log_function,
					},
				},
				"debug": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      debug_function,
					},
				},
				"info": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      info_function,
					},
				},
				"error": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      error_function,
					},
				},
				"warn": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      warn_function,
					},
				},
				"dir": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      dir_function,
					},
				},
				"time": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      time_function,
					},
				},
				"timeEnd": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      timeEnd_function,
					},
				},
				"trace": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      trace_function,
					},
				},
				"assert": _property{
					mode: 0101,
					value: Value{
						_valueType: valueObject,
						value:      assert_function,
					},
				},
			},
			propertyOrder: []string{
				"log",
				"debug",
				"info",
				"error",
				"warn",
				"dir",
				"time",
				"timeEnd",
				"trace",
				"assert",
			},
		}
	}
}

func toValue_int(value int) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_int8(value int8) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_int16(value int16) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_int32(value int32) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_int64(value int64) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_uint(value uint) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_uint8(value uint8) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_uint16(value uint16) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_uint32(value uint32) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_uint64(value uint64) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_float32(value float32) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_float64(value float64) Value {
	return Value{
		_valueType: valueNumber,
		value:      value,
	}
}

func toValue_string(value string) Value {
	return Value{
		_valueType: valueString,
		value:      value,
	}
}

func toValue_string16(value []uint16) Value {
	return Value{
		_valueType: valueString,
		value:      value,
	}
}

func toValue_bool(value bool) Value {
	return Value{
		_valueType: valueBoolean,
		value:      value,
	}
}

func toValue_object(value *_object) Value {
	return Value{
		_valueType: valueObject,
		value:      value,
	}
}
