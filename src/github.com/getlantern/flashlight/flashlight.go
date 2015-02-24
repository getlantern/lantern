// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"fmt"
	"math/rand"
	"os"
	"runtime"
	"time"

	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/i18n"
	"github.com/getlantern/profiling"
	"github.com/getlantern/systray"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/proxiedsites"
	"github.com/getlantern/flashlight/server"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
	"github.com/getlantern/flashlight/ui"
)

const (
	// Exit Statuses
	ConfigError    = 1
	PortmapFailure = 50
)

var (
	version   string
	buildDate string
	log       = golog.LoggerFor("flashlight")

	// Command-line Flags
	help      = flag.Bool("help", false, "Get usage help")
	parentPID = flag.Int("parentpid", 0, "the parent process's PID, used on Windows for killing flashlight when the parent disappears")

	configUpdates = make(chan *config.Config)
)

func init() {
	if version == "" {
		version = "development"
	}
	if buildDate == "" {
		buildDate = "now"
	}

	rand.Seed(time.Now().UnixNano())
}

func main() {
	systray.Run(doMain)
}

func doMain() {
	i18nInit()

	logfile := logging.Setup(version, buildDate)
	defer logfile.Close()

	configureSystemTray()
	displayVersion()

	flag.Parse()
	configUpdates = make(chan *config.Config)
	cfg, err := config.Start(func(updated *config.Config) {
		configUpdates <- updated
	})
	if err != nil {
		log.Fatalf("Unable to start configuration: %s", err)
	}
	if *help || cfg.Addr == "" || (cfg.Role != "server" && cfg.Role != "client") {
		flag.Usage()
		os.Exit(ConfigError)
	}

	finishProfiling := profiling.Start(cfg.CpuProfile, cfg.MemProfile)
	defer finishProfiling()

	// Configure stats initially
	configureStats(cfg, true)

	log.Debugf("Running proxy")
	if cfg.IsDownstream() {
		runClientProxy(cfg)
	} else {
		runServerProxy(cfg)
	}
}

func i18nInit() {
	i18n.SetMessagesFunc(func(filename string) ([]byte, error) {
		return ui.Translations.Get(filename)
	})
	err := i18n.UseOSLocale()
	if err != nil {
		panic(err)
	}
}

func displayVersion() {
	log.Debugf("---- flashlight version %s (%s) ----", version, buildDate)
}

func configureStats(cfg *config.Config, failOnError bool) {
	var err error

	// Configuring statreporter
	err = statreporter.Configure(cfg.Stats)
	if err != nil {
		log.Error(err)
		if failOnError {
			flag.Usage()
			os.Exit(ConfigError)
		}
	}
}

// Runs the client-side proxy
func runClientProxy(cfg *config.Config) {
	client := &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	hqfd := client.Configure(cfg.Client)

	if cfg.UIAddr != "" {
		err := ui.Start(cfg.UIAddr)
		if err != nil {
			panic(fmt.Errorf("Unable to start UI: %v", err))
		}
		ui.Show()
	}

	go logging.Configure(cfg)
	proxiedsites.Configure(cfg.ProxiedSites)

	if hqfd == nil {
		log.Errorf("No fronted dialer available, not enabling geolocation or stats")
	} else {
		hqfdc := hqfd.DirectHttpClient()
		geolookup.Configure(hqfdc)
		statserver.Configure(hqfdc)
	}

	// Continually poll for config updates and update client accordingly
	go func() {
		for {
			cfg := <-configUpdates

			proxiedsites.Configure(cfg.ProxiedSites)
			configureStats(cfg, false)
			hqfd = client.Configure(cfg.Client)
			if hqfd != nil {
				hqfdc := hqfd.DirectHttpClient()
				geolookup.Configure(hqfdc)
				statserver.Configure(hqfdc)
				logging.Configure(cfg)
			}
		}
	}()

	err := client.ListenAndServe(pacOn)
	if err != nil {
		log.Fatalf("Unable to run client proxy: %s", err)
	}
}

// Runs the server-side proxy
func runServerProxy(cfg *config.Config) {
	useAllCores()

	srv := &server.Server{
		Addr:         cfg.Addr,
		Host:         cfg.Server.AdvertisedHost,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
		CertContext: &fronted.CertContext{
			PKFile:         config.InConfigDir("proxypk.pem"),
			ServerCertFile: config.InConfigDir("servercert.pem"),
		},
		AllowedPorts: []int{80, 443, 8080, 8443, 5222},
	}

	srv.Configure(cfg.Server)

	// Continually poll for config updates and update server accordingly
	go func() {
		for {
			cfg := <-configUpdates
			configureStats(cfg, false)
			srv.Configure(cfg.Server)
		}
	}()

	err := srv.ListenAndServe()
	if err != nil {
		log.Fatalf("Unable to run server proxy: %s", err)
	}
}

func useAllCores() {
	numcores := runtime.NumCPU()
	log.Debugf("Using all %d cores on machine", numcores)
	runtime.GOMAXPROCS(numcores)
}

func configureSystemTray() {
	icon, err := Asset("icons/16on.ico")
	if err != nil {
		log.Fatalf("Unable to load icon for system tray: %v", err)
	}
	systray.SetIcon(icon)
	systray.SetTooltip("Lantern")
	show := systray.AddMenuItem(i18n.T("TRAY_SHOW_LANTERN"), i18n.T("SHOW"))
	quit := systray.AddMenuItem(i18n.T("TRAY_QUIT"), i18n.T("QUIT"))
	go func() {
		for {
			select {
			case <-show.ClickedCh:
				ui.Show()
			case <-quit.ClickedCh:
				pacOff()
				os.Exit(0)
			}
		}
	}()
}
