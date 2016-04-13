// Shamelessly stolen from goptlib's args_test.go.

package socks5

import (
	"testing"

	"git.torproject.org/pluggable-transports/goptlib.git"
)

func stringSlicesEqual(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func argsEqual(a, b pt.Args) bool {
	for k, av := range a {
		bv := b[k]
		if !stringSlicesEqual(av, bv) {
			return false
		}
	}
	for k, bv := range b {
		av := a[k]
		if !stringSlicesEqual(av, bv) {
			return false
		}
	}
	return true
}

func TestParseClientParameters(t *testing.T) {
	badTests := [...]string{
		"key",
		"key\\",
		"=value",
		"==value",
		"==key=value",
		"key=value\\",
		"a=b;key=value\\",
		"a;b=c",
		";",
		"key=value;",
		";key=value",
		"key\\=value",
	}
	goodTests := [...]struct {
		input    string
		expected pt.Args
	}{
		{
			"",
			pt.Args{},
		},
		{
			"key=",
			pt.Args{"key": []string{""}},
		},
		{
			"key==",
			pt.Args{"key": []string{"="}},
		},
		{
			"key=value",
			pt.Args{"key": []string{"value"}},
		},
		{
			"a=b=c",
			pt.Args{"a": []string{"b=c"}},
		},
		{
			"key=a\nb",
			pt.Args{"key": []string{"a\nb"}},
		},
		{
			"key=value\\;",
			pt.Args{"key": []string{"value;"}},
		},
		{
			"key=\"value\"",
			pt.Args{"key": []string{"\"value\""}},
		},
		{
			"key=\"\"value\"\"",
			pt.Args{"key": []string{"\"\"value\"\""}},
		},
		{
			"\"key=value\"",
			pt.Args{"\"key": []string{"value\""}},
		},
		{
			"key=value;key=value",
			pt.Args{"key": []string{"value", "value"}},
		},
		{
			"key=value1;key=value2",
			pt.Args{"key": []string{"value1", "value2"}},
		},
		{
			"key1=value1;key2=value2;key1=value3",
			pt.Args{"key1": []string{"value1", "value3"}, "key2": []string{"value2"}},
		},
		{
			"\\;=\\;;\\\\=\\;",
			pt.Args{";": []string{";"}, "\\": []string{";"}},
		},
		{
			"a\\=b=c",
			pt.Args{"a=b": []string{"c"}},
		},
		{
			"shared-secret=rahasia;secrets-file=/tmp/blob",
			pt.Args{"shared-secret": []string{"rahasia"}, "secrets-file": []string{"/tmp/blob"}},
		},
		{
			"rocks=20;height=5.6",
			pt.Args{"rocks": []string{"20"}, "height": []string{"5.6"}},
		},
	}

	for _, input := range badTests {
		_, err := parseClientParameters(input)
		if err == nil {
			t.Errorf("%q unexpectedly succeeded", input)
		}
	}

	for _, test := range goodTests {
		args, err := parseClientParameters(test.input)
		if err != nil {
			t.Errorf("%q unexpectedly returned an error: %s", test.input, err)
		}
		if !argsEqual(args, test.expected) {
			t.Errorf("%q → %q (expected %q)", test.input, args, test.expected)
		}
	}
}
