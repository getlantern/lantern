package lanterncore

import (
	"log/slog"
	"os"
	"path/filepath"
	"sync"

	rlog "github.com/getlantern/radiance/log"
)

// LogFileName is the basename used by SetupLogging for the in-process slog
// output. Distinct from the daemon's lantern.log so the two don't collide
// when their log directories happen to share a path.
const LogFileName = "lantern-core.log"

var setupLoggingOnce sync.Once

// SetupLogging installs a file-based default slog handler that writes to
// <logDir>/lantern-core.log with rotation and the same format the radiance
// daemon uses. Idempotent — only the first call has effect.
//
// Call this from any host process that loads lanterncore as a library
// alongside the running radiance daemon, where lanterncore's slog output
// would otherwise be silently dropped — currently the Windows/Linux desktop
// FFI process. Captures Go-side logs from lanterncore and everything it
// transitively calls (apps scanner, vpn helpers, etc.) — complementary to
// flutter.log (Dart-only) and to the daemon's lantern.log (separate process).
//
// Do NOT call this from a process that runs the radiance daemon in-process
// (mobile, macOS via gomobile/system extension): there, radiance/common.Init
// has already configured slog to write to lantern.log, and a second
// SetDefault here would override that. Those processes already capture Go
// logs through the daemon's existing lantern.log.
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
	})
}
