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

	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/vpn"
	"github.com/getlantern/radiance/vpn/ipc"
)

var (
	dataPath   = flag.String("data-path", "$HOME/.lantern", "Path to store data")
	logPath    = flag.String("log-path", "$HOME/.lantern", "Path to store logs")
	logLevel   = flag.String("log-level", "info", "Logging level (trace, debug, info, warn, error)")
	socketPath = flag.String("socket-path", "", "Full path for the IPC unix socket (overrides default)")
)

func main() {
	flag.Parse()

	dp := os.ExpandEnv(*dataPath)
	lp := os.ExpandEnv(*logPath)

	if *socketPath != "" {
		sp := os.ExpandEnv(*socketPath)
		ipc.SetSocketPath(sp)
		slog.Info("Overriding IPC socket path", "socketPath", sp)
	}

	slog.Info("Starting lanternsvc (radiance daemon)", "version", common.Version, "dataPath", dp, "logPath", lp)

	ipcServer, err := vpn.InitIPC(dp, lp, *logLevel, nil)
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
