package lanterncore

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"sync"
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

// Pairing IDs never reach the app in snapshots: the globe draws a friend's
// traffic as any other, so both events strip peerBytes[].pairing.
func TestSnapshotsDropPeerPairing(t *testing.T) {
	for _, tc := range []struct {
		name string
		poll func(ctx context.Context, notify func(string, string))
	}{
		{"peer-snapshot", func(ctx context.Context, notify func(string, string)) {
			pollPeerSnapshots(ctx, nil, func(context.Context) (peer.Snapshot, error) {
				return peer.Snapshot{PeerBytes: []peer.PeerBytes{{IP: "192.0.2.1", Down: 1, Pairing: "secret-pairing"}}}, nil
			}, notify)
		}},
		{"unbounded-snapshot", func(ctx context.Context, notify func(string, string)) {
			pollUnboundedSnapshots(ctx, nil, func(context.Context) (unbounded.Snapshot, error) {
				return unbounded.Snapshot{PeerBytes: []unbounded.PeerBytes{{IP: "192.0.2.1", Down: 1, Pairing: "secret-pairing"}}}, nil
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
			if !strings.HasPrefix(got, tc.name+" ") || !strings.Contains(got, `{"ip":"192.0.2.1","down":1,"up":0}`) {
				t.Fatalf("event = %q", got)
			}
			if strings.Contains(got, "pairing") || strings.Contains(got, "secret-pairing") {
				t.Fatalf("event carries a pairing: %q", got)
			}
		})
	}
}

// The gate runs poll at the closed rate until opened, then at the open rate,
// canceling the previous call each time it changes.
func TestPollGateSwitchesRate(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var g pollGate
	type call struct {
		ctx   context.Context
		ticks <-chan time.Time
	}
	calls := make(chan call)
	done := make(chan struct{})
	go func() {
		g.run(ctx, time.Millisecond, time.Hour, func(pollCtx context.Context, ticks <-chan time.Time) {
			calls <- call{pollCtx, ticks}
			<-pollCtx.Done()
		})
		close(done)
	}()

	next := func() call {
		t.Helper()
		select {
		case c := <-calls:
			return c
		case <-time.After(time.Second):
			t.Fatal("no poll call")
			return call{}
		}
	}
	ticks := func(c call) bool {
		select {
		case <-c.ticks:
			return true
		case <-time.After(50 * time.Millisecond):
			return false
		}
	}

	closed := next()
	if ticks(closed) {
		t.Fatal("closed gate ticked at the open rate")
	}
	g.set(true)
	<-closed.ctx.Done()
	open := next()
	if !ticks(open) {
		t.Fatal("open gate did not tick at the open rate")
	}
	g.set(false)
	<-open.ctx.Done()
	if ticks(next()) {
		t.Fatal("closed again but still ticking at the open rate")
	}

	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("run did not return after ctx was canceled")
	}
}

// The listeners read once at each rate change and then on each tick: a closed
// gate reads at the idle rate, an open one at the snapshot rate.
func TestRunSnapshotsReadsAtEachRate(t *testing.T) {
	defer func(fast, idle time.Duration) {
		snapshotInterval, idleSnapshotInterval = fast, idle
	}(snapshotInterval, idleSnapshotInterval)
	snapshotInterval, idleSnapshotInterval = 5*time.Millisecond, time.Hour

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var g pollGate
	var mu sync.Mutex
	reads := 0
	count := func() int { mu.Lock(); defer mu.Unlock(); return reads }
	go runSnapshots(ctx, &g, func(pollCtx context.Context, ticks <-chan time.Time) {
		pollUnboundedSnapshots(pollCtx, ticks, func(context.Context) (unbounded.Snapshot, error) {
			mu.Lock()
			reads++
			mu.Unlock()
			return unbounded.Snapshot{}, nil
		}, func(string, string) {})
	})

	time.Sleep(100 * time.Millisecond)
	if n := count(); n != 1 {
		t.Fatalf("closed gate read %d times in 100ms, want 1", n)
	}
	g.set(true)
	deadline := time.Now().Add(5 * time.Second)
	for count() < 6 {
		if time.Now().After(deadline) {
			t.Fatalf("open gate read only %d times in 5s at a 5ms rate", count())
		}
		time.Sleep(5 * time.Millisecond)
	}
}

// Closing the gate mid-poll must not report Unbounded as unavailable.
func TestClosingGateDoesNotReportOutage(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	var g pollGate
	g.set(true)
	var events []string
	reads := 0
	g.run(ctx, time.Millisecond, time.Hour, func(pollCtx context.Context, ticks <-chan time.Time) {
		pollUnboundedSnapshots(pollCtx, ticks, func(c context.Context) (unbounded.Snapshot, error) {
			reads++
			if reads == 2 {
				g.set(false)
				<-c.Done()
				cancel()
				return unbounded.Snapshot{}, c.Err()
			}
			return unbounded.Snapshot{}, nil
		}, func(name, _ string) { events = append(events, name) })
	})
	if !reflect.DeepEqual(events, []string{"unbounded-snapshot"}) {
		t.Fatalf("events = %v", events)
	}
}
