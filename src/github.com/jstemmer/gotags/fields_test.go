package main

import (
	"testing"
)

func TestParseFieldsEmpty(t *testing.T) {
	_, err := parseFields("")
	if err != nil {
		t.Fatalf("unexpected error from parseFields: %s", err)
	}
}

func TestParseFieldsLanguage(t *testing.T) {
	set, err := parseFields("+l")
	if err != nil {
		t.Fatalf("unexpected error from parseFields: %s", err)
	}
	if !set.Includes(Language) {
		t.Fatal("expected set to include Language")
	}
}

func TestParseFieldsInvalid(t *testing.T) {
	_, err := parseFields("junk")
	if err == nil {
		t.Fatal("expected parseFields to return error")
	}
	if _, ok := err.(ErrInvalidFields); !ok {
		t.Fatalf("expected parseFields to return error of type ErrInvalidFields, got %T", err)
	}
}
