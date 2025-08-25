//go:build windows

package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"runtime"
	"runtime/debug"
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

func guard(where string) {
	if r := recover(); r != nil {
		buf := make([]byte, 1<<20)
		n := runtime.Stack(buf, true)
		log.Errorf("PANIC in %s: %v\n%s", where, r, string(buf[:n]))
	}
}

func init() {
	debug.SetTraceback("all")
	debug.SetPanicOnFault(true)
}

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
			log.Error(err)
		}
	}
	runConsole()
}

func runConsole() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	log.Debugf("Starting %s in console mode (pid=%d)", svcName, os.Getpid())

	defer guard("runConsole")

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

	defer guard("lanternHandler.Execute")

	changes <- svc.Status{
		State:    svc.StartPending,
		WaitHint: 10 * 1000,
	}

	ctx, cancel := context.WithCancel(context.Background())

	// Start service
	started := make(chan error, 1)
	go func() {
		defer guard("service worker")
		wt := wintunmgr.New(adapterName, poolName, nil)
		s := wintunmgr.NewService(wintunmgr.ServiceOptions{
			PipeName: servicePipeName,
			DataDir:  utils.DefaultDataDir(),
			LogDir:   utils.DefaultLogDir(),
			Locale:   "en_US",
		}, wt)
		err := s.Start(ctx)
		if err != nil {
			log.Errorf("Service worker returned error: %v", err)
		} else {
			log.Debugf("Service worker exited normally")
		}
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
