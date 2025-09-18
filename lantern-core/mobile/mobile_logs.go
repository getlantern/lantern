package mobile

import (
	"context"
	"sync"
	"time"

	"github.com/getlantern/lantern-outline/lantern-core/logstream"
)

type LogSink interface {
	WriteLogs(string)
}

var (
	logsMu    sync.Mutex
	logStream logstream.Stream
	logCancel context.CancelFunc
)

// StartLogs starts the Go tailer and pushes batches to the Swift LogSink
func StartLogs(sink LogSink, dataDir, logFile string, intervalMs int64) error {
	logsMu.Lock()
	defer logsMu.Unlock()
	if logStream != nil {
		return nil
	}
	ctx, cancel := context.WithCancel(context.Background())
	logCancel = cancel

	logStream = logstream.New(logstream.Options{
		DataDir:  dataDir,
		LogFile:  logFile,
		Interval: time.Duration(intervalMs) * time.Millisecond,
	})

	return logStream.Start(ctx, func(batch string) {
		if sink != nil && batch != "" {
			sink.WriteLogs(batch)
		}
	})
}

func StopLogs() {
	logsMu.Lock()
	defer logsMu.Unlock()
	if logCancel != nil {
		logCancel()
		logCancel = nil
	}
	if logStream != nil {
		_ = logStream.Stop()
		logStream = nil
	}
}
