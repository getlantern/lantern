// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"fmt"
	"math/rand"
	"net"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/i18n"
	"github.com/getlantern/profiling"

	"github.com/getlantern/flashlight/analytics"
	"github.com/getlantern/flashlight/autoupdate"
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
	"github.com/getlantern/flashlight/util"

	"github.com/mitchellh/panicwrap"
)

var (
	version      string
	revisionDate string // The revision date and time that is associated with the version string.
	buildDate    string // The actual date and time the binary was built.

	cfgMutex sync.Mutex

	log = golog.LoggerFor("flashlight")

	// Command-line Flags
	help               = flag.Bool("help", false, "Get usage help")
	headless           = flag.Bool("headless", false, "if true, lantern will run with no ui")
	startup            = flag.Bool("startup", false, "if true, Lantern was automatically run on system startup")
	clearProxySettings = flag.Bool("clear-proxy-settings", false, "if true, Lantern removes proxy settings from the system.")

	showui = true

	configUpdates = make(chan *config.Config)
	exitCh        = make(chan error, 1)

	// use buffered channel to avoid blocking the caller of 'addExitFunc'
	// the number 10 is arbitrary
	chExitFuncs = make(chan func(), 10)
)

func init() {

	if packageVersion != defaultPackageVersion {
		// packageVersion has precedence over GIT revision. This will happen when
		// packing a version intended for release.
		version = packageVersion
	}

	if version == "" {
		version = "development"
	}

	if revisionDate == "" {
		revisionDate = "now"
	}

	// Passing public key and version to the autoupdate service.
	autoupdate.PublicKey = []byte(packagePublicKey)
	autoupdate.Version = packageVersion

	rand.Seed(time.Now().UnixNano())
}

func logPanic(msg string) {
	cfg, err := config.Init(packageVersion)
	if err != nil {
		panic("Error initializing config")
	}
	if err := logging.Init(); err != nil {
		panic("Error initializing logging")
	}

	<-logging.Configure("", "", cfg.InstanceId, version, revisionDate)

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

	if err := logging.Close(); err != nil {
		log.Debugf("Error closing log: %v", err)
	}
	os.Exit(0)
}

