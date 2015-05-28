package plumb

import (
	"bytes"
	"fmt"
	"reflect"
	"testing"
)

func TestBasic(t *testing.T) {
	attr := &Attribute{
		Name:  "addr",
		Value: "/root/",
	}
	message := &Message{
		Src:  "plumb",
		Dst:  "edit",
		Dir:  "/Users/r",
		Type: "text",
		Attr: attr,
		Data: []byte("/etc/passwd"),
	}
	var buf bytes.Buffer
	buf.Reset()
	message.Send(&buf)
	m := new(Message)
	err := m.Recv(&buf)
	if err != nil {
		t.Fatalf("recv: %s", err)
	}
	if !reflect.DeepEqual(message, m) {
		t.Fatalf("difference:\n%+v\n%+v", message, m)
	}
}

type quoteTest struct {
	unquoted, quoted string
}

var quoteTests = []quoteTest{
	{"", ""},
	{"abc", "abc"},
	{" ", "' '"},
	{"'", "''''"},
	{"''", "''''''"},
	{"abc def", "'abc def'"},
	{"abc'def", "'abc''def'"},
	{"abc'' ''def", "'abc'''' ''''def'"},
}

func TestQuoting(t *testing.T) {
	for _, test := range quoteTests {
		q := quoteAttribute(test.unquoted)
		if q != test.quoted {
			t.Errorf("quoting failed: for %q expected %q got %q", test.unquoted, test.quoted, q)
		}
		u, err := unquoteAttribute(test.quoted)
		if err != nil {
			t.Errorf("unquoting error for %q: %s", test.quoted, err)
			continue
		}
		if u != test.unquoted {
			t.Errorf("unquoting failed: for %q expected %q got %q", test.quoted, test.unquoted, u)
		}
	}
}

func TestMultipleAttributes(t *testing.T) {
	// Make up a list of attributes from the quoting tests.
	var attr *Attribute
	for i, test := range quoteTests {
		attr = &Attribute{
			Name:  fmt.Sprintf("attr%d", i),
			Value: test.unquoted,
			Next:  attr,
		}
	}
	message := &Message{
		Src:  "plumb",
		Dst:  "edit",
		Dir:  "/Users/r",
		Type: "text",
		Attr: attr,
		Data: []byte("/etc/passwd"),
	}
	var buf bytes.Buffer
	buf.Reset()
	message.Send(&buf)
	m := new(Message)
	err := m.Recv(&buf)
	if err != nil {
		t.Fatalf("recv: %s", err)
	}
	if !reflect.DeepEqual(message, m) {
		t.Fatalf("difference:\n%+v\n%+v", message, m)
	}
}
