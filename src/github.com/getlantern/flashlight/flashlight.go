// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"fmt"
	"math/rand"
	"os"
	"runtime"
	"strings"
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
	"github.com/getlantern/flashlight/settings"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
	"github.com/getlantern/flashlight/ui"
)

var (
	version   string
	buildDate string
	log       = golog.LoggerFor("flashlight")

	// Command-line Flags
	help      = flag.Bool("help", false, "Get usage help")
	parentPID = flag.Int("parentpid", 0, "the parent process's PID, used on Windows for killing flashlight when the parent disappears")
	headless  = flag.Bool("headless", false, "if true, lantern will run with no ui")

	configUpdates = make(chan *config.Config)
	exitCh        = make(chan error, 1)

	showui = true
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
	flag.Parse()
	showui = !*headless

	if showui {
		systray.Run(_main)
	} else {
		log.Debug("Running headless")
		_main()
	}
}

func _main() {
	err := doMain()
	if err != nil {
		log.Fatal(err)
	}
	log.Debug("Lantern stopped")
	os.Exit(0)
}

func doMain() error {
	err := logging.Init()
	if err != nil {
		return err
	}

	// Schedule cleanup actions
	defer logging.Close()
	defer pacOff()
	defer systray.Quit()

	i18nInit()
	if showui {
		err = configureSystemTray()
		if err != nil {
			return err
		}
	}
	displayVersion()

	parseFlags()
	configUpdates = make(chan *config.Config)
	cfg, err := config.Init()
	if err != nil {
		return fmt.Errorf("Unable to initialize configuration: %v", err)
	}
	go func() {
		err := config.Run(func(updated *config.Config) {
			configUpdates <- updated
		})
		if err != nil {
			exit(err)
		}
	}()
	if *help || cfg.Addr == "" || (cfg.Role != "server" && cfg.Role != "client") {
		flag.Usage()
		return fmt.Errorf("Wrong arguments")
	}

	finishProfiling := profiling.Start(cfg.CpuProfile, cfg.MemProfile)
	defer finishProfiling()

	// Configure stats initially
	err = statreporter.Configure(cfg.Stats)
	if err != nil {
		return err
	}

	log.Debug("Running proxy")
	if cfg.IsDownstream() {
		runClientProxy(cfg)
	} else {
		runServerProxy(cfg)
	}

	return waitForExit()
}

func i18nInit() {
	i18n.SetMessagesFunc(func(filename string) ([]byte, error) {
		return ui.Translations.Get(filename)
	})
	err := i18n.UseOSLocale()
	if err != nil {
		exit(err)
	}
}

func displayVersion() {
	log.Debugf("---- flashlight version %s (%s) ----", version, buildDate)
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
	flag.CommandLine.Parse(args)
}

// Runs the client-side proxy
func runClientProxy(cfg *config.Config) {
	err := setUpPacTool()
	if err != nil {
		exit(err)
	}
	client := &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	hqfd := client.Configure(cfg.Client)

	if cfg.UIAddr != "" {
		err := ui.Start(cfg.UIAddr)
		if err != nil {
			exit(fmt.Errorf("Unable to start UI: %v", err))
			return
		}
		if showui {
			ui.Show()
		}
	}

	logging.Configure(cfg, version, buildDate)
	settings.Configure(version, buildDate)
	proxiedsites.Configure(cfg.ProxiedSites, cfg.Addr)

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

			proxiedsites.Configure(cfg.ProxiedSites, cfg.Addr)
			// Note - we deliberately ignore the error from statreporter.Configure here
			statreporter.Configure(cfg.Stats)
			hqfd = client.Configure(cfg.Client)
			if hqfd != nil {
				hqfdc := hqfd.DirectHttpClient()
				geolookup.Configure(hqfdc)
				statserver.Configure(hqfdc)
				logging.Configure(cfg, version, buildDate)
			}
		}
	}()

	go func() {
		exit(client.ListenAndServe(pacOn))
	}()
	log.Debug("Ran goroutine")
}

// Runs the server-side proxy
func runServerProxy(cfg *config.Config) {
	useAllCores()

	pkFile, err := config.InConfigDir("proxypk.pem")
	if err != nil {
		log.Fatal(err)
	}
	certFile, err := config.InConfigDir("servercert.pem")
	if err != nil {
		log.Fatal(err)
	}

	srv := &server.Server{
		Addr:         cfg.Addr,
		Host:         cfg.Server.AdvertisedHost,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
		CertContext: &fronted.CertContext{
			PKFile:         pkFile,
			ServerCertFile: certFile,
		},
		AllowedPorts: []int{80, 443, 8080, 8443, 5222},
	}

	srv.Configure(cfg.Server)

	// Continually poll for config updates and update server accordingly
	go func() {
		for {
			cfg := <-configUpdates
			statreporter.Configure(cfg.Stats)
			srv.Configure(cfg.Server)
		}
	}()

	err = srv.ListenAndServe()
	if err != nil {
		log.Fatalf("Unable to run server proxy: %s", err)
	}
}

func useAllCores() {
	numcores := runtime.NumCPU()
	log.Debugf("Using all %d cores on machine", numcores)
	runtime.GOMAXPROCS(numcores)
}

func configureSystemTray() error {
	icon, err := Asset("icons/16on.ico")
	if err != nil {
		return fmt.Errorf("Unable to load icon for system tray: %v", err)
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
				exit(nil)
				return
			}
		}
	}()

	return nil
}

// exit tells the application to exit, optionally supplying an error that caused
// the exit.
func exit(err error) {
	exitCh <- err
}

// WaitForExit waits for a request to exit the application.
func waitForExit() error {
	return <-exitCh
}