func doMain() error {
	if err := logging.Init(); err != nil {
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
	displayVersion()

	parseFlags()

	// Run below in separate goroutine as config.Init() can potentially block when Lantern runs
	// for the first time. User can still quit Lantern through systray menu when it happens.
	go func() {
		cfg, err := config.Init(packageVersion)
		if err != nil {
			exit(fmt.Errorf("Unable to initialize configuration: %v", err))
			return
		}
		go func() {
			err := config.Run(func(updated *config.Config) {
				configUpdates <- updated
			})
			if err != nil {
				exit(err)
			}
		}()
		log.Debugf("Processed config")
		if *help || cfg.Addr == "" || (cfg.Role != "server" && cfg.Role != "client") {
			flag.Usage()
			exit(fmt.Errorf("Wrong arguments"))
		}

		finishProfiling := profiling.Start(cfg.CpuProfile, cfg.MemProfile)
		defer finishProfiling()

		// Configure stats initially
		if err := statreporter.Configure(cfg.Stats); err != nil {
			exit(err)
		}

		log.Debug("Running proxy")
		if cfg.IsDownstream() {
			// This will open a proxy on the address and port given by -addr
			go runClientProxy(cfg)
		} else {
			go runServerProxy(cfg)
		}
	}()

	return waitForExit()
}

func i18nInit() {
	i18n.SetMessagesFunc(func(filename string) ([]byte, error) {
		return ui.Translations.Get(filename)
	})
	if err := i18n.UseOSLocale(); err != nil {
		log.Debugf("i18n.UseOSLocale: %q", err)
	}
}

func displayVersion() {
	log.Debugf("---- flashlight version: %s, release: %s, build revision date: %s ----", version, packageVersion, revisionDate)
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

// runClientProxy runs the client-side (get mode) proxy.
func runClientProxy(cfg *config.Config) {
	// Set Lantern as system proxy by creating and using a PAC file.
	setProxyAddr(cfg.Addr)

	if err := setUpPacTool(); err != nil {
		exit(err)
	}

	if *clearProxySettings {
		// This is a workaround that attempts to fix a Windows-only problem where
		// Lantern was unable to clean the system's proxy settings before logging
		// off.
		//
		// See: https://github.com/getlantern/lantern/issues/2776
		doPACOff(fmt.Sprintf("http://%s/proxy_on.pac", cfg.UIAddr))
		exit(nil)
	}

	// Start user interface.
	tcpAddr, err := net.ResolveTCPAddr("tcp4", cfg.UIAddr)
	if err != nil {
		exit(fmt.Errorf("Unable to resolve UI address: %v", err))
	}

	settings, err := config.ReadSettings()
	var startupUrl string
	if err != nil {
		log.Errorf("Could not read settings? %v", err)
		startupUrl = ""
	} else {
		startupUrl = settings.StartupUrl
	}
	if err = ui.Start(tcpAddr, !showui, startupUrl); err != nil {
		// This very likely means Lantern is already running on our port. Tell
		// it to open a browser. This is useful, for example, when the user
		// clicks the Lantern desktop shortcut when Lantern is already running.
		showExistingUi(cfg.UIAddr)
		exit(fmt.Errorf("Unable to start UI: %s", err))
		return
	}

	// Create the client-side proxy.
	client := &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	applyClientConfig(client, cfg)

	// Only run analytics once on startup. It subscribes to IP discovery
	// events from geolookup, so it needs to be subscribed here before
	// the geolookup code executes.
	analytics.Configure(cfg, version)
	geolookup.Start()

	// Continually poll for config updates and update client accordingly
	go func() {
		for {
			cfg := <-configUpdates
			applyClientConfig(client, cfg)
		}
	}()

	/*
		      Temporarily disabling localdiscover. See:
		      https://github.com/getlantern/lantern/issues/2813
		      // Continually search for local Lantern instances and update the UI
		      go func() {
			addExitFunc(localdiscovery.Stop)
			localdiscovery.Start(!showui, strconv.Itoa(tcpAddr.Port))
		      }()
	*/

	// watchDirectAddrs will spawn a goroutine that will add any site that is
	// directly accesible to the PAC file.
	watchDirectAddrs()

	err = client.ListenAndServe(func() {
		pacOn()
		addExitFunc(pacOff)

		// We finally tell the config package to start polling for new configurations.
		// This is the final step because the config polling itself uses the full
		// proxying capabilities of Lantern, so it needs everything to be properly
		// set up with at least an initial bootstrap config (on first run) to
		// complete successfully.
		config.StartPolling()
		if showui && !*startup {
			// Launch a browser window with Lantern but only after the pac
			// URL and the proxy server are all up and running to avoid
			// race conditions where we change the proxy setup while the
			// UI server and proxy server are still coming up.
			ui.Show()
		} else {
			log.Debugf("Not opening browser. Startup is: %v", *startup)
		}
	})
	if err != nil {
		exit(fmt.Errorf("Error calling listen and serve: %v", err))
	}
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

// addExitFunc adds a function to be called before the application exits.
func addExitFunc(exitFunc func()) {
	chExitFuncs <- exitFunc
}

func applyClientConfig(client *client.Client, cfg *config.Config) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	certs, err := cfg.GetTrustedCACerts()
	if err != nil {
		log.Errorf("Unable to get trusted ca certs, not configure fronted: %s", err)
	} else {
		fronted.Configure(certs, cfg.Client.MasqueradeSets)
	}

	autoupdate.Configure(cfg)
	logging.Configure(cfg.Addr, cfg.CloudConfigCA, cfg.InstanceId,
		version, revisionDate)
	settings.Configure(cfg, version, revisionDate, buildDate)
	proxiedsites.Configure(cfg.ProxiedSites)
	log.Debugf("Proxy all traffic or not: %v", cfg.Client.ProxyAll)
	ServeProxyAllPacFile(cfg.Client.ProxyAll)
	// Note - we deliberately ignore the error from statreporter.Configure here
	_ = statreporter.Configure(cfg.Stats)

	// Update client configuration and get the highest QOS dialer available.
	client.Configure(cfg.Client)

	// We offload this onto a go routine because creating the http clients
	// blocks on waiting for the local server, and the local server starts
	// later on this same thread, so it would otherwise creating a deadlock.
	go func() {
		withHttpClient(cfg.Addr, statserver.Configure)
	}()

}

func withHttpClient(addr string, withClient func(client *http.Client)) {
	if httpClient, err := util.HTTPClient("", addr); err != nil {
		log.Errorf("Could not create HTTP client via %s: %s", addr, err)
	} else {
		withClient(httpClient)
	}
}

// Runs the server-side proxy
func runServerProxy(cfg *config.Config) {
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
			if err := statreporter.Configure(cfg.Stats); err != nil {
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
	})
	if err != nil {
		log.Fatalf("Unable to run server proxy: %s", err)
	}
}

func useAllCores() {
	numcores := runtime.NumCPU()
	log.Debugf("Using all %d cores on machine", numcores)
	runtime.GOMAXPROCS(numcores)
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
