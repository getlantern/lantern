// Package logs provides a shared helper for streaming diagnostic log entries
// from radiance's ipc client.
package logs

import (
	"context"
	"log/slog"

	"github.com/getlantern/radiance/ipc"
	rlog "github.com/getlantern/radiance/log"
)

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
