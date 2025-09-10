//go:build windows

package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"runtime/debug"
	"syscall"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/common"
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
	pipeFlag := flag.String("pipe", "", "Named pipe to listen on (overrides env LANTERN_PIPE_NAME)")
	dataFlag := flag.String("data", "", "Data dir (overrides env LANTERN_DATA_DIR)")
	logFlag := flag.String("log", "", "Log dir (overrides env LANTERN_LOG_DIR)")
	localeFlag := flag.String("locale", "", "Locale")
	tokenFlag := flag.String("token", "", "IPC token path (overrides env LANTERN_TOKEN_PATH)")
	flag.Parse()

	opts := resolveOpts(*pipeFlag, *dataFlag, *logFlag, *localeFlag, *tokenFlag)

	if *consoleMode {
		runConsole(opts)
		return
	}

	isService, _ := svc.IsWindowsService()
	if isService {
		if err := svc.Run(common.WindowsServiceName, &lanternHandler{opts: opts}); err != nil {
			log.Error(err)
		}
	}
	runConsole(opts)
}

func newWindowsService(opts wintunmgr.ServiceOptions) (*wintunmgr.Manager, *wintunmgr.Service) {
	wt := wintunmgr.New(adapterName, poolName, nil)
	s := wintunmgr.NewService(opts, wt)
	return wt, s
}

func runConsole(opts wintunmgr.ServiceOptions) {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	log.Debugf("Starting %s in console mode (pid=%d)", common.WindowsServiceName, os.Getpid())

	defer guard("runConsole")

	_, s := newWindowsService(opts)

	if err := s.Start(ctx); err != nil {
		os.Exit(1)
	}
}

type lanternHandler struct{ opts wintunmgr.ServiceOptions }

func (h *lanternHandler) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (svcSpecificEC bool, exitCode uint32) {
	const accepts = svc.AcceptStop | svc.AcceptShutdown

	defer guard("lanternHandler.Execute")

	changes <- svc.Status{
		State:    svc.StartPending,
		WaitHint: 10 * 1000,
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start service
	started := make(chan error, 1)
	go func() {
		defer guard("service worker")
		_, s := newWindowsService(h.opts)
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

func resolveOpts(pipeArg, dataArg, logArg, localeArg, tokenArg string) wintunmgr.ServiceOptions {
	env := func(k, def string) string {
		if v := os.Getenv(k); v != "" {
			return v
		}
		return def
	}
	// Defaults
	progData := env("ProgramData", `C:\ProgramData`)
	localApp := env("LOCALAPPDATA", progData)

	pipe := first(pipeArg, env("LANTERN_PIPE_NAME", `\\.\pipe\LanternService`))
	data := first(dataArg, env("LANTERN_DATA_DIR", fmt.Sprintf(`%s\Lantern`, localApp)))
	logs := first(logArg, env("LANTERN_LOG_DIR", fmt.Sprintf(`%s\Lantern\logs`, localApp)))
	locale := first(localeArg, env("LANTERN_LOCALE", "en-US"))
	token := first(tokenArg, env("LANTERN_TOKEN_PATH", fmt.Sprintf(`%s\Lantern\ipc-token`, progData)))
	if _, err := os.Stat(token); err != nil && os.Getenv("LANTERN_PIPE_NAME") == "" && pipe == `\\.\pipe\LanternService` {
		pipe = `\\.\pipe\LanternService.dev`
		token = fmt.Sprintf(`%s\Lantern\ipc-token.dev`, localApp)
	}

	return wintunmgr.ServiceOptions{
		PipeName:  pipe,
		DataDir:   data,
		LogDir:    logs,
		Locale:    locale,
		TokenPath: token,
	}
}

func first(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
