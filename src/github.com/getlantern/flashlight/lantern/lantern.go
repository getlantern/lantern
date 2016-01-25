package lantern

import (
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/i18n"

	"github.com/getlantern/flashlight/analytics"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/pac"
	"github.com/getlantern/flashlight/server"
	"github.com/getlantern/flashlight/settings"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/ui"

	"github.com/getlantern/flashlight/autoupdate"
)

var (
	log = golog.LoggerFor("lantern")

	version      string
	revisionDate string // The revision date and time that is associated with the version string.
	buildDate    string // The actual date and time the binary was built.

	configUpdates = make(chan *config.Config)
	exitCh        = make(chan error, 1)
	doneCfg       = make(chan bool, 2)

	// use buffered channel to avoid blocking the caller of 'addExitFunc'
	// the number 10 is arbitrary
	chExitFuncs = make(chan func(), 10)
)

type Lantern struct {
	config *config.Config
	Client *client.Client
}

func init() {

	if PackageVersion != DefaultPackageVersion {
		// packageVersion has precedence over GIT revision. This will happen when
		// packing a version intended for release.
		version = PackageVersion
	}

	if version == "" {
		version = "development"
	}

	if revisionDate == "" {
		revisionDate = "now"
	}

	// Passing public key and version to the autoupdate service.
	autoupdate.PublicKey = []byte(PackagePublicKey)
	autoupdate.Version = PackageVersion

	rand.Seed(time.Now().UnixNano())

	if runtime.GOOS != "android" {
		settings.Load(version, revisionDate, buildDate)
	}
}

func GetVersion() string {
	return version
}

func GetRevisionDate() string {
	return revisionDate
}

func configureDesktop(cfg *config.Config, clearProxySettings bool, showui bool) {
	// Set Lantern as system proxy by creating and using a PAC file.
	pac.SetProxyAddr(cfg.Addr)

	if err := pac.SetUpPacTool(); err != nil {
		Exit(err)
	}

	if clearProxySettings {
		// This is a workaround that attempts to fix a Windows-only problem where
		// Lantern was unable to clean the system's proxy settings before logging
		// off.
		//
		// See: https://github.com/getlantern/lantern/issues/2776
		pac.DoPACOff(fmt.Sprintf("http://%s/proxy_on.pac", cfg.UIAddr))
		Exit(nil)
	}

	// Start user interface.
	tcpAddr, err := net.ResolveTCPAddr("tcp4", cfg.UIAddr)
	if err != nil {
		Exit(fmt.Errorf("Unable to resolve UI address: %v", err))
	}

	bootstrap, err := config.ReadBootstrapSettings()
	var startupUrl string
	if err != nil {
		log.Errorf("Could not read settings? %v", err)
		startupUrl = ""
	} else {
		startupUrl = bootstrap.StartupUrl
	}

	if err = ui.Start(tcpAddr, !showui, startupUrl); err != nil {
		// This very likely means Lantern is already running on our port. Tell
		// it to open a browser. This is useful, for example, when the user
		// clicks the Lantern desktop shortcut when Lantern is already running.
		showExistingUi(cfg.UIAddr)
		Exit(fmt.Errorf("Unable to start UI: %s", err))
		return
	}
}

// runClientProxy runs the client-side (get mode) proxy.
func (self *Lantern) RunClientProxy(cfg *config.Config, android bool, clearProxySettings bool, showui bool, startup bool) {
	if !android {
		configureDesktop(cfg, clearProxySettings, showui)
	}

	// Create the client-side proxy.
	self.Client = &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
		Version:      version,
		RevisionDate: revisionDate,
	}

	AddExitFunc(self.Client.Stop)

	self.Client.ApplyClientConfig(cfg)

	// Only run analytics once on startup. It subscribes to IP discovery
	// events from geolookup, so it needs to be subscribed here before
	// the geolookup code executes.
	AddExitFunc(analytics.Configure(cfg, version))

	geolookup.Start()

	// Continually poll for config updates and update client accordingly
	go func() {
		for {
			select {
			case cfg := <-configUpdates:
				self.Client.ApplyClientConfig(cfg)
			case <-doneCfg:
				return
			}
		}
	}()

	AddExitFunc(func() { doneCfg <- true })

	if !android {
		// watchDirectAddrs will spawn a goroutine that will add any site that is
		// directly accesible to the PAC file.
		pac.WatchDirectAddrs()
	}

	go func() {
		err := self.Client.ListenAndServe(func() {
			if !android {
				pac.PacOn()
				AddExitFunc(pac.PacOff)
			}

			// We finally tell the config package to start polling for new configurations.
			// This is the final step because the config polling itself uses the full
			// proxying capabilities of Lantern, so it needs everything to be properly
			// set up with at least an initial bootstrap config (on first run) to
			// complete successfully.
			config.StartPolling()
			if !android {
				if showui && !startup {
					// Launch a browser window with Lantern but only after the pac
					// URL and the proxy server are all up and running to avoid
					// race conditions where we change the proxy setup while the
					// UI server and proxy server are still coming up.
					ui.Show()
				} else {
					log.Debugf("Not opening browser. Startup is: %v", startup)
				}
			}
		})
		if err != nil {
			log.Errorf("Error calling listen and serve: %v", err)
			Exit(fmt.Errorf("Error calling listen and serve: %v", err))
		}
	}()
}

