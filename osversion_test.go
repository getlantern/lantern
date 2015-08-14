package osversion

import (
	"regexp"
	"runtime"
	"testing"
)

func TestString(t *testing.T) {
	switch runtime.GOOS {
	case "darwin":
		str, err := GetString()
		if err != nil {
			t.Fatal("Error getting string")
		}
		reg := regexp.MustCompile("^([0-9])+\\.([0-9])+\\.([0-9])$")
		if !reg.MatchString(str) {
			t.Fatal("Improper string format")
		}
	default:
		t.Fatal("Unsupported OS detected")
	}
}

func TestHumanReadable(t *testing.T) {
	switch runtime.GOOS {
	case "darwin":
		str, err := GetHumanReadable()
		if err != nil {
			t.Fatal("Error getting string")
		}
		reg := regexp.MustCompile("OS X 10\\..+")
		if !reg.MatchString(str) {
			t.Fatal("Improper human readable format")
		}
	default:
		t.Fatal("Unsupported OS detected")
	}
}
