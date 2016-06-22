package app

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"path/filepath"
	"reflect"
	"strings"
	"sync"

	"code.google.com/p/go-uuid/uuid"

	"github.com/getlantern/appdir"
	"github.com/getlantern/launcher"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/ui"
)

// SettingName is the name of a setting.
type SettingName string

const (
	SNAutoReport  SettingName = "autoReport"
	SNAutoLaunch  SettingName = "autoLaunch"
	SNProxyAll    SettingName = "proxyAll"
	SNSystemProxy SettingName = "systemProxy"

	SNLanguage SettingName = "language"

	SNDeviceID  SettingName = "deviceID"
	SNUserID    SettingName = "userID"
	SNUserToken SettingName = "userToken"

	SNVersion      SettingName = "version"
	SNBuildDate    SettingName = "buildDate"
	SNRevisionDate SettingName = "revisionDate"
)

type settingType byte

const (
	stBool settingType = iota
	stNumber
	stString
)

const (
	messageType = `settings`
)

var settingMeta = map[SettingName]struct {
	sType     settingType
	persist   bool
	omitempty bool
}{
	SNAutoReport:  {stBool, true, false},
	SNAutoLaunch:  {stBool, true, false},
	SNProxyAll:    {stBool, true, false},
	SNSystemProxy: {stBool, true, false},

	SNLanguage: {stString, true, true},

	// SNDeviceID: intentionally omit, to avoid setting it from UI
	SNUserID:    {stNumber, true, true},
	SNUserToken: {stString, true, true},

	SNVersion:      {stString, false, false},
	SNBuildDate:    {stString, false, false},
	SNRevisionDate: {stString, false, false},
}

var (
	service    *ui.Service
	httpClient *http.Client
	path       = filepath.Join(appdir.General("Lantern"), "settings.yaml")
	once       = &sync.Once{}
)

// Settings is a struct of all settings unique to this particular Lantern instance.
type Settings struct {
	muNotifiers     sync.RWMutex
	changeNotifiers map[SettingName]func(interface{})

	m            map[SettingName]interface{}
	sync.RWMutex `json:"-" yaml:"-"`
}

func loadSettings(version, revisionDate, buildDate string) *Settings {
	return loadSettingsFrom(version, revisionDate, buildDate, path)
}

// loadSettings loads the initial settings at startup, either from disk or using defaults.
func loadSettingsFrom(version, revisionDate, buildDate, path string) *Settings {
	log.Debug("Loading settings")
	// Create default settings that may or may not be overridden from an existing file
	// on disk.
	sett := newSettings()
	set := sett.m

	// Use settings from disk if they're available.
	if bytes, err := ioutil.ReadFile(path); err != nil {
		log.Debugf("Could not read file %v", err)
	} else if err := yaml.Unmarshal(bytes, set); err != nil {
		log.Errorf("Could not load yaml %v", err)
		// Just keep going with the original settings not from disk.
	} else {
		log.Debugf("Loaded settings from %v", path)
	}

	// We always just set the device ID to the MAC address on the system. Note
	// this ignores what's on disk, if anything.
	set[SNDeviceID] = base64.StdEncoding.EncodeToString(uuid.NodeID())

	if sett.IsAutoLaunch() {
		launcher.CreateLaunchFile(true)
	}
	// always override below 3 attributes as they are not meant to be persisted across versions
	set[SNVersion] = version
	set[SNBuildDate] = buildDate
	set[SNRevisionDate] = revisionDate

	// Only configure the UI once. This will typically be the case in the normal
	// application flow, but tests might call Load twice, for example, which we
	// want to allow.
	once.Do(func() {
		err := sett.start()
		if err != nil {
			log.Errorf("Unable to register settings service: %q", err)
			return
		}
		go sett.read(service.In, service.Out)
	})
	return sett
}

func newSettings() *Settings {
	return &Settings{
		m: map[SettingName]interface{}{
			SNUserID:      int64(0),
			SNAutoReport:  true,
			SNAutoLaunch:  true,
			SNProxyAll:    false,
			SNSystemProxy: true,
			SNLanguage:    "",
			SNUserToken:   "",
		},
		changeNotifiers: make(map[SettingName]func(interface{})),
	}
}

