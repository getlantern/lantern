//go:build linux

package main

import (
	"flag"
	"log"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sagernet/sing-box/experimental/libbox"

	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/vpn"
)

var (
	dataPath = flag.String("data-path", "$HOME/.lantern", "Path to store data")
	logPath  = flag.String("log-path", "$HOME/.lantern", "Path to store logs")
	logLevel = flag.String("log-level", "info", "Logging level (trace, debug, info, warn, error)")
)

func main() {
	flag.Parse()

	dp := os.ExpandEnv(*dataPath)
	lp := os.ExpandEnv(*logPath)

	slog.Info("Starting lanternsvc (radiance daemon)", "version", common.Version, "dataPath", dp, "logPath", lp)

	platIfceProvider := func() libbox.PlatformInterface { return nil }
	ipcServer, err := vpn.InitIPC(dp, lp, *logLevel, platIfceProvider)
	if err != nil {
		log.Fatalf("Failed to initialize IPC: %v\n", err)
	}
	defer ipcServer.Close()

	// Wait for a signal to gracefully shut down.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	slog.Info("Shutting down...")
	time.AfterFunc(15*time.Second, func() {
		log.Fatal("Failed to shut down in time, forcing exit.")
	})

	status, _ := vpn.GetStatus()
	if status.TunnelOpen {
		vpn.Disconnect()
	}
}
