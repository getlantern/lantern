// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"fmt"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/dogenzaka/rotator"
	"github.com/getlantern/appdir"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/i18n"
	"github.com/getlantern/profiling"
	"github.com/getlantern/systray"
	"github.com/getlantern/wfilter"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
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

	LogTimestampFormat = "Jan 02 15:04:05.000"
)

var (
	log       = golog.LoggerFor("flashlight")
	version   string
	buildDate string

	// Command-line Flags
	help      = flag.Bool("help", false, "Get usage help")
	parentPID = flag.Int("parentpid", 0, "the parent process's PID, used on Windows for killing flashlight when the parent disappears")

	configUpdates = make(chan *config.Config)
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

func main() {
	systray.Run(doMain)
}

func doMain() {
	i18nInit()
	logfile := configureLogging()
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
	if version == "" {
		version = "development"
	}
	if buildDate == "" {
		buildDate = "now"
	}
	log.Debugf("---- flashlight version %s (%s) ----", version, buildDate)
}

func configureStats(cfg *config.Config, failOnError bool) {
	err := statreporter.Configure(cfg.Stats)
	if err != nil {
		log.Error(err)
		if failOnError {
			flag.Usage()
			os.Exit(ConfigError)
		}
	}

	if cfg.StatsAddr != "" {
		statserver.Start(cfg.StatsAddr)
	} else {
		statserver.Stop()
	}
}

// Runs the client-side proxy
func runClientProxy(cfg *config.Config) {
	client := &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	// Configure client initially
	client.Configure(cfg.Client)

	// Start UI server
	if cfg.UIAddr != "" {
		err := ui.Start(cfg.UIAddr)
		if err != nil {
			panic(fmt.Errorf("Unable to start UI: %v", err))
		}
		ui.Show()
	}

	// intitial proxied sites configuration
	proxiedsites.Configure(cfg.ProxiedSites)

	// Continually poll for config updates and update client accordingly
	go func() {
		for {
			cfg := <-configUpdates

			proxiedsites.Configure(cfg.ProxiedSites)
			configureStats(cfg, false)
			client.Configure(cfg.Client)
		}
	}()

	err := client.ListenAndServe()
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

func configureLogging() *rotator.SizeRotator {
	logdir := appdir.Logs("Lantern")
	log.Debugf("Placing logs in %v", logdir)
	if _, err := os.Stat(logdir); err != nil {
		if os.IsNotExist(err) {
			// Create log dir
			if err := os.MkdirAll(logdir, 0755); err != nil {
				log.Fatalf("Unable to create logdir at %s: %s", logdir, err)
			}
		}
	}
	file := rotator.NewSizeRotator(filepath.Join(logdir, "lantern.log"))
	// Set log files to 1 MB
	file.RotationSize = 1 * 1024 * 1024
	// Keep up to 20 log files
	file.MaxRotation = 20
	errorOut := timestamped(io.MultiWriter(os.Stderr, file))
	debugOut := timestamped(io.MultiWriter(os.Stdout, file))
	golog.SetOutputs(errorOut, debugOut)
	return file
}

// timestamped adds a timestamp to the beginning of log lines
func timestamped(orig io.Writer) io.Writer {
	return wfilter.LinePrepender(orig, func(w io.Writer) (int, error) {
		return fmt.Fprintf(w, "%s - ", time.Now().In(time.UTC).Format(LogTimestampFormat))
	})
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
				os.Exit(0)
			}
		}
	}()
}
