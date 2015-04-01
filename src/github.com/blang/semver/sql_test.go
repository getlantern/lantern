package semver

import (
	"testing"
)

type scanTest struct {
	val         interface{}
	shouldError bool
	expected    string
}

var scanTests = []scanTest{
	scanTest{"1.2.3", false, "1.2.3"},
	scanTest{[]byte("1.2.3"), false, "1.2.3"},
	scanTest{7, true, ""},
	scanTest{7e4, true, ""},
	scanTest{true, true, ""},
}

func TestScanString(t *testing.T) {
	for _, tc := range scanTests {
		s := &Version{}
		err := s.Scan(tc.val)
		if tc.shouldError {
			if err == nil {
				t.Fatalf("Scan did not return an error on %v (%T)", tc.val, tc.val)
			}
		} else {
			if err != nil {
				t.Fatalf("Scan returned an unexpected error: %s (%T) on %v (%T)", tc.val, tc.val, tc.val, tc.val)
			}
			if val, _ := s.Value(); val != tc.expected {
				t.Errorf("Wrong Value returned, expected %q, got %q", tc.expected, val)
			}
		}
	}
}
