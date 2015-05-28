package draw

// Only called during init, so no need to synchronize.

var theDisplay *Display

func display() *Display {
	if theDisplay == nil {
		var err error
		theDisplay, err = Init(nil, "", "test", "")
		if err != nil {
			panic(err)
		}
	}
	return theDisplay
}
