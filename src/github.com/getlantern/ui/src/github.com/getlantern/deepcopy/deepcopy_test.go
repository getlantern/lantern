package deepcopy

import (
	"reflect"
	"testing"

	"github.com/davecgh/go-spew/spew"
)

type A struct {
	String  string
	Int     int
	Strings []string
	Ints    map[string]int
	As      map[string]*A
}

func TestCopy(t *testing.T) {
	src := map[string]interface{}{
		"String":  "Hello World",
		"Int":     5,
		"Strings": []string{"A", "B"},
		"Ints":    map[string]int{"A": 1, "B": 2},
		"As": map[string]map[string]interface{}{
			"One": map[string]interface{}{
				"String": "2",
			},
			"Two": map[string]interface{}{
				"String": "3",
			},
		},
	}
	dst := &A{
		Strings: []string{"C"},
		Ints:    map[string]int{"B": 3, "C": 4},
		As:      map[string]*A{"One": &A{String: "1", Int: 5}}}
	expected := &A{
		String:  "Hello World",
		Int:     5,
		Strings: []string{"A", "B"},
		Ints:    map[string]int{"A": 1, "B": 2, "C": 4},
		As: map[string]*A{
			"One": &A{String: "2"},
			"Two": &A{String: "3"},
		},
	}
	err := Copy(dst, src)
	t.Log(spew.Sdump(dst))
	if err != nil {
		t.Errorf("Unable to copy!")
	}
	if !reflect.DeepEqual(expected, dst) {
		t.Errorf("expected and dst differed")
	}
}
