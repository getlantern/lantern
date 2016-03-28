// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"fmt"
	"math/rand"
	"net/http"
	_ "net/http/pprof"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/flashlight"
	"github.com/getlantern/golog"
	"github.com/getlantern/i18n"
	"github.com/getlantern/profiling"

	"github.com/getlantern/flashlight/analytics"
	"github.com/getlantern/flashlight/autoupdate"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/ui"

	"github.com/mitchellh/panicwrap"
)

var (
	log = golog.LoggerFor("flashlight")

	showui = true

	exitCh = make(chan error, 1)

	// use buffered channel to avoid blocking the caller of 'addExitFunc'
	// the number 10 is arbitrary
	chExitFuncs = make(chan func(), 10)
)

func init() {
	// Passing public key and version to the autoupdate service.
	autoupdate.PublicKey = []byte(packagePublicKey)
	autoupdate.Version = flashlight.PackageVersion

	rand.Seed(time.Now().UnixNano())

	settings = LoadSettings(flashlight.Version, flashlight.RevisionDate, flashlight.BuildDate)
}

func logPanic(msg string) {
	cfg, err := config.Init(settings, flashlight.PackageVersion, *configdir, *stickyConfig, flagsAsMap())
	if err != nil {
		panic("Error initializing config")
	}
	if err := logging.EnableFileLogging(); err != nil {
		panic("Error initializing logging")
	}

	<-logging.Configure(eventual.DefaultGetter(""), "", cfg.Client.DeviceID, flashlight.Version, flashlight.RevisionDate)

	log.Error(msg)

	logging.Flush()
	_ = logging.Close()
}

func main() {
	// panicwrap works by re-executing the running program (retaining arguments,
	// environmental variables, etc.) and monitoring the stderr of the program.
	exitStatus, err := panicwrap.BasicWrap(
		func(output string) {
			logPanic(output)
			exit(nil)
		})
	if err != nil {
		// Something went wrong setting up the panic wrapper. This won't be
		// captured by panicwrap
		// At this point, continue execution without panicwrap support. There
		// are known cases where panicwrap will fail to fork, such as Windows
		// GUI app
		log.Errorf("Error setting up panic wrapper: %v", err)
	} else {
		// If exitStatus >= 0, then we're the parent process.
		if exitStatus >= 0 {
			os.Exit(exitStatus)
		}
	}

	parseFlags()

	if *pprofAddr != "" {
		go func() {
			log.Debugf("Starting pprof page at http://%s/debug/pprof", *pprofAddr)
			if err := http.ListenAndServe(*pprofAddr, nil); err != nil {
				log.Error(err)
			}
		}()
	}

	client.ForceChainedProxyAddr = *forceProxyAddr
	client.ForceAuthToken = *forceAuthToken

	showui = !*headless

	if showui {
		runOnSystrayReady(_main)
	} else {
		log.Debug("Running headless")
		_main()
	}
}

func _main() {
	if err := doMain(); err != nil {
		log.Error(err)
	}
	log.Debug("Lantern stopped")

	os.Exit(0)
}

func doMain() error {
	if err := logging.EnableFileLogging(); err != nil {
		return err
	}

	// Schedule cleanup actions
	handleSignals()
	addExitFunc(func() {
		if err := logging.Close(); err != nil {
			log.Debugf("Error closing log: %v", err)
		}
	})
	addExitFunc(quitSystray)

	i18nInit()
	if showui {
		if err := configureSystemTray(); err != nil {
			return err
		}
	}

	// Run below in separate goroutine as config.Init() can potentially block when Lantern runs
	// for the first time. User can still quit Lantern through systray menu when it happens.
	go func() {
		if *proxyAll {
			// If proxyall flag was supplied, force proxying of all
			settings.SetProxyAll(true)
		}

		listenAddr := *addr
		if listenAddr == "" {
			listenAddr = "127.0.0.1:8787"
		}

		err := flashlight.Run(
			listenAddr,
			"127.0.0.1:8788",
			*configdir,
			*stickyConfig,
			settings.GetProxyAll,
			flagsAsMap(),
			beforeStart,
			afterStart,
			onConfigUpdate,
			settings,
			exit)
		if err != nil {
			exit(err)
			return
		}
	}()

	return waitForExit()
}

