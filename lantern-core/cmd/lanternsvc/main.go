//go:build windows

package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/wintunmgr"
	"golang.org/x/sys/windows/svc"
)

const (
	svcName         = "LanternSvc"
	adapterName     = "Lantern"
	poolName        = "Lantern"
	servicePipeName = `\\.\pipe\LanternService`
)

var log = golog.LoggerFor("lantern-core.wintunmgr")

func main() {

	consoleMode := flag.Bool("console", false, "Run in console mode instead of Windows service")
	flag.Parse()

	if *consoleMode {
		runConsole()
		return
	}

	isService, _ := svc.IsWindowsService()
	if isService {
		if err := svc.Run(svcName, &lanternHandler{}); err != nil {
			runConsole()
		}
		return
	}
	runConsole()
}

func runConsole() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	wt := wintunmgr.New(adapterName, poolName, nil)
	s := wintunmgr.NewService(wintunmgr.ServiceOptions{
		PipeName: servicePipeName,
		DataDir:  utils.DefaultDataDir(),
		LogDir:   utils.DefaultLogDir(),
		Locale:   "en_US",
	}, wt)

	if err := s.Start(ctx); err != nil {
		os.Exit(1)
	}
}

type lanternHandler struct{}

func (h *lanternHandler) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (svcSpecificEC bool, exitCode uint32) {
	const accepts = svc.AcceptStop | svc.AcceptShutdown

	changes <- svc.Status{
		State:    svc.StartPending,
		WaitHint: 10 * 1000, // milliseconds; optional
	}

	ctx, cancel := context.WithCancel(context.Background())

	// Start service
	started := make(chan error, 1)
	go func() {
		wt := wintunmgr.New(adapterName, poolName, nil)
		s := wintunmgr.NewService(wintunmgr.ServiceOptions{
			PipeName: servicePipeName,
			DataDir:  utils.DefaultDataDir(),
			LogDir:   utils.DefaultLogDir(),
			Locale:   "en_US",
		}, wt)
		err := s.Start(ctx)
		started <- err
	}()

	// Report Running to SCM
	changes <- svc.Status{State: svc.Running, Accepts: accepts}

	for {
		select {
		case c, ok := <-r:
			if !ok {
				cancel()
				if err := <-started; err != nil {
					log.Errorf("service worker exited after SCM channel close: %v", err)
					return false, 1
				}
				return false, 0
			}
			switch c.Cmd {
			case svc.Interrogate:
				changes <- c.CurrentStatus

			case svc.Stop, svc.Shutdown:
				changes <- svc.Status{State: svc.StopPending}
				cancel()
				if err := <-started; err != nil {
					log.Errorf("service worker exited with error on stop: %v", err)
					changes <- svc.Status{State: svc.Stopped}
					return false, 1
				}
				changes <- svc.Status{State: svc.Stopped}
				return false, 0
			}
		case err := <-started:
			if err != nil {
				log.Errorf("service worker exited unexpectedly: %v", err)
				changes <- svc.Status{State: svc.Stopped}
				return false, 1
			}
			changes <- svc.Status{State: svc.Stopped}
			return false, 0
		}
	}
}
