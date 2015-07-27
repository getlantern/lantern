// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"fmt"
	"math/rand"
	"net"
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
)

var (
	version      string
	revisionDate string // The revision date and time that is associated with the version string.
	buildDate    string // The actual date and time the binary was built.

	cfgMutex sync.Mutex

	log = golog.LoggerFor("flashlight")

	// Command-line Flags
	help     = flag.Bool("help", false, "Get usage help")
	headless = flag.Bool("headless", false, "if true, lantern will run with no ui")
	startup  = flag.Bool("startup", false, "if true, Lantern was automatically run on system startup")

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

func main() {
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

	cfg, err := config.Init(packageVersion)
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
	if err := statreporter.Configure(cfg.Stats); err != nil {
		return err
	}

	log.Debug("Running proxy")
	if cfg.IsDownstream() {
		// This will open a proxy on the address and port given by -addr
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

	// Create the client-side proxy.
	client := &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	// Start user interface.
	if cfg.UIAddr == "" {
		exit(fmt.Errorf("Please provide a valid local or remote UI address"))
	}
	tcpAddr, err := net.ResolveTCPAddr("tcp4", cfg.UIAddr)
	if err != nil {
		exit(fmt.Errorf("Unable to resolve UI address: %v", err))
	}
	if err := ui.Start(tcpAddr, !showui); err != nil {
		exit(fmt.Errorf("Unable to start UI: %v", err))
		return
	}

	applyClientConfig(client, cfg)
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

	go func() {
		addExitFunc(pacOff)
		err := client.ListenAndServe(func() {
			pacOn()
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
			log.Errorf("Error calling listen and serve: %v", err)
		}
	}()
}

// addExitFunc adds a function to be called before the application exits.
func addExitFunc(exitFunc func()) {
	chExitFuncs <- exitFunc
}

func applyClientConfig(client *client.Client, cfg *config.Config) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	autoupdate.Configure(cfg)
	logging.Configure(cfg.Addr, cfg.CloudConfigCA, cfg.InstanceId,
		version, revisionDate)
	settings.Configure(cfg, version, revisionDate, buildDate)
	proxiedsites.Configure(cfg.ProxiedSites)
	analytics.Configure(cfg, version)
	log.Debugf("Proxy all traffic or not: %v", cfg.Client.ProxyAll)
	ServeProxyAllPacFile(cfg.Client.ProxyAll)
	// Note - we deliberately ignore the error from statreporter.Configure here
	_ = statreporter.Configure(cfg.Stats)

	// Update client configuration and get the highest QOS dialer available.
	hqfd := client.Configure(cfg.Client)
	if hqfd == nil {
		log.Errorf("No fronted dialer available, not enabling geolocation, stats or analytics")
	} else {
		// An *http.Client that uses the highest QOS dialer.
		hqfdClient := hqfd.NewDirectDomainFronter()
		config.Configure(hqfdClient)
		geolookup.Configure(hqfdClient)
		statserver.Configure(hqfdClient)
		// Note we don't call Configure on analytics here, as that would
		// result in an extra analytics call and double counting.
	}
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

	updateServerSideConfigClient(cfg)

	srv := &server.Server{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
		CertContext: &fronted.CertContext{
			PKFile:         pkFile,
			ServerCertFile: certFile,
		},
		AllowedPorts: []int{80, 443, 8080, 8443, 5222, 5223, 5228},

		// We allow all censored countries plus us, es, mx, and gb because we do work
		// and testing from those countries.
		AllowedCountries: []string{"US", "ES", "MX", "GB", "CN", "VN", "IN", "IQ", "IR", "CU", "SY", "SA", "BH", "ET", "ER", "UZ", "TM", "PK", "TR", "VE"},
	}

	srv.Configure(cfg.Server)

	// Continually poll for config updates and update server accordingly
	go func() {
		for {
			cfg := <-configUpdates
			updateServerSideConfigClient(cfg)
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

func updateServerSideConfigClient(cfg *config.Config) {
	client, err := util.HTTPClient(cfg.CloudConfigCA, "")
	if err != nil {
		log.Errorf("Couldn't create http.Client for fetching the config")
		return
	}
	config.Configure(client)
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
		<-c
		exit(nil)
	}()
}

// WaitForExit waits for a request to exit the application.
func waitForExit() error {
	return <-exitCh
}
