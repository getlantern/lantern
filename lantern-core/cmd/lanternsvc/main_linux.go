//go:build linux

package main

import (
	"context"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"github.com/getlantern/lantern-outline/lantern-core/linuxsvc"
)

func main() {
	var (
		socket  = flag.String("socket", "", "unix socket path (default: XDG_RUNTIME_DIR or /run/lantern/service.sock)")
		dataDir = flag.String("data-dir", "", "data dir (default: /var/lib/lantern)")
		logDir  = flag.String("log-dir", "", "log dir (default: /var/log/lantern)")
		locale  = flag.String("locale", "en-US", "locale")
		token   = flag.String("token-path", "", "token path (default: /var/lib/lantern/ipc-token)")
	)
	flag.Parse()

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	s := linuxsvc.NewService(linuxsvc.ServiceOptions{
		SocketPath: *socket,
		DataDir:    *dataDir,
		LogDir:     *logDir,
		Locale:     *locale,
		TokenPath:  *token,
	})

	if err := s.Start(ctx); err != nil {
		slog.Error("service exited", "err", err)
		os.Exit(1)
	}
}
