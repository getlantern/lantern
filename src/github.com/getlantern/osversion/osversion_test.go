package osversion

import (
	"regexp"
	"runtime"
	"testing"
)

func TestString(t *testing.T) {
	reg := regexp.MustCompile("^([0-9])+\\.([0-9])+\\.([0-9])+.*")
	str, err := GetString()
	if err != nil {
		t.Fatal("Error getting string")
	}
	if !reg.MatchString(str) {
		t.Fatalf("Improper string format: %s", str)
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
			t.Fatalf("Improper human readable format: %s", str)
		}
	case "linux":
		str, err := GetHumanReadable()
		if err != nil {
			t.Fatal("Error getting string")
		}
		reg := regexp.MustCompile(".*kernel.+")
		if !reg.MatchString(str) {
			t.Fatalf("Improper human readable format: %s", str)
		}
	case "windows":
		str, err := GetHumanReadable()
		if err != nil {
			t.Fatal("Error getting string")
		}
		reg := regexp.MustCompile("Windows .+")
		if !reg.MatchString(str) {
			t.Fatalf("Improper human readable format: %s", str)
		}
	default:
		t.Fatal("Unsupported OS detected: %s", runtime.GOOS)
	}
}
