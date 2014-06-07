package otto

func (runtime *_runtime) newErrorObject(message Value) *_object {
	self := runtime.newClassObject("Error")
	if message.IsDefined() {
		self.defineProperty("message", toValue_string(message.string()), 0111, false)
	}
	return self
}
