package otto

import (
	"strconv"
)

func (runtime *_runtime) newArgumentsObject(indexOfParameterName []string, environment _environment, length int) *_object {
	self := runtime.newClassObject("Arguments")
	self.prototype = runtime.Global.ObjectPrototype

	self.stash = newArgumentsStash(indexOfParameterName, environment, self.stash)
	//for index, value := range argumentList {
	//    // TODO Write test for runtime.GetValue(value)
	//    // The problem here is possible reference nesting, is this the right place to GetValue?
	//    // FIXME This is sort of hack-y
	//    // 2012-02-23:
	//    // Not using this because we arguments should not be configurable (i.e. DontDelete)
	//    // self.set(arrayIndexToString(uint(index)), runtime.GetValue(value), false)
	//    self.stash.set(arrayIndexToString(uint(index)), runtime.GetValue(value), 0110)
	//}
	self.stash.set("length", toValue(length), 0101)

	return self
}

type _argumentsStash struct {
	indexOfParameterName []string
	environment          _environment
	_stash
}

func newArgumentsStash(indexOfParameterName []string, environment _environment, stash _stash) *_argumentsStash {
	self := &_argumentsStash{
		indexOfParameterName: indexOfParameterName,
		environment:          environment,
		_stash:               stash,
	}
	return self
}

func (self *_argumentsStash) getArgument(name string) Value {
	index := stringToArrayIndex(name)
	if index >= 0 && index < int64(len(self.indexOfParameterName)) {
		name := self.indexOfParameterName[index]
		if name == "" {
			return emptyValue()
		}
		return self.environment.GetBindingValue(name, false)
	}
	return emptyValue()
}

// read

func (self *_argumentsStash) test(name string) bool {
	value := self.getArgument(name)
	if !value.isEmpty() {
		return true
	}

	return self._stash.test(name)
}

func (self *_argumentsStash) get(name string) Value {
	value := self.getArgument(name)
	if !value.isEmpty() {
		return value
	}

	return self._stash.get(name)
}

func (self *_argumentsStash) property(name string) *_property {
	value := self.getArgument(name)
	if !value.isEmpty() {
		return &_property{
			value,
			0111, // +Write +Enumerate +Configure
		}
	}

	return self._stash.property(name)
}

func (self *_argumentsStash) enumerate(each func(string)) {

	for index, value := range self.indexOfParameterName {
		if value == "" {
			continue
		}
		name := strconv.FormatInt(int64(index), 10)
		each(name)
	}

	self._stash.enumerate(each)
}

// write

func (self *_argumentsStash) canPut(name string) bool {
	value := self.getArgument(name)
	if !value.isEmpty() {
		return true
	}
	return self._stash.canPut(name)
}

func (self *_argumentsStash) put(name string, value Value) {
	_value := self.getArgument(name)
	if !_value.isEmpty() {
		index := stringToArrayIndex(name)
		name := self.indexOfParameterName[index]
		self.environment.SetMutableBinding(name, value, false)
		return
	}
	self._stash.put(name, value)
}

func (self *_argumentsStash) delete(name string) {
	value := self.getArgument(name)
	if !value.isEmpty() {
		index := stringToArrayIndex(name)
		self.indexOfParameterName[index] = ""
	}
	self._stash.delete(name)
}
