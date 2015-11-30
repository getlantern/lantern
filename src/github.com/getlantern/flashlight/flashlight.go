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

	"github.com/getlantern/flashlight/autoupdate"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/lantern"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/settings"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/golog"
	"github.com/getlantern/profiling"

	"github.com/mitchellh/panicwrap"
)

var (
	version      string
	revisionDate string // The revision date and time that is associated with the version string.
	buildDate    string // The actual date and time the binary was built.

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

	if lantern.PackageVersion != lantern.DefaultPackageVersion {
		// packageVersion has precedence over GIT revision. This will happen when
		// packing a version intended for release.
		version = lantern.PackageVersion
	}

	if version == "" {
		version = "development"
	}

	if revisionDate == "" {
		revisionDate = "now"
	}

	// Passing public key and version to the autoupdate service.
	autoupdate.PublicKey = []byte(lantern.PackagePublicKey)
	autoupdate.Version = lantern.PackageVersion

	rand.Seed(time.Now().UnixNano())

	settings.Load(version, revisionDate, buildDate)
}

func logPanic(msg string) {
	_, err := config.Init(lantern.PackageVersion)
	if err != nil {
		panic("Error initializing config")
	}
	if err := logging.Init(); err != nil {
		panic("Error initializing logging")
	}

	<-logging.Configure("", "", settings.GetInstanceID(), version, revisionDate)

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
			lantern.Exit(nil)
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
		lantern.RunOnSystrayReady(_main)
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

	lantern.Stop()
	os.Exit(0)
}

func doMain() error {
	// Run below in separate goroutine as config.Init() can potentially block when Lantern runs
	// for the first time. User can still quit Lantern through systray menu when it happens.
	go func() {
		isAndroid := runtime.GOOS == "android"
		cfgFn := func(cfg *config.Config) {
			if *help || cfg.Addr == "" || (cfg.Role != "server" && cfg.Role != "client") {
				flag.Usage()
				lantern.Exit(fmt.Errorf("Wrong arguments"))
			}

			if cfg.CpuProfile != "" || cfg.MemProfile != "" {
				log.Debugf("Start profiling with cpu file %s and mem file %s", cfg.CpuProfile, cfg.MemProfile)
				finishProfiling := profiling.Start(cfg.CpuProfile, cfg.MemProfile)
				lantern.AddExitFunc(finishProfiling)
			}
			// Configure stats initially
			if err := statreporter.Configure(cfg.Stats, settings.GetInstanceID()); err != nil {
				lantern.Exit(err)
			}
		}
		lantern.Start(showui, isAndroid, *clearProxySettings,
			*startup, cfgFn)
	}()

	return lantern.WaitForExit()
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
