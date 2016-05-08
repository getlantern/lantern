package config

import (
	"errors"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/getlantern/appdir"
	"github.com/getlantern/errlog"
	"github.com/getlantern/tarfs"
	"github.com/getlantern/yaml"
	"github.com/getlantern/yamlconf"
)

var (
	name            = ".packaged-lantern.yaml"
	lanternYamlName = "lantern.yaml"

	// This is the local copy of our embedded ration file. This is necessary
	// to ensure we remember the embedded ration across auto-updated
	// binaries. We write to the local file system instead of to the package
	// itself (app bundle on OSX, install directory on Windows) because
	// we're not always sure we can write to that directory.
	local = appdir.General("Lantern") + "/" + name
)

// BootstrapSettings provides access to configuration embedded directly in Lantern installation
// packages. On OSX, that means data embedded in the Lantern.app app bundle in
// Lantern.app/Contents/Resources/.lantern.yaml, while on Windows that means data embedded
// in AppData/Roaming/Lantern/.lantern.yaml. This allows customization embedded in the
// installer outside of the auto-updated binary that should only be used under special
// circumstances.
type BootstrapSettings struct {
	StartupUrl string
}

// ReadBootstrapSettings reads packaged settings from pre-determined paths
// on the various OSes.
func ReadBootstrapSettings() (*BootstrapSettings, error) {
	_, yamlPath, err := bootstrapPath(name)
	if err != nil {
		return &BootstrapSettings{}, err
	}

	ps, er := readSettingsFromFile(yamlPath)
	if er != nil {
		return readSettingsFromFile(local)
	}
	return ps, nil
}

// ReadSettingsFromFile reads BootstrapSettings from the yaml file at the specified
// path.
func readSettingsFromFile(yamlPath string) (*BootstrapSettings, error) {
	log.Debugf("Opening file at: %v", yamlPath)
	data, err := ioutil.ReadFile(yamlPath)
	if err != nil {
		// This will happen whenever there's no packaged settings, which is often
		log.Debugf("Error reading file %v", err)
		return &BootstrapSettings{}, err
	}

	trimmed := strings.TrimSpace(string(data))

	log.Debugf("Read bytes: %v", trimmed)

	if trimmed == "" {
		log.Debugf("Ignoring empty string")
		return &BootstrapSettings{}, errors.New("Empty string")
	}
	var s BootstrapSettings
	err = yaml.Unmarshal([]byte(trimmed), &s)

	if err != nil {
		elog.Log(err, errlog.WithOp("read-bootstrap-settings"))
		return &BootstrapSettings{}, err
	}
	return &s, nil
}

// MakeInitialConfig returns a default configuration
func MakeInitialConfig() (yamlconf.Config, error) {
	dir, _, err := bootstrapPath(lanternYamlName)
	if err != nil {
		elog.Log(err, errlog.WithOp("get-bootstrap-path"))
		return nil, err
	}

	// We need to use tarfs here because the lantern.yaml needs to embedded
	// in the binary for auto-updates to work. We also want the flexibility,
	// however, to embed it in installers to change various settings.
	fs, err := tarfs.New(Resources, dir)
	if err != nil {
		elog.Log(err, errlog.WithOp("read-tarfs"))
		return nil, err
	}

	// Get the yaml file from either the local file system or from an
	// embedded resource, but ignore local file system files if they're
	// empty.
	bytes, err := fs.GetIgnoreLocalEmpty("lantern.yaml")
	if err != nil {
		elog.Log(err, errlog.WithOp("read-bootstrap-file"))
		return nil, err
	}
	cfg := &Config{}
	err = yaml.Unmarshal(bytes, cfg)
	if err != nil {
		elog.Log(err, errlog.WithOp("parse-yaml"))
		return nil, err
	}
	return cfg, nil
}

func bootstrapPath(fileName string) (string, string, error) {
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		elog.Log(err, errlog.WithOp("get-cwd"))
		return "", "", err
	}
	var yamldir string
	if runtime.GOOS == "windows" {
		yamldir = dir
	} else if runtime.GOOS == "darwin" {
		// Code signing doesn't like this file in the current directory
		// for whatever reason, so we grab it from the Resources/en.lproj
		// directory in the app bundle. See:
		// https://developer.apple.com/library/mac/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919-CH1-TNTAG402
		yamldir = dir + "/../Resources/en.lproj"
		if _, err := ioutil.ReadDir(yamldir); err != nil {
			// This likely means the user originally installed with an older version that didn't include en.lproj
			// in the app bundle, so just look in the old location in Resources.
			yamldir = dir + "/../Resources"
		}
	} else if runtime.GOOS == "linux" {
		yamldir = dir + "/../"
	}
	fullPath := filepath.Join(yamldir, fileName)
	log.Debugf("Opening bootstrap file from: %v", fullPath)
	return yamldir, fullPath, nil
}
