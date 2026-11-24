// Package logs provides a shared helper for streaming diagnostic log entries
// from radiance's ipc client.
package logs

import (
	"context"
	"log/slog"
	"time"

	"github.com/getlantern/radiance/ipc"
	rlog "github.com/getlantern/radiance/log"
)

const followRetryDelay = 500 * time.Millisecond

// Subscribe streams log entries from client, invoking cb for each entry as a
// string. It blocks until ctx is cancelled or the underlying stream returns.
func Subscribe(ctx context.Context, client *ipc.Client, cb func(string)) error {
	defer func() {
		if r := recover(); r != nil {
			slog.Error("log stream panic", "panic", r)
		}
	}()
	return client.TailLogs(ctx, func(entry rlog.LogEntry) {
		cb(string(entry))
	})
}

// Follow is Subscribe until ctx ends, resubscribing whenever the stream drops,
// as it does while the service restarts.
func Follow(ctx context.Context, client *ipc.Client, cb func(string)) {
	follow(ctx, followRetryDelay, func(ctx context.Context) error {
		return Subscribe(ctx, client, cb)
	})
}

func follow(ctx context.Context, retryDelay time.Duration, subscribe func(context.Context) error) {
	for {
		err := subscribe(ctx)
		if ctx.Err() != nil {
			return
		}
		slog.Debug("log stream disconnected", "error", err)
		select {
		case <-ctx.Done():
			return
		case <-time.After(retryDelay):
		}
	}
}
