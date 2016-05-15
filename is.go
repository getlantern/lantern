package is

import (
	"io"
	"log"
	"os"
	"reflect"
	"testing"
)

var output io.Writer = os.Stdout

// Is provides methods that leverage the existing testing capabilities found
// in the Go test framework. The methods provided allow for a more natural,
// efficient and expressive approach to writing tests. The goal is to write
// fewer lines of code while improving communication of intent.
type Is struct {
	TB         testing.TB
	strict     bool
	failFormat string
	failArgs   []interface{}
}

// New creates a new instance of the Is object and stores a reference to the
// provided testing object.
func New(tb testing.TB) *Is {
	if tb == nil {
		log.Fatalln("You must provide a testing object.")
	}
	return &Is{TB: tb, strict: true}
}

// Msg defines a message to print in the event of a failure. This allows you
// to print out additional information about a failure if it happens.
func (is *Is) Msg(format string, args ...interface{}) *Is {
	return &Is{
		TB:         is.TB,
		failFormat: format,
		failArgs:   args,
		strict:     is.strict,
	}
}

// Lax returns a copy of this instance of Is which does not abort the test if
// a failure occurs. Use this to run a set of tests and see all the failures
// at once.
func (is *Is) Lax() *Is {
	return &Is{
		TB:         is.TB,
		strict:     false,
		failFormat: is.failFormat,
		failArgs:   is.failArgs,
	}
}

// Strict returns a copy of this instance of Is which aborts the test if a
// failure occurs. This is the default behavior, thus this method has no
// effect unless it is used to reverse a previous call to Lax.
func (is *Is) Strict() *Is {
	return &Is{
		TB:         is.TB,
		strict:     true,
		failFormat: is.failFormat,
		failArgs:   is.failArgs,
	}
}

// Equal performs a deep compare of the provided objects and fails if they are
// not equal.
//
// Equal does not respect type differences. If the types are different and
// comparable (eg int32 and int64), they will be compared as though they are
// the same type.
func (is *Is) Equal(a interface{}, b interface{}) {
	if !isEqual(a, b) {
		fail(is, "expected objects '%s' and '%s' to be equal, but got: %v and %v",
			objectTypeName(a),
			objectTypeName(b), a, b)
	}
}

// NotEqual performs a deep compare of the provided objects and fails if they are
// equal.
//
// NotEqual does not respect type differences. If the types are different and
// comparable (eg int32 and int64), they will be compared as though they are
// the same type.
func (is *Is) NotEqual(a interface{}, b interface{}) {
	if isEqual(a, b) {
		fail(is, "expected objects '%s' and '%s' not to be equal",
			objectTypeName(a),
			objectTypeName(b))
	}
}

// OneOf performs a deep compare of the provided object and an array of
// comparison objects. It fails if the first object is not equal to one of the
// comparison objects.
//
// OneOf does not respect type differences. If the types are different and
// comparable (eg int32 and int64), they will be compared as though they are
// the same type.
func (is *Is) OneOf(a interface{}, b ...interface{}) {
	result := false
	for _, o := range b {
		result = isEqual(a, o)
		if result {
			break
		}
	}
	if !result {
		fail(is, "expected object '%s' to be equal to one of '%s', but got: %v and %v",
			objectTypeName(a),
			objectTypeNames(b), a, b)
	}
}

// NotOneOf performs a deep compare of the provided object and an array of
// comparison objects. It fails if the first object is equal to one of the
// comparison objects.
//
// NotOneOf does not respect type differences. If the types are different and
// comparable (eg int32 and int64), they will be compared as though they are
// the same type.
func (is *Is) NotOneOf(a interface{}, b ...interface{}) {
	result := false
	for _, o := range b {
		result = isEqual(a, o)
		if result {
			break
		}
	}
	if result {
		fail(is, "expected object '%s' not to be equal to one of '%s', but got: %v and %v",
			objectTypeName(a),
			objectTypeNames(b), a, b)
	}
}

// Err checks the provided error object to determine if an error is present.
func (is *Is) Err(e error) {
	if isNil(e) {
		fail(is, "expected error")
	}
}

// NotErr checks the provided error object to determine if an error is not
// present.
func (is *Is) NotErr(e error) {
	if !isNil(e) {
		fail(is, "expected no error, but got: %v", e)
	}
}

// Nil checks the provided object to determine if it is nil.
func (is *Is) Nil(o interface{}) {
	if !isNil(o) {
		fail(is, "expected object '%s' to be nil, but got: %v", objectTypeName(o), o)
	}
}

// NotNil checks the provided object to determine if it is not nil.
func (is *Is) NotNil(o interface{}) {
	if isNil(o) {
		fail(is, "expected object '%s' not to be nil", objectTypeName(o))
	}
}

// True checks the provided boolean to determine if it is true.
func (is *Is) True(b bool) {
	if !b {
		fail(is, "expected boolean to be true")
	}
}

// False checks the provided boolean to determine if is false.
func (is *Is) False(b bool) {
	if b {
		fail(is, "expected boolean to be false")
	}
}

// Zero checks the provided object to determine if it is the zero value
// for the type of that object. The zero value is the same as what the object
// would contain when initialized but not assigned.
//
// This method, for example, would be used to determine if a string is empty,
// an array is empty or a map is empty. It could also be used to determine if
// a number is 0.
//
// In cases such as slice, map, array and chan, a nil value is treated the
// same as an object with len == 0
func (is *Is) Zero(o interface{}) {
	if !isZero(o) {
		fail(is, "expected object '%s' to be zero value, but it was: %v", objectTypeName(o), o)
	}
}

// NotZero checks the provided object to determine if it is not the zero
// value for the type of that object. The zero value is the same as what the
// object would contain when initialized but not assigned.
//
// This method, for example, would be used to determine if a string is not
// empty, an array is not empty or a map is not empty. It could also be used
// to determine if a number is not 0.
//
// In cases such as slice, map, array and chan, a nil value is treated the
// same as an object with len == 0
func (is *Is) NotZero(o interface{}) {
	if isZero(o) {
		fail(is, "expected object '%s' not to be zero value", objectTypeName(o))
	}
}

// Len checks the provided object to determine if it is the same length as the
// provided length argument.
//
// If the object is not one of type array, slice or map, it will fail.
func (is *Is) Len(o interface{}, l int) {
	t := reflect.TypeOf(o)
	if t.Kind() != reflect.Array &&
		t.Kind() != reflect.Slice &&
		t.Kind() != reflect.Map {
		fail(is, "expected object '%s' to be of length '%d', but the object is not one of array, slice or map", objectTypeName(o), l)
	}

	if reflect.ValueOf(o).Len() != l {
		fail(is, "expected object '%s' to be of length '%d'", objectTypeName(o), l)
	}
}

// SetOutput changes the message output Writer from the default (os.Stdout).
// This may be useful if the application under test takes over the console, or
// if logging to a file is desired.
func SetOutput(w io.Writer) {
	output = w
}
