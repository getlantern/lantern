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
	"github.com/getlantern/lantern-outline/lantern-core/common"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/wintunmgr"
	"golang.org/x/sys/windows/svc"
)

const (
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

	isService, err := svc.IsWindowsService()
	if err != nil {
		log.Fatal(err)
	}

	if *consoleMode || !isService {
		runConsole()
		return
	}

	// let SCM specify the service name
	if err := svc.Run(common.WindowsServiceName, &lanternHandler{}); err != nil {
		log.Error(err)
	}
}

func newWindowsService() (*wintunmgr.Manager, *wintunmgr.Service, error) {
	wt := wintunmgr.New(adapterName, poolName, nil)
	s := wintunmgr.NewService(wintunmgr.ServiceOptions{
		PipeName: servicePipeName,
		DataDir:  utils.DefaultDataDir(),
		LogDir:   utils.DefaultLogDir(),
	}, wt)
	return wt, s, nil
}

func runConsole() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	log.Debugf("Starting %s in console mode (pid=%d)", common.WindowsServiceName, os.Getpid())

	defer guard("runConsole")

	_, s, err := newWindowsService()
	if err != nil {
		log.Fatal(err)
	}

	if err := s.Start(ctx); err != nil {
		log.Fatal(err)
	}
}

type lanternHandler struct{}

func (h *lanternHandler) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (svcSpecificEC bool, exitCode uint32) {
	const accepts = svc.AcceptStop | svc.AcceptShutdown

	defer guard("lanternHandler.Execute")

	changes <- svc.Status{State: svc.StartPending, WaitHint: 30 * 1000}

	// Report Running to SCM
	changes <- svc.Status{State: svc.Running, Accepts: accepts}

	ctx, cancel := context.WithCancel(context.Background())

	started := make(chan error, 1)
	go func() {
		defer guard("service worker")
		_, s, err := newWindowsService()
		if err == nil {
			err = s.Start(ctx)
		}
		started <- err
	}()

	for {
		select {
		case c := <-r:
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
		}
	}
}
