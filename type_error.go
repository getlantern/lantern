package otto

func (runtime *_runtime) newErrorObject(message Value) *_object {
	self := runtime.newClassObject("Error")
	if message.IsDefined() {
		self.WriteValue("message", toValue(toString(message)), false)
	}
	return self
}
