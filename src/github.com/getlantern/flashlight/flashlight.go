// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"flag"
	"math/rand"
	"os"
	"runtime"
	"time"

	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/profiling"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/server"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
)

const (
	// Exit Statuses
	ConfigError    = 1
	PortmapFailure = 50
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

	// Continually poll for config updates and update client accordingly
	go func() {
		for {
			cfg := <-configUpdates
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
