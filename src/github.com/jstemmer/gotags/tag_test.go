package main

import (
	"testing"
)

func TestTagString(t *testing.T) {
	tag := NewTag("tagname", "filename", 2, "x")
	tag.Fields["access"] = "public"
	tag.Fields["type"] = "struct"
	tag.Fields["signature"] = "()"
	tag.Fields["empty"] = ""

	expected := "tagname\tfilename\t2;\"\tx\taccess:public\tline:2\tsignature:()\ttype:struct"

	s := tag.String()
	if s != expected {
		t.Errorf("Tag.String()\n  is:%s\nwant:%s", s, expected)
	}
}
