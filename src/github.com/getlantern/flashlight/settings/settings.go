// Package settings loads user-specific settings and exchanges them with the UI.
package settings

import (
	"io/ioutil"
	"net/http"
	"path/filepath"
	"runtime"
	"sync"

	"code.google.com/p/go-uuid/uuid"

	"github.com/getlantern/appdir"
	"github.com/getlantern/launcher"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
)

const (
	messageType = `Settings`
)

var (
	log        = golog.LoggerFor("flashlight.settings")
	service    *ui.Service
	settings   *Settings
	httpClient *http.Client
	yamlName   = "settings.yaml"
	path       = filepath.Join(appdir.General("Lantern"), yamlName)
	once       = &sync.Once{}
)

// Settings is a struct of all settings unique to this particular Lantern instance.
type Settings struct {
	Version      string
	BuildDate    string
	RevisionDate string
	AutoReport   bool
	AutoLaunch   bool
	ProxyAll     bool
	InstanceID   string

	HttpAddr  string
	SocksAddr string

	sync.RWMutex
}

func SetAndroidPath(settingsDir string) {
	path = filepath.Join(settingsDir, yamlName)
}

// Load loads the initial settings at startup, either from disk or using defaults.
func Load(version, revisionDate, buildDate string) *Settings {

	log.Debugf("Attempting to load settings file from path: %s", path)

	// Create default settings that may or may not be overridden from an existing file
	// on disk.
	settings = &Settings{
		AutoReport: true,
		AutoLaunch: true,
		ProxyAll:   false,
		HttpAddr:   "127.0.0.1:8787",
		SocksAddr:  "127.0.0.1:9131",
		InstanceID: uuid.New(),
	}

	// Use settings from disk if they're available.
	bytes, err := ioutil.ReadFile(path)
	if err != nil {
		log.Debugf("Could not read file %v", err)
	} else {
		if err := yaml.Unmarshal(bytes, settings); err != nil {
			log.Errorf("Could not load yaml %v", err)
			// Just keep going with the original settings not from disk.
		}
	}

	// don't create an launch file on android
	if runtime.GOOS != "android" && settings.AutoLaunch {
		launcher.CreateLaunchFile(settings.AutoLaunch)
	}

	// always override below 3 attributes as they are not meant to be persisted across versions
	settings.Version = version
	settings.BuildDate = buildDate
	settings.RevisionDate = revisionDate

	// Only configure the UI once. This will typically be the case in the normal
	// application flow, but tests might call Load twice, for example, which we
	// want to allow.
	if runtime.GOOS != "android" {
		once.Do(func() {
			err := start(settings)
			if err != nil {
				log.Errorf("Unable to register settings service: %q", err)
				return
			}
			go read()
		})
	}

	return settings
}

// GetInstanceID returns the unique identifier for Lantern on this machine.
func GetInstanceID() string {
	settings.RLock()
	defer settings.RUnlock()
	return settings.InstanceID
}

// SetInstanceID sets the unique identifier for Lantern on this machine.
func SetInstanceID(id string) {
	settings.Lock()
	defer settings.Unlock()
	settings.InstanceID = id
}

// GetProxyAll returns whether or not to proxy all traffic.
func GetProxyAll() bool {
	settings.RLock()
	defer settings.RUnlock()
	return settings.ProxyAll
}

// SetProxyAll sets whether or not to proxy all traffic.
func SetProxyAll(proxyAll bool) {
	settings.Lock()
	defer settings.Unlock()
	settings.ProxyAll = proxyAll
}

// IsAutoReport returns whether or not to auto-report debugging and analytics data.
func IsAutoReport() bool {
	settings.RLock()
	defer settings.RUnlock()
	return settings.AutoReport
}

// SetAutoReport sets whether or not to auto-report debugging and analytics data.
func SetAutoReport(auto bool) {
	settings.Lock()
	defer settings.Unlock()
	settings.AutoReport = auto
}

// SetAutoLaunch sets whether or not to auto-launch Lantern on system startup.
func SetAutoLaunch(auto bool) {
	settings.Lock()
	defer settings.Unlock()
	settings.AutoLaunch = auto
	go launcher.CreateLaunchFile(auto)
}

// start the settings service that synchronizes Lantern's configuration with every UI client
func start(baseSettings *Settings) error {
	var err error

	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending Lantern settings to new client")
		settings.Lock()
		defer settings.Unlock()
		return write(baseSettings)
	}
	service, err = ui.Register(messageType, nil, helloFn)
	return err
}

func read() {
	log.Tracef("Reading settings messages!!")
	for message := range service.In {
		log.Tracef("Read settings message!! %q", message)
		msg := (message).(map[string]interface{})

		if autoReport, ok := msg["autoReport"].(bool); ok {
			SetAutoReport(autoReport)
		} else if proxyAll, ok := msg["proxyAll"].(bool); ok {
			SetProxyAll(proxyAll)
		} else if autoLaunch, ok := msg["autoLaunch"].(bool); ok {
			SetAutoLaunch(autoLaunch)
		}
	}
}

// Saves settings to disk.
func Save() {
	settings.Lock()
	defer settings.Unlock()
	if bytes, err := yaml.Marshal(settings); err != nil {
		log.Errorf("Could not create yaml from settings %v", err)
	} else if err := ioutil.WriteFile(path, bytes, 0644); err != nil {
		log.Errorf("Could not write settings file %v", err)
	}
}
