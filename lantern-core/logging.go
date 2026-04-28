package lanterncore

import (
	"log/slog"
	"os"
	"path/filepath"

	rlog "github.com/getlantern/radiance/log"
)

// AppLogFileName is the basename used for main-app-side slog output on
// platforms where the tunnel extension owns lantern.log. Distinct from the
// extension's lantern.log so two lumberjack writers aren't racing on
// rotation of the same file.
const AppLogFileName = "lantern-app.log"

// setupAppLogging installs a file-based default slog handler writing to
// <logDir>/lantern-app.log. Used on iOS and macOS where the main app shares
// its logDir with the tunnel extension (which runs its own common.Init).
// Best-effort — any failure leaves the default stderr handler in place.
func setupAppLogging(logDir, level string) {
	if logDir == "" {
		slog.Warn("setupAppLogging: empty logDir, sticking with default handler")
		return
	}
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		slog.Warn("setupAppLogging: unable to create logDir", "logDir", logDir, "err", err)
		return
	}
	if level == "" {
		level = DefaultLogLevel
	}
	logger := rlog.NewLogger(rlog.Config{
		LogPath:          filepath.Join(logDir, AppLogFileName),
		Level:            level,
		Prod:             true,
		DisablePublisher: true,
	})
	slog.SetDefault(logger)
}
