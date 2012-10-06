package otto

type _stash interface {
	CanRead(string) bool
	Read(string) Value
	CanWrite(string) bool
	Write(string, Value)
	property(string) *_property
	Delete(string)
	Define(string, _defineProperty) bool
	Enumerate(func(string))
	writeValuePropertyMap(map[string]_valueProperty)
}

type _propertyStash struct {
	canCreate bool
	propertyMap map[string]*_property
}

func newPropertyStash(canCreate bool) *_propertyStash {
	return &_propertyStash{
		canCreate: canCreate,
		propertyMap: make(map[string]*_property),
	}
}

func (self *_propertyStash) CanRead(name string) bool {
	_, exists := self.propertyMap[name]
	return exists
}

func (self *_propertyStash) Read(name string) Value {
	property := self.propertyMap[name]

	if property == nil {
		return UndefinedValue()
	}

	switch value := property.Value.(type) {
	case Value:
		return value
	case _propertyGetSet:
		if value[0] == nil {
			return UndefinedValue()
		}
		return value[0].CallGet(name)
	}

	panic(hereBeDragons())
}

func (self *_propertyStash) CanWrite(name string) bool {
	property, _ := self.propertyMap[name]
	if property == nil {
		return self.canCreate
	}
	switch propertyValue := property.Value.(type) {
	case Value:
		return property.CanWrite()
	case _propertyGetSet:
		return propertyValue[1] != nil
	}
	panic(hereBeDragons())
}

func (self *_propertyStash) Write(name string, value Value) {
	property_, _ := self.propertyMap[name]
	if property_ != nil {
		switch propertyValue := property_.Value.(type) {
		case Value:
			if property_.CanWrite() {
				property_.Value = value
			}
		case _propertyGetSet:
			if propertyValue[1] != nil {
				propertyValue[1].CallSet(name, value)
			}
		}
	} else if self.canCreate {
		self.propertyMap[name] = &_property{ value, propertyModeWriteEnumerateConfigure }
	}
}

func (self *_propertyStash) property(name string) *_property {
	property, _ := self.propertyMap[name]
	return property
}

func (self *_propertyStash) Delete(name string) {
	delete(self.propertyMap, name)
}

func (self *_propertyStash) Define(name string, define _defineProperty) bool {
	canCreate := self.canCreate
	property_, _ := self.propertyMap[name]
	if property_ == nil {
		if !canCreate {
			return false
		}
		property_ = &_property{
			Value: define.Value,
			Mode: define.Mode(),
		}
		self.propertyMap[name] = property_
		return true
	}
	if define.isEmpty() {
		return true
	}

	// TODO Per 8.12.9.6 - We should shortcut here (returning true) if
	// the current and new (define) properties are the same

	canConfigure := property_.CanConfigure()
	if !canConfigure {
		if define.CanConfigure() {
			return false
		}
		if define.Enumerate != propertyAttributeNotSet && define.CanEnumerate() != property_.CanEnumerate() {
			return false
		}
	}
	value, isDataDescriptor := property_.Value.(Value)
	getSet, _ := property_.Value.(_propertyGetSet)
	if define.IsGenericDescriptor() {
		; // GenericDescriptor
	} else if isDataDescriptor != define.IsDataDescriptor() {
		var interface_ interface{}
		if isDataDescriptor {
			property_.Mode = property_.Mode & ^propertyModeWrite
			property_.Value = interface_
		} else {
			property_.Mode |= propertyModeWrite
			property_.Value = interface_
		}
	} else if isDataDescriptor && define.IsDataDescriptor() {
		if !canConfigure {
			if property_.CanWrite() != define.CanWrite() {
				return false
			} else if !sameValue(value, define.Value.(Value)) {
				return false
			}
		}
	} else {
		if !canConfigure {
			defineGetSet, _ := define.Value.(_propertyGetSet)
			if getSet[0] != defineGetSet[0] || getSet[1] != defineGetSet[1] {
				return false
			}
		}
	}
	define.CopyInto(property_)
	return true
}

func (self *_propertyStash) Enumerate(each func(string)) {
	for name, property_ := range self.propertyMap {
		if property_.CanEnumerate() {
			each(name)
		}
	}
}

func (self *_propertyStash) writeValuePropertyMap(valuePropertyMap map[string]_valueProperty) {
	for name, _valueProperty := range valuePropertyMap {
		self.propertyMap[name] = &_property{ Value: _valueProperty.Value, Mode: _valueProperty.Mode }
	}
}
