package lanterncore

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/getlantern/radiance/peer"
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

// The peer poller has no unavailable event: failed reads are skipped, and
// each success is sent under the peer event.
func TestPeerSnapshotsSkipFailedReads(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	ticks := make(chan time.Time, 2)
	for range 2 {
		ticks <- time.Now()
	}
	calls := 0
	var events []string
	pollSnapshots(ctx, ticks, func(context.Context) (peer.Snapshot, error) {
		calls++
		if calls == 2 {
			return peer.Snapshot{Epoch: "run-1", BytesDown: 9}, nil
		}
		return peer.Snapshot{}, errors.New("offline")
	}, func(name, data string) {
		events = append(events, name+" "+data)
		cancel()
	}, "peer-snapshot", "")
	want := []string{`peer-snapshot {"epoch":"run-1","running":false,"peers":null,"bytesDown":9,"bytesUp":0,"peerBytes":null}`}
	if !reflect.DeepEqual(events, want) {
		t.Fatalf("events = %v, want %v", events, want)
	}
}

func TestUnboundedCancellationDoesNotReportOutage(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	pollUnboundedSnapshots(ctx, nil, func(ctx context.Context) (unbounded.Snapshot, error) {
		return unbounded.Snapshot{}, ctx.Err()
	}, func(name, _ string) { t.Fatalf("unexpected event: %s", name) })
}

// The globe labels a friend's arc from peerBytes[].pairing, so both snapshot
// events must carry it through to the app unchanged.
func TestSnapshotsCarryPeerPairing(t *testing.T) {
	for _, tc := range []struct {
		name string
		poll func(ctx context.Context, notify func(string, string))
	}{
		{"peer-snapshot", func(ctx context.Context, notify func(string, string)) {
			pollSnapshots(ctx, nil, func(context.Context) (peer.Snapshot, error) {
				return peer.Snapshot{PeerBytes: []peer.PeerBytes{{IP: "192.0.2.1", Down: 1, Pairing: "p1"}}}, nil
			}, notify, "peer-snapshot", "")
		}},
		{"unbounded-snapshot", func(ctx context.Context, notify func(string, string)) {
			pollUnboundedSnapshots(ctx, nil, func(context.Context) (unbounded.Snapshot, error) {
				return unbounded.Snapshot{PeerBytes: []unbounded.PeerBytes{{IP: "192.0.2.1", Down: 1, Pairing: "p1"}}}, nil
			}, notify)
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			var got string
			tc.poll(ctx, func(name, data string) {
				got = name + " " + data
				cancel()
			})
			if !strings.HasPrefix(got, tc.name+" ") || !strings.Contains(got, `{"ip":"192.0.2.1","down":1,"up":0,"pairing":"p1"}`) {
				t.Fatalf("event = %q", got)
			}
		})
	}
}
