package ui

// Envelope is a struct that wraps messages and associates them with a type.
type Envelope struct {
	Type    string
	Message interface{}
}
