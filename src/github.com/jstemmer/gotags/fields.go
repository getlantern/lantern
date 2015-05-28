package main

import (
	"fmt"
	"regexp"
)

// FieldSet is a set of extension fields to include in a tag.
type FieldSet map[TagField]bool

// Includes tests whether the given field is included in the set.
func (f FieldSet) Includes(field TagField) bool {
	b, ok := f[field]
	return ok && b
}

// ErrInvalidFields is an error returned when attempting to parse invalid
// fields.
type ErrInvalidFields struct {
	Fields string
}

func (e ErrInvalidFields) Error() string {
	return fmt.Sprintf("invalid fields: %s", e.Fields)
}

// currently only "+l" is supported
var fieldsPattern = regexp.MustCompile(`^\+l$`)

func parseFields(fields string) (FieldSet, error) {
	if fields == "" {
		return FieldSet{}, nil
	}
	if fieldsPattern.MatchString(fields) {
		return FieldSet{Language: true}, nil
	}
	return FieldSet{}, ErrInvalidFields{fields}
}