// start the settings service that synchronizes Lantern's configuration with every UI client
func (s *Settings) start() error {
	var err error

	ui.PreferProxiedUI(s.GetSystemProxy())
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending Lantern settings to new client")
		uiMap := s.uiMap()
		return write(uiMap)
	}
	service, err = ui.Register(messageType, helloFn)
	return err
}

func (s *Settings) read(in <-chan interface{}, out chan<- interface{}) {
	log.Debugf("Start reading settings messages!!")
	for message := range in {
		log.Debugf("Read settings message %v", message)

		data, ok := (message).(map[string]interface{})
		if !ok {
			continue
		}

		for k, v := range data {
			name := SettingName(k)
			t, exists := settingMeta[name]
			if !exists {
				log.Errorf("Unknown settings name %s", k)
				continue
			}
			switch t.sType {
			case stBool:
				s.checkBool(name, v)
			case stString:
				s.checkString(name, v)
			case stNumber:
				s.checkNum(name, v)
			}
		}

		out <- s
	}
}

func (s *Settings) checkBool(name SettingName, v interface{}) {
	b, ok := v.(bool)
	if !ok {
		log.Errorf("Could not convert %s(%v) to bool", name, v)
		return
	}
	s.setVal(name, b)
}

func (s *Settings) checkNum(name SettingName, v interface{}) {
	number, ok := v.(json.Number)
	if !ok {
		log.Errorf("Could not convert %v of type %v", name, reflect.TypeOf(v))
		return
	}
	bigint, err := number.Int64()
	if err != nil {
		log.Errorf("Could not get int64 value for %v with error %v", name, err)
		return
	}
	s.setVal(name, bigint)
}

func (s *Settings) checkString(name SettingName, v interface{}) {
	str, ok := v.(string)
	if !ok {
		log.Errorf("Could not convert %s(%v) to string", name, v)
		return
	}
	s.setVal(name, str)
}

// Save saves settings to disk.
func (s *Settings) save() {
	log.Trace("Saving settings")
	toBeSaved := s.mapToSave()
	if bytes, err := yaml.Marshal(toBeSaved); err != nil {
		log.Errorf("Could not create yaml from settings %v", err)
	} else if err := ioutil.WriteFile(path, bytes, 0644); err != nil {
		log.Errorf("Could not write settings file %v", err)
	} else {
		log.Tracef("Saved settings to %s with contents %v", path, string(bytes))
	}
}

func (s *Settings) mapToSave() map[string]interface{} {
	m := make(map[string]interface{})
	s.RLock()
	defer s.RUnlock()
	for k, v := range s.m {
		if settingMeta[k].persist {
			key := strings.ToLower(string(k))
			m[key] = v
		}
	}
	return m
}

// uiMap makes a copy of our map for the UI with support for omitting empty
// values.
func (s *Settings) uiMap() map[string]interface{} {
	m := make(map[string]interface{})
	s.RLock()
	defer s.RUnlock()
	for key, v := range s.m {
		meta := settingMeta[key]
		k := string(key)
		// This mimics https://golang.org/pkg/encoding/json/ for what are considered
		// empty values.
		if !meta.omitempty {
			m[k] = v
		} else {
			if v == nil {
				continue
			}
			switch meta.sType {
			case stBool:
				if v.(bool) {
					m[k] = v
				}
			case stString:
				if v != "" {
					m[k] = v
				}
			case stNumber:
				if v != 0 {
					m[k] = v
				}
			}
		}
	}
	return m
}

// GetProxyAll returns whether or not to proxy all traffic.
func (s *Settings) GetProxyAll() bool {
	return s.getBool(SNProxyAll)
}

// SetProxyAll sets whether or not to proxy all traffic.
func (s *Settings) SetProxyAll(proxyAll bool) {
	s.setVal(SNProxyAll, proxyAll)
	// Cycle the PAC file so that browser picks up changes
	cyclePAC()
}

// IsAutoReport returns whether or not to auto-report debugging and analytics data.
func (s *Settings) IsAutoReport() bool {
	return s.getBool(SNAutoReport)
}

