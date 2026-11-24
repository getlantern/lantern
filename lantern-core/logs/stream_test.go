package logs

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

func TestFollowResubscribesUntilCancelled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	var calls atomic.Int32
	done := make(chan struct{})
	go func() {
		defer close(done)
		follow(ctx, time.Millisecond, func(context.Context) error {
			if calls.Add(1) == 3 {
				cancel()
			}
			return errors.New("stream dropped")
		})
	}()

	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("follow didn't return after its context ended")
	}
	if got := calls.Load(); got != 3 {
		t.Fatalf("subscribed %d times, want 3", got)
	}
}

func TestFollowReturnsWhileWaitingToRetry(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	subscribed := make(chan struct{})
	done := make(chan struct{})
	go func() {
		defer close(done)
		follow(ctx, time.Hour, func(context.Context) error {
			close(subscribed)
			return errors.New("stream dropped")
		})
	}()

	<-subscribed
	cancel()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("follow waited out its retry delay after its context ended")
	}
}
