package mobile

import (
	"context"
	"log/slog"
	"math"
	"runtime"
	runtimeDebug "runtime/debug"
	"sync"
	"time"
)

// memoryLogInterval matches the iOS PacketTunnelProvider Swift memory logger
// cadence so the Go-side and Swift-side log lines interleave at the same rate.
const memoryLogInterval = 10 * time.Second

const bytesPerMB = 1024.0 * 1024.0

var (
	memLogMu     sync.Mutex
	memLogCancel context.CancelFunc
)

// startMemoryLogger begins periodic Go-runtime memory logging for the tunnel
// (extension) process. It is the Go counterpart to the Swift memory logger in
// PacketTunnelProvider: that one reports the whole extension process footprint
// via Mach task_vm_info (phys_footprint), while this reports the Go runtime's
// view from inside that same process. The Go heap is the largest mutable
// contributor to phys_footprint, and iOS jetsams the entire Network Extension
// when the footprint exceeds its tight memory cap — so correlating the two log
// streams shows whether Go is what's pushing the process toward that limit.
//
// Started from StartIPCServer (tunnel start) and stopped from CloseIPCServer
// (tunnel stop), mirroring the Swift logger's startTunnel/stopTunnel hooks.
// Safe to call repeatedly: a start while already running is a no-op until the
// matching stop.
func startMemoryLogger() {
	memLogMu.Lock()
	defer memLogMu.Unlock()
	if memLogCancel != nil {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	memLogCancel = cancel
	go func() {
		ticker := time.NewTicker(memoryLogInterval)
		defer ticker.Stop()
		logMemStats() // log immediately, like the Swift timer's deadline: .now()
		for {
			select {
			case <-ctx.Done():
				slog.Debug("Stopping tunnel memory logger")
				return
			case <-ticker.C:
				logMemStats()
			}
		}
	}()
}

// stopMemoryLogger stops the goroutine started by startMemoryLogger. Safe to
// call when the logger isn't running.
func stopMemoryLogger() {
	memLogMu.Lock()
	defer memLogMu.Unlock()
	if memLogCancel != nil {
		memLogCancel()
		memLogCancel = nil
	}
}

// mbFromBytes converts a byte count to megabytes rounded to 2 decimals, matching
// the "%.2f MB" formatting on the Swift side.
func mbFromBytes(b uint64) float64 {
	return math.Round(float64(b)/bytesPerMB*100) / 100
}

// logMemStats emits one Go-runtime memory snapshot. Field meanings:
//   - heap_alloc: live heap objects (the working set Go can't release)
//   - heap_inuse/heap_idle: bytes in in-use vs idle spans
//   - heap_released: idle bytes already returned to the OS (lowers footprint)
//   - stack_inuse: goroutine stacks
//   - sys: total obtained from the OS (Go's contribution to process footprint)
//   - next_gc: heap size that will trigger the next GC
//   - mem_limit: the soft memory limit in effect (libbox.SetMemoryLimit sets
//     this on mobile); 0 means no limit
func logMemStats() {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	// SetMemoryLimit(-1) reads the current soft limit without changing it;
	// math.MaxInt64 is the sentinel for "no limit".
	var limitMB float64
	if limit := runtimeDebug.SetMemoryLimit(-1); limit != math.MaxInt64 {
		limitMB = math.Round(float64(limit)/bytesPerMB*100) / 100
	}

	slog.Info("[memory stats]",
		"heap_alloc_mb", mbFromBytes(m.HeapAlloc),
		"heap_inuse_mb", mbFromBytes(m.HeapInuse),
		"heap_idle_mb", mbFromBytes(m.HeapIdle),
		"heap_released_mb", mbFromBytes(m.HeapReleased),
		"stack_inuse_mb", mbFromBytes(m.StackInuse),
		"sys_mb", mbFromBytes(m.Sys),
		"next_gc_mb", mbFromBytes(m.NextGC),
		"mem_limit_mb", limitMB,
		"num_gc", m.NumGC,
		"num_goroutine", runtime.NumGoroutine(),
	)
}
