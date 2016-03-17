package ui

type EnvelopeType struct {
	Type string
}

// Envelope is a struct that wraps messages and associates them with a type.
type Envelope struct {
	EnvelopeType
	Message interface{}
}
