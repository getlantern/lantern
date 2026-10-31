package lanterncore

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"
)

type liveCall struct {
	known     bool
	connected map[string]bool
}

func TestHelperLiveNotifiesOnlyOnChangeAndCarriesNoPairing(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reads := []struct {
		connected map[string]bool
		err       error
	}{
		{map[string]bool{"pairing-secret": true}, nil},
		{map[string]bool{"pairing-secret": true}, nil},
		{nil, errors.New("ipc not running")},
		{map[string]bool{}, nil},
	}
	// One read comes before the first tick, so the last read finds no tick
	// left and only the cancellation.
	ticks := make(chan time.Time, len(reads)-1)
	for range len(reads) - 1 {
		ticks <- time.Now()
	}
	var calls []liveCall
	var last liveCall
	set := func(known bool, connected map[string]bool) bool {
		c := liveCall{known, connected}
		calls = append(calls, c)
		changed := !reflect.DeepEqual(c, last)
		last = c
		if len(calls) == len(reads) {
			defer cancel()
		}
		return changed
	}
	var events []string
	i := 0
	pollHelperLive(ctx, ticks, func(context.Context) (map[string]bool, error) {
		r := reads[i]
		i++
		return r.connected, r.err
	}, set, func(name, data string) {
		events = append(events, name+" "+data)
	})

	wantCalls := []liveCall{
		{true, map[string]bool{"pairing-secret": true}},
		{true, map[string]bool{"pairing-secret": true}},
		{false, nil},
		{true, map[string]bool{}},
	}
	if !reflect.DeepEqual(calls, wantCalls) {
		t.Fatalf("set calls = %v, want %v", calls, wantCalls)
	}
	want := []string{"helper-live {}", "helper-live {}", "helper-live {}"}
	if !reflect.DeepEqual(events, want) {
		t.Fatalf("events = %v, want %v", events, want)
	}
	for _, e := range events {
		if strings.Contains(e, "pairing") {
			t.Fatalf("event carries a pairing: %q", e)
		}
	}
}

func TestHelperLiveCancellationLeavesStatusAlone(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	pollHelperLive(ctx, nil, func(ctx context.Context) (map[string]bool, error) {
		return nil, ctx.Err()
	}, func(bool, map[string]bool) bool {
		t.Fatal("set after cancellation")
		return false
	}, func(name, _ string) { t.Fatalf("unexpected event: %s", name) })
}
