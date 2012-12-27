package otto

// property

type _propertyMode int

const (
	propertyMode_write     _propertyMode = 0100
	propertyMode_enumerate               = 0010
	propertyMode_configure               = 0001
)

type _propertyGetSet [2]*_object

type _property struct {
	value interface{}
	mode  _propertyMode
}

func (self _property) writable() bool {
	return self.mode & 0700 == 0100
}

func (self _property) enumerable() bool {
	return self.mode & 0070 == 0010
}

func (self _property) configurable() bool {
	return self.mode & 0007 == 0001
}

func (self _property) copy() *_property {
	property := self
	return &property
}

func (self _property) isAccessorDescriptor() bool {
	setGet, test := self.value.(_propertyGetSet)
	return test && setGet[0] != nil || setGet[1] != nil
}

func (self _property) isDataDescriptor() bool {
	value, test := self.value.(Value)
	return self.mode & 0700 != 0200 || (test && !value.isEmpty())
}

func (self _property) isGenericDescriptor() bool {
	return !(self.isDataDescriptor() || self.isAccessorDescriptor())
}

func (self _property) isEmpty() bool {
	return self.mode == 0222 && self.isGenericDescriptor()
}

// _enumerableValue, _enumerableTrue, _enumerableFalse?
// .enumerableValue() .enumerableExists()

func toPropertyDescriptor(value Value) (descriptor _property) {
	objectDescriptor := value._object()
	if objectDescriptor == nil {
		panic(newTypeError())
	}

	{
		mode := _propertyMode(0)
		if objectDescriptor.hasProperty("enumerable") {
			if objectDescriptor.get("enumerable").toBoolean() {
				mode |= 0010
			}
		} else {
			mode |= 0020
		}

		if objectDescriptor.hasProperty("configurable") {
			if objectDescriptor.get("configurable").toBoolean() {
				mode |= 0001
			}
		} else {
			mode |= 0002
		}

		if objectDescriptor.hasProperty("writable") {
			descriptor.value = UndefinedValue() // FIXME Is this the right place for this?
			if objectDescriptor.get("writable").toBoolean() {
				mode |= 0100
			}
		} else {
			mode |= 0200
		}
		descriptor.mode = mode
	}


	var getter, setter *_object
	getterSetter := false

	if objectDescriptor.hasProperty("get") {
		value := objectDescriptor.get("get")
		if value.IsDefined() {
			if !value.isCallable() {
				panic(newTypeError())
			}
			getter = value._object()
			getterSetter = getterSetter || getter != nil
		}
	}

	if objectDescriptor.hasProperty("set") {
		value := objectDescriptor.get("set")
		if value.IsDefined() {
			if !value.isCallable() {
				panic(newTypeError())
			}
			setter = value._object()
			getterSetter = getterSetter || setter != nil
		}
	}

	if (getterSetter) {
		// If writable is set on the descriptor, ...
		if descriptor.mode & 0200 != 0 {
			panic(newTypeError())
		}
		descriptor.value = _propertyGetSet{getter, setter}
	}

	if objectDescriptor.hasProperty("value") {
		if (getterSetter) {
			panic(newTypeError())
		}
		descriptor.value = objectDescriptor.get("value")
	}

	return
}

func (self *_runtime) fromPropertyDescriptor(descriptor _property) *_object {
	object := self.newObject()
	if descriptor.isDataDescriptor() {
		object.stash.set("value", descriptor.value.(Value), 0111)
		object.stash.set("writable", toValue(descriptor.writable()), 0111)
	} else if descriptor.isAccessorDescriptor() {
		getSet := descriptor.value.(_propertyGetSet)
		object.stash.set("get", toValue(getSet[0]), 0111)
		object.stash.set("set", toValue(getSet[1]), 0111)
	}
	object.stash.set("enumerable", toValue(descriptor.enumerable()), 0111)
	object.stash.set("configurable", toValue(descriptor.configurable()), 0111)
	return object
}
