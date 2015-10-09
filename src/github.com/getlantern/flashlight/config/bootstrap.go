package config

import (
	"errors"
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/getlantern/appdir"
	"github.com/getlantern/tarfs"
	"github.com/getlantern/yaml"
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

// ReadSettings reads packaged settings from pre-determined paths
// on the various OSes.
func ReadSettings() (*BootstrapSettings, error) {
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
		log.Errorf("Could not read yaml: %v", err)
		return &BootstrapSettings{}, err
	}
	return &s, nil
}

// MakeInitialConfig save baked-in config to the file specified by configPath
func MakeInitialConfig(configPath string) error {
	dir, _, err := bootstrapPath(lanternYamlName)
	if err != nil {
		log.Errorf("Could not get bootstrap path %v", err)
		return err
	}

	// We need to use tarfs here because the lantern.yaml needs to embedded
	// in the binary for auto-updates to work. We also want the flexibility,
	// however, to embed it in installers to change various settings.
	fs, err := tarfs.New(Resources, dir)
	if err != nil {
		log.Errorf("Could not read resources? %v", err)
		return err
	}

	// Get the yaml file from either the local file system or from an
	// embedded resource, but ignore local file system files if they're
	// empty.
	bytes, err := fs.GetIgnoreLocalEmpty("lantern.yaml")
	if err != nil {
		log.Errorf("Could not read bootstrap file %v", err)
		return err
	}
	err = ioutil.WriteFile(configPath, bytes, 0644)
	if err != nil {
		log.Errorf("Could not write bootstrap file %v", err)
		return err
	}
	return nil
}

func bootstrapPath(fileName string) (string, string, error) {
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		log.Errorf("Could not get current directory %v", err)
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

func writeToDisk(ps *BootstrapSettings) (string, error) {
	data, err := yaml.Marshal(ps)
	if err != nil {
		log.Errorf("Could not write to disk: %v", err)
		return "", err
	}
	err = ioutil.WriteFile(local, data, 0644)
	if err != nil {
		log.Errorf("Could not write to disk: %v", err)
		return "", err
	}
	return local, nil
}