// SetAutoReport sets whether or not to auto-report debugging and analytics data.
func (s *Settings) SetAutoReport(auto bool) {
	s.setVal(SNAutoReport, auto)
}

// SetAutoLaunch sets whether or not to auto-launch Lantern on system startup.
func (s *Settings) SetAutoLaunch(auto bool) {
	s.setVal(SNAutoLaunch, auto)
	go launcher.CreateLaunchFile(auto)
}

// IsAutoLaunch returns whether or not to auto-report debugging and analytics data.
func (s *Settings) IsAutoLaunch() bool {
	return s.getBool(SNAutoLaunch)
}

// SetLanguage sets the user language
func (s *Settings) SetLanguage(language string) {
	s.setVal(SNLanguage, language)
}

// GetLanguage returns the user language
func (s *Settings) GetLanguage() string {
	return s.getString(SNLanguage)
}

// SetDeviceID sets the device ID
func (s *Settings) SetDeviceID(deviceID string) {
	// Cannot set the device ID.
}

// GetDeviceID returns the unique ID of this device.
func (s *Settings) GetDeviceID() string {
	return s.getString(SNDeviceID)
}

// SetToken sets the user token
func (s *Settings) SetToken(token string) {
	s.setVal(SNUserToken, token)
}

// GetToken returns the user token
func (s *Settings) GetToken() string {
	return s.getString(SNUserToken)
}

// SetUserID sets the user ID
func (s *Settings) SetUserID(id int64) {
	s.setVal(SNUserID, id)
}

// GetUserID returns the user ID
func (s *Settings) GetUserID() int64 {
	return s.getInt64(SNUserID)
}

// GetSystemProxy returns whether or not to set system proxy when lantern starts
func (s *Settings) GetSystemProxy() bool {
	return s.getBool(SNSystemProxy)
}

// SetSystemProxy sets whether or not to set system proxy when lantern starts
func (s *Settings) SetSystemProxy(enable bool) {
	changed := enable != s.GetSystemProxy()
	s.setVal(SNSystemProxy, enable)
	if changed {
		if enable {
			pacOn()
		} else {
			pacOff()
		}
		preferredUIAddr, addrChanged := ui.PreferProxiedUI(enable)
		if !enable && addrChanged {
			log.Debugf("System proxying disabled, redirect UI to: %v", preferredUIAddr)
			service.Out <- map[string]string{"redirectTo": preferredUIAddr}
		}
	}
}

func (s *Settings) getBool(name SettingName) bool {
	if val, err := s.getVal(name); err == nil {
		return val.(bool)
	}
	return false
}

func (s *Settings) getString(name SettingName) string {
	if val, err := s.getVal(name); err == nil {
		return val.(string)
	}
	return ""
}

func (s *Settings) getInt64(name SettingName) int64 {
	if val, err := s.getVal(name); err == nil {
		return val.(int64)
	}
	return int64(0)
}

func (s *Settings) getVal(name SettingName) (interface{}, error) {
	s.RLock()
	defer s.RUnlock()
	if val, ok := s.m[name]; ok {
		return val, nil
	}
	log.Errorf("Could not get value for %s", name)
	return nil, fmt.Errorf("No value for %v", name)
}

func (s *Settings) setVal(name SettingName, val interface{}) {
	log.Debugf("Setting %v to %v in %v", name, val, s.m)
	s.Lock()
	s.m[name] = val
	// Need to unlock here because s.save() will lock again.
	s.Unlock()
	s.save()
	s.onChange(name, val)
}

// OnChange sets a callback cb to get called when attr is changed from UI.
func (s *Settings) OnChange(attr SettingName, cb func(interface{})) {
	s.muNotifiers.Lock()
	s.changeNotifiers[attr] = cb
	s.muNotifiers.Unlock()
}

// onChange is called when attr is changed from UI
func (s *Settings) onChange(attr SettingName, value interface{}) {
	s.muNotifiers.RLock()
	fn := s.changeNotifiers[attr]
	s.muNotifiers.RUnlock()
	if fn != nil {
		fn(value)
	}
}
