//go:build windows

package main

import (
	"context"
	"os"
	"os/signal"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/wintunmgr"
)

const (
	adapterName = "Lantern"
	poolName    = "Lantern"
)

var (
	log = golog.LoggerFor("lantern-core.wintunmgr")
)

func main() {
	mgr := wintunmgr.New(adapterName, poolName, nil)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	ad, err := mgr.OpenOrCreateTunAdapter(ctx)
	if err != nil {
		log.Fatalf("open wintun adapter: %v", err)
	}
	defer ad.Close()

	// Start Lantern core service here

	t := time.NewTicker(10 * time.Second)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Debug("shutting down…")
			return
		case <-t.C:
		}
	}
}
