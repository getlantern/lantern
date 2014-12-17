// flashlight is a lightweight chained proxy that can run in client or server mode.
package main

import (
	"compress/gzip"
	"flag"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"runtime/pprof"
	"strconv"
	"strings"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/log"
	"github.com/getlantern/flashlight/server"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/go-igdman/igdman"
)

const (
	// Exit Statuses
	ConfigError    = 1
	Interrupted    = 2
	PortmapFailure = 50
)

const (
	ETAG          = "ETag"
	IF_NONE_MATCH = "If-None-Match"
)

var (
	version   string
	buildDate string

	CLOUD_CONFIG_POLL_INTERVAL = 1 * time.Minute

	// Command-line Flags
	help      = flag.Bool("help", false, "Get usage help")
	parentPID = flag.Int("parentpid", 0, "the parent process's PID, used on Windows for killing flashlight when the parent disappears")

	configUpdates = make(chan *config.Config)

	lastCloudConfigETag = ""
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

func main() {
	displayVersion()

	cfg := configure()

	if cfg.CpuProfile != "" {
		startCPUProfiling(cfg.CpuProfile)
		defer stopCPUProfiling(cfg.CpuProfile)
	}

	if cfg.MemProfile != "" {
		defer saveMemProfile(cfg.MemProfile)
	}

	saveProfilingOnSigINT(cfg)

	configureStats(cfg)

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

// configure parses the command-line flags and binds the configuration YAML.
// If there's a problem with the provided flags, it prints usage to stdout and
// exits with status 1.
func configure() *config.Config {
	flag.Parse()
	var err error
	cfg, err := config.LoadFromDisk()
	if err != nil {
		log.Debugf("Error loading config, using default: %s", err)
	}
	cfg = cfg.ApplyFlags()
	if *help || cfg.Addr == "" || (cfg.Role != "server" && cfg.Role != "client") {
		flag.Usage()
		os.Exit(ConfigError)
	}

	err = cfg.SaveToDisk()
	if err != nil {
		log.Fatalf("Unable to save config: %s", err)
	}

	go fetchConfigUpdates(cfg)

	return cfg
}

func fetchConfigUpdates(cfg *config.Config) {
	nextCloud := nextCloudPoll()
	for {
		cloudDelta := nextCloud.Sub(time.Now())
		var err error
		var updated *config.Config
		select {
		case <-time.After(1 * time.Second):
			if cfg.HasChangedOnDisk() {
				updated, err = config.LoadFromDisk()
			}
		case <-time.After(cloudDelta):
			if cfg.CloudConfig != "" {
				updated, err = fetchCloudConfig(cfg)
				if updated == nil && err == nil {
					log.Debugf("Configuration unchanged in cloud at: %s", cfg.CloudConfig)
				}
			}
			nextCloud = nextCloudPoll()
		}
		if err != nil {
			log.Errorf("Error fetching config updates: %s", err)
		} else if updated != nil {
			cfg = updated
			configUpdates <- updated
		}
	}
}

func nextCloudPoll() time.Time {
	sleepTime := (CLOUD_CONFIG_POLL_INTERVAL.Nanoseconds() / 2) + rand.Int63n(CLOUD_CONFIG_POLL_INTERVAL.Nanoseconds())
	return time.Now().Add(time.Duration(sleepTime))
}

func fetchCloudConfig(cfg *config.Config) (*config.Config, error) {
	log.Debugf("Fetching cloud config from: %s", cfg.CloudConfig)
	// Try it unproxied first
	bytes, err := doFetchCloudConfig(cfg, "")
	if err != nil && cfg.IsDownstream() {
		// If that failed, try it proxied
		bytes, err = doFetchCloudConfig(cfg, cfg.Addr)
	}
	if err != nil {
		return nil, fmt.Errorf("Unable to read yaml from %s: %s", cfg.CloudConfig, err)
	}
	if bytes == nil {
		return nil, nil
	}
	log.Debugf("Merging cloud configuration")
	return cfg.UpdatedFrom(bytes)
}

func doFetchCloudConfig(cfg *config.Config, proxyAddr string) ([]byte, error) {
	client, err := util.HTTPClient(cfg.CloudConfigCA, proxyAddr)
	if err != nil {
		return nil, fmt.Errorf("Unable to initialize HTTP client: %s", err)
	}
	log.Debugf("Checking for cloud configuration at: %s", cfg.CloudConfig)
	req, err := http.NewRequest("GET", cfg.CloudConfig, nil)
	if err != nil {
		return nil, fmt.Errorf("Unable to construct request for cloud config at %s: %s", cfg.CloudConfig, err)
	}
	if lastCloudConfigETag != "" {
		// Don't bother fetching if unchanged
		req.Header.Set(IF_NONE_MATCH, lastCloudConfigETag)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Unable to fetch cloud config at %s: %s", cfg.CloudConfig, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == 304 {
		return nil, nil
	} else if resp.StatusCode != 200 {
		return nil, fmt.Errorf("Unexpected response status: %d", resp.StatusCode)
	}
	lastCloudConfigETag = resp.Header.Get(ETAG)
	gzReader, err := gzip.NewReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Unable to open gzip reader: %s", err)
	}
	return ioutil.ReadAll(gzReader)
}

func configureStats(cfg *config.Config) {
	if cfg.StatsPeriod > 0 {
		if cfg.StatshubAddr == "" {
			log.Error("Must specify StatshubAddr if reporting stats")
			flag.Usage()
			os.Exit(ConfigError)
		}
		if cfg.InstanceId == "" {
			log.Error("Must specify InstanceId if reporting stats")
			flag.Usage()
			os.Exit(ConfigError)
		}
		if cfg.Country == "" {
			log.Error("Must specify Country if reporting stats")
			flag.Usage()
			os.Exit(ConfigError)
		}
		log.Debugf("Reporting stats to %s every %s under instance id '%s' in country %s", cfg.StatshubAddr, cfg.StatsPeriod, cfg.InstanceId, cfg.Country)
		go statreporter.Start(cfg.StatsPeriod, cfg.StatshubAddr, cfg.InstanceId, cfg.Country)
	} else {
		log.Debug("Not reporting stats (no statsperiod specified)")
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
	client.Configure(cfg.Client, nil)
	// Continually poll for config updates and update client accordingly
	go func() {
		for {
			cfg := <-configUpdates
			client.Configure(cfg.Client, nil)
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

	if cfg.Portmap > 0 {
		log.Debugf("Attempting to map external port %d", cfg.Portmap)
		err := mapPort(cfg)
		if err != nil {
			log.Errorf("Unable to map external port: %s", err)
			os.Exit(PortmapFailure)
		}
		log.Debugf("Mapped external port %d", cfg.Portmap)
	}

	srv := &server.Server{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
		Host:         cfg.AdvertisedHost,
		CertContext: &server.CertContext{
			PKFile:         config.InConfigDir("proxypk.pem"),
			ServerCertFile: config.InConfigDir("servercert.pem"),
		},
	}
	if cfg.StatsAddr != "" {
		// Serve stats
		srv.StatServer = &statserver.Server{
			Addr: cfg.StatsAddr,
		}
	}
	err := srv.ListenAndServe()
	if err != nil {
		log.Fatalf("Unable to run server proxy: %s", err)
	}
}

func mapPort(cfg *config.Config) error {
	parts := strings.Split(cfg.Addr, ":")

	internalPort, err := strconv.Atoi(parts[1])
	if err != nil {
		return fmt.Errorf("Unable to parse local port: ")
	}

	internalIP := parts[0]
	if internalIP == "" {
		internalIP, err = determineInternalIP()
		if err != nil {
			return fmt.Errorf("Unable to determine internal IP: %s", err)
		}
	}

	igd, err := igdman.NewIGD()
	if err != nil {
		return fmt.Errorf("Unable to get IGD: %s", err)
	}

	igd.RemovePortMapping(igdman.TCP, cfg.Portmap)
	err = igd.AddPortMapping(igdman.TCP, internalIP, internalPort, cfg.Portmap, 0)
	if err != nil {
		return fmt.Errorf("Unable to map port with igdman %d: %s", cfg.Portmap, err)
	}

	return nil
}

func determineInternalIP() (string, error) {
	conn, err := net.Dial("tcp", "s3.amazonaws.com:443")
	if err != nil {
		return "", fmt.Errorf("Unable to determine local IP: %s", err)
	}
	defer conn.Close()
	return strings.Split(conn.LocalAddr().String(), ":")[0], nil
}

func useAllCores() {
	numcores := runtime.NumCPU()
	log.Debugf("Using all %d cores on machine", numcores)
	runtime.GOMAXPROCS(numcores)
}

func startCPUProfiling(filename string) {
	f, err := os.Create(filename)
	if err != nil {
		log.Fatal(err)
	}
	pprof.StartCPUProfile(f)
	log.Debugf("Process will save cpu profile to %s after terminating", filename)
}

func stopCPUProfiling(filename string) {
	log.Debugf("Saving CPU profile to: %s", filename)
	pprof.StopCPUProfile()
}

func saveMemProfile(filename string) {
	f, err := os.Create(filename)
	if err != nil {
		log.Errorf("Unable to create file to save memprofile: %s", err)
		return
	}
	log.Debugf("Saving heap profile to: %s", filename)
	pprof.WriteHeapProfile(f)
	f.Close()
}

func saveProfilingOnSigINT(cfg *config.Config) {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		<-c
		if cfg.CpuProfile != "" {
			stopCPUProfiling(cfg.CpuProfile)
		}
		if cfg.MemProfile != "" {
			saveMemProfile(cfg.MemProfile)
		}
		os.Exit(Interrupted)
	}()
}