func beforeStart(cfg *config.Config) bool {
	log.Debug("Got first config")
	if *help {
		flag.Usage()
		exit(fmt.Errorf("Wrong arguments"))
		return false
	}

	if cfg.CpuProfile != "" || cfg.MemProfile != "" {
		log.Debugf("Start profiling with cpu file %s and mem file %s", cfg.CpuProfile, cfg.MemProfile)
		finishProfiling := profiling.Start(cfg.CpuProfile, cfg.MemProfile)
		addExitFunc(finishProfiling)
	}

	if err := setUpPacTool(); err != nil {
		exit(err)
	}

	if *clearProxySettings {
		// This is a workaround that attempts to fix a Windows-only problem where
		// Lantern was unable to clean the system's proxy settings before logging
		// off.
		//
		// See: https://github.com/getlantern/lantern/issues/2776
		log.Debug("Clearing proxy settings")
		doPACOff(fmt.Sprintf("http://%s/proxy_on.pac", *uiaddr))
		exit(nil)
	}

	bootstrap, err := config.ReadBootstrapSettings()
	var startupURL string
	if err != nil {
		log.Errorf("Could not read settings? %v", err)
		startupURL = ""
	} else {
		startupURL = bootstrap.StartupUrl
	}

	log.Debugf("Starting client UI at %v", *uiaddr)
	actualUIAddr, err := ui.Start(*uiaddr, !showui, startupURL)
	if err != nil {
		// This very likely means Lantern is already running on our port. Tell
		// it to open a browser. This is useful, for example, when the user
		// clicks the Lantern desktop shortcut when Lantern is already running.
		err2 := showExistingUI(*uiaddr)
		if err2 != nil {
			exit(fmt.Errorf("Unable to start UI: %s", err))
		} else {
			log.Debug("Lantern already running, showing existing UI")
			exit(nil)
		}
		return false
	}
	client.UIAddr = actualUIAddr

	// Only run analytics once on startup.
	if settings.IsAutoReport() {
		stopAnalytics := analytics.Start(cfg, flashlight.Version)
		addExitFunc(stopAnalytics)
	}
	watchDirectAddrs()

	return true
}

func afterStart(cfg *config.Config) {
	onConfigUpdate(cfg)
	ServePACFile()
	if settings.GetSystemProxy() {
		pacOn()
	}

	addExitFunc(pacOff)
	if showui && !*startup {
		// Launch a browser window with Lantern but only after the pac
		// URL and the proxy server are all up and running to avoid
		// race conditions where we change the proxy setup while the
		// UI server and proxy server are still coming up.
		ui.Show()
	} else {
		log.Debugf("Not opening browser. Startup is: %v", *startup)
	}
}

func onConfigUpdate(cfg *config.Config) {
	autoupdate.Configure(cfg)
}

func i18nInit() {
	i18n.SetMessagesFunc(func(filename string) ([]byte, error) {
		return ui.Translations.Get(filename)
	})
	if err := i18n.UseOSLocale(); err != nil {
		log.Debugf("i18n.UseOSLocale: %q", err)
	}
}

func parseFlags() {
	args := os.Args[1:]
	// On OS X, the first time that the program is run after download it is
	// quarantined.  OS X will ask the user whether or not it's okay to run the
	// program.  If the user says that it's okay, OS X will run the program but
	// pass an extra flag like -psn_0_1122578.  flag.Parse() fails if it sees
	// any flags that haven't been declared, so we remove the extra flag.
	if len(os.Args) == 2 && strings.HasPrefix(os.Args[1], "-psn") {
		log.Debugf("Ignoring extra flag %v", os.Args[1])
		args = []string{}
	}
	// Note - we can ignore the returned error because CommandLine.Parse() will
	// exit if it fails.
	_ = flag.CommandLine.Parse(args)
}

// showExistingUi triggers an existing Lantern running on the same system to
// open a browser to the Lantern start page.
func showExistingUI(addr string) error {
	url := "http://" + addr + "/startup"
	log.Debugf("Hitting local URL: %v", url)
	resp, err := http.Get(url)
	if err != nil {
		log.Debugf("Could not hit local lantern")
		if resp.Body != nil {
			if err = resp.Body.Close(); err != nil {
				log.Debugf("Error closing body! %s", err)
			}
		}
		return err
	} else if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Unexpected response from existing Lantern: %d", resp.StatusCode)
	} else {
		return nil
	}
}

// addExitFunc adds a function to be called before the application exits.
func addExitFunc(exitFunc func()) {
	chExitFuncs <- exitFunc
}

// exit tells the application to exit, optionally supplying an error that caused
// the exit.
func exit(err error) {
	defer func() { exitCh <- err }()
	for {
		select {
		case f := <-chExitFuncs:
			log.Debugf("Calling exit func")
			f()
		default:
			log.Debugf("No exit func remaining, exit now")
			return
		}
	}
}

// Handle system signals for clean exit
func handleSignals() {
	c := make(chan os.Signal, 1)
	signal.Notify(c,
		syscall.SIGHUP,
		syscall.SIGINT,
		syscall.SIGTERM,
		syscall.SIGQUIT)
	go func() {
		s := <-c
		log.Debugf("Got signal \"%s\", exiting...", s)
		exit(nil)
	}()
}

// WaitForExit waits for a request to exit the application.
func waitForExit() error {
	return <-exitCh
}
