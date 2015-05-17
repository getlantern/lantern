// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"fmt"
	"math/rand"
	"os"
	"reflect"
	"runtime"
	"strings"
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
	"github.com/getlantern/flashlight/withclient"
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

	if packageVersion != defaultPackageVersion {
		// packageVersion has precedence over GIT revision. This will happen when
		// packing a version intended for release.
		version = packageVersion
	}

	if version == "" {
		version = "development"
	}

	if buildDate == "" {
		buildDate = "now"
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
	defer quitSystray()

	i18nInit()
	if showui {
		err = configureSystemTray()
		if err != nil {
			return err
		}
	}
	displayVersion()

	parseFlags()

	mch := withclient.NewMakerChan()

	cfg, err := config.Init(mch.MakeWithClient())
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
		// This will open a proxy on the address and port given by -addr
		runClientProxy(cfg, mch)
	} else {
		runServerProxy(cfg, mch)
	}

	return waitForExit()
}

func i18nInit() {
	i18n.SetMessagesFunc(func(filename string) ([]byte, error) {
		return ui.Translations.Get(filename)
	})
	err := i18n.UseOSLocale()
	if err != nil {
		log.Debugf("i18n.UseOSLocale: %q", err)
	}
}

func displayVersion() {
	log.Debugf("---- flashlight version: %s, release: %s, build date: %s ----", version, packageVersion, buildDate)
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

// runClientProxy runs the client-side (get mode) proxy.
func runClientProxy(cfg *config.Config, mch withclient.MakerChan) {
	var err error

	// Set Lantern as system proxy by creating and using a PAC file.
	setProxyAddr(cfg.Addr)

	if err = setUpPacTool(); err != nil {
		exit(err)
	}

	// Create the client-side proxy.
	client := &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	client.Configure(cfg.Client)

	// Start user interface.
	if cfg.UIAddr != "" {
		if err = ui.Start(cfg.UIAddr); err != nil {
			exit(fmt.Errorf("Unable to start UI: %v", err))
			return
		}
		if showui {
			// Launch a browser window with Lantern.
			ui.Show()
		}
	}

	autoupdate.Configure(cfg)
	logging.Configure(cfg, version, buildDate)
	settings.Configure(cfg, version, buildDate)
	proxiedsites.Configure(cfg.ProxiedSites)

	mch.UpdateClientDirectFronter(cfg.Client)
	wdc := mch.MakeWithClient()
	geolookup.Configure(wdc)
	statserver.Configure(wdc)
	analytics.Configure(cfg, false, wdc)

	// Continually poll for config updates and update client accordingly
	go func() {
		var cfg *config.Config
		var oldCfg *config.Config
		for {
			oldCfg = cfg
			cfg = <-configUpdates

			proxiedsites.Configure(cfg.ProxiedSites)
			// Note - we deliberately ignore the error from statreporter.Configure here
			statreporter.Configure(cfg.Stats)

			client.Configure(cfg.Client)

			// These are the only things in the config that affect the direct fronter.
			// XXX: wrt fronted servers, we only really care if the one with highest QOS
			// is still the same one.
			if oldCfg == nil || !(reflect.DeepEqual(oldCfg.Client.FrontedServers, cfg.Client.FrontedServers) && reflect.DeepEqual(oldCfg.Client.MasqueradeSets, cfg.Client.MasqueradeSets)) {
				mch.UpdateClientDirectFronter(cfg.Client)
			}
			settings.Configure(cfg, version, buildDate)
			logging.Configure(cfg, version, buildDate)
			autoupdate.Configure(cfg)
		}
	}()

	// watchDirectAddrs will spawn a goroutine that will add any site that is
	// directly accesible to the PAC file.
	watchDirectAddrs()

	go func() {
		exit(client.ListenAndServe(pacOn))
	}()
}

// Runs the server-side proxy
func runServerProxy(cfg *config.Config, mch withclient.MakerChan) {
	useAllCores()

	mch.UpdateServerConfigClient(cfg)
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
	analytics.Configure(cfg, true, nil)

	// Continually poll for config updates and update server accordingly
	go func(oldca string) {
		for {
			cfg := <-configUpdates
			if cfg.CloudConfigCA != oldca {
				mch.UpdateServerConfigClient(cfg)
				oldca = cfg.CloudConfigCA
			}
			statreporter.Configure(cfg.Stats)
			srv.Configure(cfg.Server)
		}
	}(cfg.CloudConfigCA)

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
	exitCh <- err
}

// WaitForExit waits for a request to exit the application.
func waitForExit() error {
	return <-exitCh
}