// Runs the server-side proxy
func RunServerProxy(cfg *config.Config) {
	useAllCores()

	_, pkFile, err := config.InConfigDir("proxypk.pem")
	if err != nil {
		log.Fatal(err)
	}
	_, certFile, err := config.InConfigDir("servercert.pem")
	if err != nil {
		log.Fatal(err)
	}

	srv := &server.Server{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
		CertContext: &fronted.CertContext{
			PKFile:         pkFile,
			ServerCertFile: certFile,
		},
		AllowedPorts: []int{80, 443, 8080, 8443, 5222, 5223, 5228},

		// We've observed high resource consumption from these countries for
		// purposes unrelated to Lantern's mission, so we disallow them.
		BannedCountries: []string{"PH"},
	}

	srv.Configure(cfg.Server)

	// Continually poll for config updates and update server accordingly
	go func() {
		for {
			cfg := <-configUpdates
			if err := statreporter.Configure(cfg.Stats, settings.GetInstanceID()); err != nil {
				log.Debugf("Error configuring statreporter: %v", err)
			}

			srv.Configure(cfg.Server)
		}
	}()

	err = srv.ListenAndServe(func(update func(*server.ServerConfig) error) {
		err := config.Update(func(cfg *config.Config) error {
			return update(cfg.Server)
		})
		if err != nil {
			log.Errorf("Error while trying to update: %v", err)
		}
	}, settings.GetInstanceID())
	if err != nil {
		log.Fatalf("Unable to run server proxy: %s", err)
	}
}

// exit tells the application to exit, optionally supplying an error that caused
// the exit.
func Exit(err error) {
	defer func() { exitCh <- err }()
	log.Errorf("Exit called with error: %v", err)
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

func Start(showui bool, android bool, clearProxySettings bool, startup bool, cfgFn func(cfgFn *config.Config)) (*Lantern, error) {

	lantern := &Lantern{}

	if !android {
		if err := logging.Init(); err != nil {
			return nil, err
		}
	}

	// Schedule cleanup actions
	handleSignals()
	AddExitFunc(func() {
		if err := logging.Close(); err != nil {
			log.Debugf("Error closing log: %v", err)
		}
	})

	if !android {
		AddExitFunc(quitSystray)
		AddExitFunc(settings.Save)
		i18nInit()

	}

	if !android && showui {
		if err := configureSystemTray(); err != nil {
			return nil, err
		}
	}

	displayVersion()

	lantern.ProcessConfig(cfgFn)

	log.Debug("Running proxy")
	if lantern.config.IsDownstream() {
		// This will open a proxy on the address and port given by -addr
		lantern.RunClientProxy(lantern.config, android,
			clearProxySettings, showui, startup)
	} else {
		RunServerProxy(lantern.config)
	}

	return lantern, nil
}

func (self *Lantern) ProcessConfig(f func(*config.Config)) *config.Config {
	// Run below in separate goroutine as config.Init() can potentially block when Lantern runs
	// for the first time. User can still quit Lantern through systray menu when it happens.
	cfg, err := config.Init(PackageVersion)
	if err != nil {
		Exit(fmt.Errorf("Unable to initialize configuration: %v", err))
		return nil
	}
	self.config = cfg

	go func() {
		AddExitFunc(config.Exit)
		err := config.Run(func(updated *config.Config) {
			configUpdates <- updated
		})
		if err != nil {
			log.Errorf("Could not apply config updates: %v", err)
			Exit(err)
		}
	}()

	log.Debugf("Processed config")
	f(cfg)
	return cfg
}

// showExistingUi triggers an existing Lantern running on the same system to
// open a browser to the Lantern start page.
func showExistingUi(tcpAddr string) {
	url := "http://" + tcpAddr + "/startup"
	log.Debugf("Hitting local URL: %v", url)
	resp, err := http.Get(url)
	if err != nil {
		log.Debugf("Could not hit local lantern")
		if err = resp.Body.Close(); err != nil {
			log.Debugf("Error closing body! %s", err)
		}
	} else {
		log.Debugf("Got response from local Lantern: %v", resp.Status)
	}
}

func displayVersion() {
	log.Debugf("---- lantern version: %s, release: %s, build revision date: %s ----", version, PackageVersion, revisionDate)
}

func Stop() {
	if err := logging.Close(); err != nil {
		log.Debugf("Error closing log: %v", err)
	}
}

func i18nInit() {
	i18n.SetMessagesFunc(func(filename string) ([]byte, error) {
		return ui.Translations.Get(filename)
	})
	if err := i18n.UseOSLocale(); err != nil {
		log.Debugf("i18n.UseOSLocale: %q", err)
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
		Exit(nil)
	}()
}

// WaitForExit waits for a request to exit the application.
func WaitForExit() error {
	return <-exitCh
}

// addExitFunc adds a function to be called before the application exits.
func AddExitFunc(exitFunc func()) {
	chExitFuncs <- exitFunc
}

func useAllCores() {
	numcores := runtime.NumCPU()
	log.Debugf("Using all %d cores on machine", numcores)
	runtime.GOMAXPROCS(numcores)
}
