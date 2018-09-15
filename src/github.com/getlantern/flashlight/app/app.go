// Package app implements the desktop application functionality of flashlight
package app

import (
	"fmt"
	"math/rand"
	"net/http"
	"time"

	"github.com/getlantern/flashlight"
	"github.com/getlantern/golog"
	"github.com/getlantern/profiling"

	"github.com/getlantern/flashlight/analytics"
	"github.com/getlantern/flashlight/autoupdate"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/proxiedsites"
	"github.com/getlantern/flashlight/ui"
)

var (
	log      = golog.LoggerFor("flashlight")
	settings *Settings
)

func init() {
	// Passing public key and version to the autoupdate service.
	autoupdate.PublicKey = []byte(packagePublicKey)
	autoupdate.Version = flashlight.PackageVersion

	rand.Seed(time.Now().UnixNano())

	settings = loadSettings(flashlight.Version, flashlight.RevisionDate, flashlight.BuildDate)
}

// App is the core of the Lantern desktop application, in the form of a library.
type App struct {
	ShowUI      bool
	Flags       map[string]interface{}
	exitCh      chan error
	chExitFuncs chan func()
}

// Init initializes the App's state
func (app *App) Init() {
	app.exitCh = make(chan error, 1)
	// use buffered channel to avoid blocking the caller of 'AddExitFunc'
	// the number 10 is arbitrary
	app.chExitFuncs = make(chan func(), 10)
}

// LogPanicAndExit logs a panic and then exits the application.
func (app *App) LogPanicAndExit(msg string) {
	if err := logging.EnableFileLogging(); err != nil {
		panic("Error initializing logging")
	}

	<-logging.Configure("", "dummy-device-id-for-panic", flashlight.Version, flashlight.RevisionDate, 0, 0, 0)

	log.Error(msg)

	logging.Flush()
	_ = logging.Close()

	app.Exit(nil)
}

// Run starts the app. It will block until the app exits.
func (app *App) Run() error {
	// Run below in separate goroutine as config.Init() can potentially block when Lantern runs
	// for the first time. User can still quit Lantern through systray menu when it happens.
	go func() {
		log.Debug(app.Flags)
		if app.Flags["proxyall"].(bool) {
			// If proxyall flag was supplied, force proxying of all
			settings.SetProxyAll(true)
		}

		listenAddr := app.Flags["addr"].(string)
		if listenAddr == "" {
			listenAddr = "127.0.0.1:8787"
		}

		err := flashlight.Run(
			listenAddr,
			"127.0.0.1:8788",
			app.Flags["configdir"].(string),
			app.Flags["stickyconfig"].(bool),
			settings.GetProxyAll,
			app.Flags,
			app.beforeStart,
			app.afterStart,
			app.onConfigUpdate,
			settings,
			app.Exit,
			settings.GetDeviceID())
		if err != nil {
			app.Exit(err)
			return
		}
	}()

	return app.waitForExit()
}

func (app *App) beforeStart() bool {
	log.Debug("Got first config")
	var cpuProf, memProf string
	if cpu, cok := app.Flags["cpuprofile"]; cok {
		cpuProf = cpu.(string)
	}
	if mem, cok := app.Flags["memprofile"]; cok {
		memProf = mem.(string)
	}
	if cpuProf != "" || memProf != "" {
		log.Debugf("Start profiling with cpu file %s and mem file %s", cpuProf, memProf)
		finishProfiling := profiling.Start(cpuProf, memProf)
		app.AddExitFunc(finishProfiling)
	}

	if err := setUpPacTool(); err != nil {
		app.Exit(err)
	}

	if app.Flags["clear-proxy-settings"].(bool) {
		// This is a workaround that attempts to fix a Windows-only problem where
		// Lantern was unable to clean the system's proxy settings before logging
		// off.
		//
		// See: https://github.com/getlantern/lantern/issues/2776
		log.Debug("Clearing proxy settings")
		doPACOff(fmt.Sprintf("http://%s/proxy_on.pac", app.uiaddr()))
		app.Exit(nil)
	}

	bootstrap, err := config.ReadBootstrapSettings()
	var startupURL string
	if err != nil {
		log.Errorf("Could not read settings? %v", err)
		startupURL = ""
	} else {
		startupURL = bootstrap.StartupUrl
	}

	log.Debugf("Starting client UI at %v", app.uiaddr())
	actualUIAddr, err := ui.Start(app.uiaddr(), !app.ShowUI, startupURL)
	if err != nil {
		// This very likely means Lantern is already running on our port. Tell
		// it to open a browser. This is useful, for example, when the user
		// clicks the Lantern desktop shortcut when Lantern is already running.
		err2 := app.showExistingUI(app.uiaddr())
		if err2 != nil {
			app.Exit(fmt.Errorf("Unable to start UI: %s", err))
		} else {
			log.Debug("Lantern already running, showing existing UI")
			app.Exit(nil)
		}
		return false
	}
	client.UIAddr = actualUIAddr

	err = serveBandwidth()
	if err != nil {
		log.Errorf("Unable to serve bandwidth to UI: %v", err)
	}

	// Only run analytics once on startup.
	if settings.IsAutoReport() {
		stopAnalytics := analytics.Start(settings.GetDeviceID(), flashlight.Version)
		app.AddExitFunc(stopAnalytics)
	}
	watchDirectAddrs()

	return true
}

func (app *App) afterStart() {
	servePACFile()
	if settings.GetSystemProxy() {
		pacOn()
	}

	app.AddExitFunc(pacOff)
	if app.ShowUI && !app.Flags["startup"].(bool) {
		// Launch a browser window with Lantern but only after the pac
		// URL and the proxy server are all up and running to avoid
		// race conditions where we change the proxy setup while the
		// UI server and proxy server are still coming up.
		ui.Show()
	} else {
		log.Debugf("Not opening browser. Startup is: %v", app.Flags["startup"])
	}
}

func (app *App) onConfigUpdate(cfg *config.Global) {
	proxiedsites.Configure(cfg.ProxiedSites)
	autoupdate.Configure(cfg.UpdateServerURL, cfg.AutoUpdateCA)
}

// showExistingUi triggers an existing Lantern running on the same system to
// open a browser to the Lantern start page.
func (app *App) showExistingUI(addr string) error {
	url := "http://" + addr + "/startup"
	log.Debugf("Hitting local URL: %v", url)
	resp, err := http.Get(url)
	if err != nil {
		log.Debugf("Could not hit local lantern: %s", err)
		return err
	}
	if resp.Body != nil {
		if err = resp.Body.Close(); err != nil {
			log.Debugf("Error closing body! %s", err)
		}
	}
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Unexpected response from existing Lantern: %d", resp.StatusCode)
	}
	return nil
}

// AddExitFunc adds a function to be called before the application exits.
func (app *App) AddExitFunc(exitFunc func()) {
	app.chExitFuncs <- exitFunc
}

// Exit tells the application to exit, optionally supplying an error that caused
// the exit.
func (app *App) Exit(err error) {
	defer func() { app.exitCh <- err }()
	for {
		select {
		case f := <-app.chExitFuncs:
			log.Debugf("Calling exit func")
			f()
		default:
			log.Debugf("No exit func remaining, exit now")
			return
		}
	}
}

// WaitForExit waits for a request to exit the application.
func (app *App) waitForExit() error {
	return <-app.exitCh
}

func (app *App) uiaddr() string {
	return app.Flags["uiaddr"].(string)
}
