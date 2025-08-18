//go:build windows

package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/wintunmgr"
)

const (
	adapterName     = "Lantern"
	poolName        = "Lantern"
	servicePipeName = `\\.\pipe\LanternService`
)

var (
	log = golog.LoggerFor("lantern-core.wintunmgr")
)

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	wt := wintunmgr.New("Lantern", "Lantern", nil)
	svc := wintunmgr.NewService(wintunmgr.ServiceOptions{
		PipeName: servicePipeName,
		DataDir:  utils.DefaultDataDir(),
		LogDir:   utils.DefaultLogDir(),
		Locale:   "en_US",
	}, wt)

	go func() {
		<-ctx.Done()
		time.Sleep(200 * time.Millisecond)
	}()

	if err := svc.Start(ctx); err != nil {
		os.Exit(1)
	}
}
