package lanterncore

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"

	"github.com/getlantern/radiance/unbounded"
)

func TestUnboundedUnavailableIsEmittedOncePerOutage(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ticks := make(chan time.Time, 3)
	for range 3 {
		ticks <- time.Now()
	}
	calls := 0
	var events []string
	pollUnboundedSnapshots(ctx, ticks, func(context.Context) (unbounded.Snapshot, error) {
		calls++
		if calls == 3 {
			return unbounded.Snapshot{Running: true}, nil
		}
		return unbounded.Snapshot{}, errors.New("offline")
	}, func(name, _ string) {
		events = append(events, name)
		if len(events) == 3 {
			cancel()
		}
	})
	want := []string{"unbounded-unavailable", "unbounded-snapshot", "unbounded-unavailable"}
	if !reflect.DeepEqual(events, want) {
		t.Fatalf("events = %v, want %v", events, want)
	}
	if calls != 4 {
		t.Fatalf("read calls = %d, want 4", calls)
	}
}

func TestUnboundedCancellationDoesNotReportOutage(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	pollUnboundedSnapshots(ctx, nil, func(ctx context.Context) (unbounded.Snapshot, error) {
		return unbounded.Snapshot{}, ctx.Err()
	}, func(name, _ string) { t.Fatalf("unexpected event: %s", name) })
}
