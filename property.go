package otto

// property

type _propertyMode int

const (
	modeWriteMask     _propertyMode = 0700
	modeEnumerateMask               = 0070
	modeConfigureMask               = 0007
	modeOnMask                      = 0111
	modeOffMask                     = 0000
	modeSetMask                     = 0222 // If value is 2, then mode is neither "On" nor "Off"
)

type _propertyGetSet [2]*_object

type _property struct {
	value interface{}
	mode  _propertyMode
}

func (self _property) writable() bool {
	return self.mode&modeWriteMask == modeWriteMask&modeOnMask
}

func (self *_property) writeOn() {
	self.mode = (self.mode & ^modeWriteMask) | (modeWriteMask & modeOnMask)
}

func (self *_property) writeOff() {
	self.mode &= ^modeWriteMask
}

func (self _property) writeSet() bool {
	return 0 == self.mode&modeWriteMask&modeSetMask
}

func (self _property) enumerable() bool {
	return self.mode&modeEnumerateMask == modeEnumerateMask&modeOnMask
}

func (self *_property) enumerateOn() {
	self.mode = (self.mode & ^modeEnumerateMask) | (modeEnumerateMask & modeOnMask)
}

func (self *_property) enumerateOff() {
	self.mode &= ^modeEnumerateMask
}

func (self _property) enumerateSet() bool {
	return 0 == self.mode&modeEnumerateMask&modeSetMask
}

func (self _property) configurable() bool {
	return self.mode&modeConfigureMask == modeConfigureMask&modeOnMask
}

func (self *_property) configureOn() {
	self.mode = (self.mode & ^modeConfigureMask) | (modeConfigureMask & modeOnMask)
}

func (self *_property) configureOff() {
	self.mode &= ^modeConfigureMask
}

func (self _property) configureSet() bool {
	return 0 == self.mode&modeConfigureMask&modeSetMask
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
	if self.writeSet() { // Either "On" or "Off"
		return true
	}
	value, valid := self.value.(Value)
	return valid && !value.isEmpty()
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
		descriptor.mode = modeSetMask // Initially nothing is set
		if objectDescriptor.hasProperty("enumerable") {
			if objectDescriptor.get("enumerable").toBoolean() {
				descriptor.enumerateOn()
			} else {
				descriptor.enumerateOff()
			}
		}

		if objectDescriptor.hasProperty("configurable") {
			if objectDescriptor.get("configurable").toBoolean() {
				descriptor.configureOn()
			} else {
				descriptor.configureOff()
			}
		}

		if objectDescriptor.hasProperty("writable") {
			descriptor.value = UndefinedValue() // FIXME Is this the right place for this?
			if objectDescriptor.get("writable").toBoolean() {
				descriptor.writeOn()
			} else {
				descriptor.writeOff()
			}
		}
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

	if getterSetter {
		if descriptor.writeSet() {
			panic(newTypeError())
		}
		descriptor.value = _propertyGetSet{getter, setter}
	}

	if objectDescriptor.hasProperty("value") {
		if getterSetter {
			panic(newTypeError())
		}
		descriptor.value = objectDescriptor.get("value")
	}

	return
}

func (self *_runtime) fromPropertyDescriptor(descriptor _property) *_object {
	object := self.newObject()
	if descriptor.isDataDescriptor() {
		object.defineProperty("value", descriptor.value.(Value), 0111, false)
		object.defineProperty("writable", toValue(descriptor.writable()), 0111, false)
	} else if descriptor.isAccessorDescriptor() {
		getSet := descriptor.value.(_propertyGetSet)
		object.defineProperty("get", toValue(getSet[0]), 0111, false)
		object.defineProperty("set", toValue(getSet[1]), 0111, false)
	}
	object.defineProperty("enumerable", toValue(descriptor.enumerable()), 0111, false)
	object.defineProperty("configurable", toValue(descriptor.configurable()), 0111, false)
	return object
}
