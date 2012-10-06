package otto

// property

type _propertyMode int

const (
	propertyModeEmpty _propertyMode = 1
	propertyModeWrite = 2
	propertyModeEnumerate = 4
	propertyModeConfigure = 8
)

const (
	propertyModeWriteEnumerateConfigure _propertyMode = propertyModeWrite | propertyModeEnumerate | propertyModeConfigure
)

type _propertyGetSet [2]*_object

type _property struct {
	Value interface{}
	Mode _propertyMode
}

func (self _property) CanWrite() bool {
	return self.Mode & propertyModeWrite != 0
}

func (self _property) CanEnumerate() bool {
	return self.Mode & propertyModeEnumerate != 0
}

func (self _property) CanConfigure() bool {
	return self.Mode & propertyModeConfigure != 0
}

func (self _property) toDefineProperty() _defineProperty {
	property := _defineProperty{
		Value: self.Value,
	}
	mode := self.Mode
	if mode & propertyModeEmpty != 0 {
		return property
	}
	if mode & propertyModeWrite != 0 {
		property.Write = propertyAttributeTrue
	} else {
		property.Write = propertyAttributeFalse
	}
	if mode & propertyModeEnumerate != 0 {
		property.Enumerate = propertyAttributeTrue
	} else {
		property.Enumerate = propertyAttributeFalse
	}
	if mode & propertyModeConfigure != 0 {
		property.Configure = propertyAttributeTrue
	} else {
		property.Configure = propertyAttributeFalse
	}
	return property
}

func (self *_property) Copy() *_property {
	property := *self
	return &property
}

// _valueProperty

type _valueProperty struct {
	Value Value
	Mode _propertyMode
}

// _defineProperty

type _propertyAttributeBoolean int

const (
	propertyAttributeNotSet _propertyAttributeBoolean = iota
	propertyAttributeTrue
	propertyAttributeFalse
)

type _defineProperty struct {
	Value interface{}
	Write _propertyAttributeBoolean
	Enumerate _propertyAttributeBoolean
	Configure _propertyAttributeBoolean
}

func (self _defineProperty) Mode() (mode _propertyMode) {
	if self.Write != propertyAttributeFalse {
		mode |= propertyModeWrite
	}
	if self.Enumerate != propertyAttributeFalse {
		mode |= propertyModeEnumerate
	}
	if self.Configure != propertyAttributeFalse {
		mode |= propertyModeConfigure
	}
	return
}

func (self _defineProperty) CanWrite() bool {
	return self.Write == propertyAttributeTrue
}

func (self _defineProperty) CanEnumerate() bool {
	return self.Enumerate == propertyAttributeTrue
}

func (self _defineProperty) CanConfigure() bool {
	return self.Configure == propertyAttributeTrue
}

func (self _defineProperty) IsAccessorDescriptor() bool {
	setGet, test := self.Value.(_propertyGetSet)
	return test && setGet[0] != nil || setGet[1] != nil
}

func (self _defineProperty) IsDataDescriptor() bool {
	value, test := self.Value.(Value)
	return self.Write != propertyAttributeNotSet || (test && !value.isEmpty())
}

func (self _defineProperty) IsGenericDescriptor() bool {
	return !(self.IsDataDescriptor() || self.IsAccessorDescriptor())
}

func (self _defineProperty) isEmpty() bool {
	return self.IsGenericDescriptor() &&
			self.Write == propertyAttributeNotSet &&
			self.Enumerate == propertyAttributeNotSet &&
			self.Configure == propertyAttributeNotSet
}

func (self _defineProperty) CopyInto(other *_property) {
	switch self.Write {
	case propertyAttributeTrue:
		other.Mode |= propertyModeWrite
	case propertyAttributeFalse:
		other.Mode &= ^propertyModeWrite
	}

	switch self.Enumerate {
	case propertyAttributeTrue:
		other.Mode |= propertyModeEnumerate
	case propertyAttributeFalse:
		other.Mode &= ^propertyModeEnumerate
	}

	switch self.Configure {
	case propertyAttributeTrue:
		other.Mode |= propertyModeConfigure
	case propertyAttributeFalse:
		other.Mode &= ^propertyModeConfigure
	}

	if !self.IsGenericDescriptor() {
		other.Value = self.Value
	}
}

