package lanterncore

import (
	"log/slog"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"

	rlog "github.com/getlantern/radiance/log"
)

// LogFileName is the basename used by SetupLogging for the in-process slog
// output. Distinct from the daemon's lantern.log so the two don't collide
// when their log directories happen to share a path.
const LogFileName = "lantern-core.log"

var (
	setupLoggingOnce sync.Once
	setupLoggingDir  atomic.Pointer[string]
)

// SetupLogging installs a file-based default slog handler that writes to
// <logDir>/lantern-core.log with rotation and the same format the radiance
// daemon uses. Idempotent — only the first call has effect.
//
// Call this from any host process that loads lanterncore as a library
// WITHOUT the radiance daemon running in the same process. Today that is
// every platform except Android:
//
//   - Windows / Linux desktop: UI talks to lanternd over a named pipe; the
//     UI process loads lanterncore via cgo FFI.
//   - iOS / macOS: UI talks to a Network / System Extension over XPC; the
//     UI process loads lanterncore via gomobile bindings.
//   - Android: UI and VPN service share a process; radiance.common.Init
//     there already sets up slog → lantern.log, so this function should
//     NOT be called from Android or it would override the daemon's handler.
//
// Captures Go-side logs from lanterncore and everything it transitively
// calls (apps scanner, vpn helpers, etc.) — complementary to flutter.log
// (Dart-only) and to the daemon's lantern.log (separate process).
//
// Best-effort: any failure (logDir uncreatable, file unopenable) leaves the
// existing default handler in place and emits a warning so a
// console-attached build can still surface the diagnostic.
func SetupLogging(logDir, level string) {
	setupLoggingOnce.Do(func() {
		if logDir == "" {
			slog.Warn("lanterncore.SetupLogging: empty logDir, sticking with default handler")
			return
		}
		if err := os.MkdirAll(logDir, 0o755); err != nil {
			slog.Warn("lanterncore.SetupLogging: unable to create logDir, sticking with default handler", "logDir", logDir, "err", err)
			return
		}
		if level == "" {
			level = DefaultLogLevel
		}
		logger := rlog.NewLogger(rlog.Config{
			LogPath: filepath.Join(logDir, LogFileName),
			Level:   level,
			Prod:    true,
			// The desktop FFI's logsPort pipeline streams the DAEMON's logs to
			// the UI diagnostic logs screen. lanterncore's own logs go to the
			// file only for now; wiring them into rlog.Publisher() so they
			// also appear in the UI is a separate follow-up.
			DisablePublisher: true,
		})
		slog.SetDefault(logger)
		setupLoggingDir.Store(&logDir)
	})
}

// LogDir returns the log directory registered by SetupLogging, or "" if
// SetupLogging was never called (e.g. the Android host process, where the
// daemon's common.Init owns logging instead). Used by ReportIssue to glob
// UI-process log files for inclusion in the issue archive — those files
// live outside the daemon's logDir and would otherwise be invisible to the
// daemon-side archive builder.
func LogDir() string {
	if p := setupLoggingDir.Load(); p != nil {
		return *p
	}
	return ""
}
