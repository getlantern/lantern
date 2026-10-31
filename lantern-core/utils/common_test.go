package utils

import "testing"

type testInterfaceListener struct{ id int }

func (*testInterfaceListener) UpdateDefaultInterface(string, int32, bool, bool) {}

func TestSameInterfaceUpdateListener(t *testing.T) {
	first := &testInterfaceListener{id: 1}
	second := &testInterfaceListener{id: 2}
	if !SameInterfaceUpdateListener(first, first) {
		t.Fatal("same Go listener must match across binding calls")
	}
	if SameInterfaceUpdateListener(first, second) {
		t.Fatal("different listeners must not match")
	}
	if SameInterfaceUpdateListener(first, nil) || SameInterfaceUpdateListener(nil, nil) {
		t.Fatal("missing listener must not match")
	}
}

func TestIsHighVolumeEvent(t *testing.T) {
	for _, typ := range []string{"unbounded-snapshot", "peer-snapshot", "peer-connection", "data-cap-event"} {
		if !IsHighVolumeEvent(typ) {
			t.Errorf("%s must be logged by type only", typ)
		}
	}
	for _, typ := range []string{"helper-live", "selection-changed", "server-location", "unbounded-unavailable", ""} {
		if IsHighVolumeEvent(typ) {
			t.Errorf("%s must be logged in full", typ)
		}
	}
}
