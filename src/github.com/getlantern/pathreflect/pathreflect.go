// package pathreflect provides the ability to address an object graph using
// a path notation and then modify the addressed node.
package pathreflect

import (
	"fmt"
	"reflect"
	"strconv"
	"strings"

	spew "github.com/davecgh/go-spew/spew"
)

const (
	PathSep = "/"
)

var (
	zeroValue = reflect.Value{}
)

type Path []string

func Parse(pathString string) Path {
	parts := strings.Split(pathString, PathSep)
	finalParts := []string{}
	// Remove empty parts (i.e. extra slashes)
	for _, part := range parts {
		if part != "" {
			finalParts = append(finalParts, part)
		}
	}
	return Path(finalParts)
}

// Get gets the value in the given on at this Path.
func (p Path) Get(on interface{}) (interface{}, error) {
	parent, current, nameOrIndex, err := p.descend(on)
	if err != nil {
		return nil, err
	}

	if parent.Kind() == reflect.Map {
		// For maps, get the value from the parent
		result := parent.MapIndex(reflect.ValueOf(nameOrIndex))
		if result == zeroValue {
			return nil, fmt.Errorf("Unable to get value")
		}
		return result.Interface(), nil
	} else {
		// For structs and slices, get the value itself
		return current.Interface(), nil
	}
}

// Set sets the given value in the given on at this Path.
func (p Path) Set(on interface{}, val interface{}) error {
	parent, current, nameOrIndex, err := p.descend(on)
	if err != nil {
		return err
	}

	if parent.Kind() == reflect.Map {
		// For maps, set the value on the parent
		parent.SetMapIndex(reflect.ValueOf(nameOrIndex), reflect.ValueOf(val))
	} else {
		// For structs and slices, set the value using Set on the terminal field
		current.Set(reflect.ValueOf(val))
	}
	return nil
}

// Clear clears the given value in the given on at this Path.
func (p Path) Clear(on interface{}) error {
	parent, current, nameOrIndex, err := p.descend(on)
	if err != nil {
		return err
	}

	if parent.Kind() == reflect.Map {
		// For maps, remove the value from the parent
		zeroValueOfValue := reflect.ValueOf(nil)
		parent.SetMapIndex(reflect.ValueOf(nameOrIndex), zeroValueOfValue)
	} else {
		// For structs and slices, set the value using Set on the terminal field
		zeroValueOfType := reflect.Zero(current.Type())
		current.Set(zeroValueOfType)
	}
	return nil
}

// ZeroValue returns the ZeroValue corresponding to the type of element at this
// path.
func (p Path) ZeroValue(on interface{}) (val interface{}, err error) {
	parent, current, _, err := p.descend(on)
	if err != nil {
		return nil, err
	}
	var t reflect.Type
	if parent.Kind() == reflect.Map || parent.Kind() == reflect.Slice || parent.Kind() == reflect.Array {
		t = parent.Type().Elem()
	} else {
		t = current.Type()
	}
	if t.Kind() == reflect.Ptr {
		return reflect.New(t.Elem()).Interface(), nil
	} else {
		return reflect.Zero(t).Interface(), nil
	}
}

func (p Path) String() string {
	return strings.Join(p, PathSep)
}

func (p Path) descend(on interface{}) (parent reflect.Value, current reflect.Value, nameOrIndex string, err error) {
	if len(p) == 0 {
		err = fmt.Errorf("Path must contain at least one element")
		return
	}

	current = reflect.ValueOf(on)
	nameOrIndex = ""
	for i := 0; i < len(p); i++ {
		if i > 0 {
			parent = current
		}
		nameOrIndex = p[i]
		current, err = getChild(current, nameOrIndex)
		if err != nil {
			err = fmt.Errorf("On %s, error traversing beyond path %s: %s", spew.Sdump(on), p.through(i), err)
			return
		}
	}

	return
}

func (p Path) through(i int) string {
	return strings.Join(p[:i], PathSep)
}

func getChild(parent reflect.Value, nameOrIndex string) (val reflect.Value, err error) {
	if parent.Kind() == reflect.Ptr || parent.Kind() == reflect.Interface {
		if parent.IsNil() {
			err = fmt.Errorf("Empty parent value")
			return
		}
		parent = parent.Elem()
	}

	switch parent.Kind() {
	case reflect.Map:
		val = parent.MapIndex(reflect.ValueOf(nameOrIndex))
		return
	case reflect.Struct:
		val = parent.FieldByName(nameOrIndex)
		return
	case reflect.Array, reflect.Slice:
		i, err2 := strconv.Atoi(nameOrIndex)
		if err2 != nil {
			err = fmt.Errorf("%s is not a valid index for an array or slice", nameOrIndex)
			return
		}
		val = parent.Index(i)
		return
	default:
		err = fmt.Errorf("Unable to extract value %s from value of kind %s", nameOrIndex, parent.Kind())
		return
	}
}
