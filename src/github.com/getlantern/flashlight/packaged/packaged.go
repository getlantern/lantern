// Package packaged provided access to configuration embedded directly in Lantern installation
// packages. On OSX, that means data embedded in the Lantern.app app bundle in
// Lantern.app/Contents/Resources/.lantern.yaml, while on Windows that means data embedded
// in AppData/Roaming/Lantern/.lantern.yaml. This allows customization embedded in the
// installer outside of the auto-updated binary that should only be used under special
// circumstances.
package packaged

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"runtime"

	"github.com/getlantern/appdir"
	"github.com/getlantern/golog"
	"github.com/getlantern/yaml"
)

var (
	log  = golog.LoggerFor("flashlight.packaged")
	name = ".packaged-lantern.yaml"
	url  = ""

	// This is the local copy of our embedded configuration file. This is necessary
	// to ensure we remember the embedded configuration across auto-updated
	// binaries. We write to the local file system instead of to the package
	// itself (app bundle on OSX, install directory on Windows) because
	// we're not always sure we can write to that directory.
	local = appdir.General("Lantern") + "/" + name
)

// PackagedSettings provided access to configuration embedded in the package.
type PackagedSettings struct {
	StartupUrl string
}

// ReadSettings reads packaged settings from pre-determined paths
// on the various OSes.
func ReadSettings() (string, *PackagedSettings, error) {
	yamlPath, err := packagedSettingsPath()
	if err != nil {
		return "", &PackagedSettings{}, err
	}

	path, ps, er := readSettingsFromFile(yamlPath)
	if er != nil {
		return readSettingsFromFile(local)
	}
	return path, ps, nil
}

// ReadSettingsFromFile reads PackagedSettings from the yaml file at the specified
// path.
func readSettingsFromFile(yamlPath string) (string, *PackagedSettings, error) {
	if url != "" {
		log.Debugf("Startup URL is hard-coded to: %v", url)
		ps := &PackagedSettings{StartupUrl: url}

		// If there is an embedded URL, it's a temporary workaround for this issue:
		// https://github.com/getlantern/lantern/issues/2857
		// As such, we need to store it to disk so that subsequent binaries that
		// are auto-updated will get the new version.
		path, err := writeToDisk(ps)
		if err == nil {
			return path, ps, nil
		}
		return path, nil, err
	}
	log.Debugf("Opening file at: %v", yamlPath)
	file, err := os.Open(yamlPath)
	if err != nil {
		log.Debugf("Error opening file %v", err)
		// This typically means the file doesn't exist. If that's
		// the case, and we're hard coded here to open a URL, we need
		// to write the yaml file so future auto-updated versions will
		// also have the URL we're trying to open.
		//writeUrlToFile()
		return "", &PackagedSettings{}, err
	}
	data := make([]byte, 2000)
	count, err := file.Read(data)
	if err != nil {
		log.Errorf("Error reading file %v", err)
		return "", &PackagedSettings{}, err
	}
	log.Debugf("read %d bytes: %q\n", count, data[:count])
	var s PackagedSettings
	err = yaml.Unmarshal(data[:count], &s)

	if err != nil {
		log.Errorf("Could not read yaml: %v", err)
		return "", &PackagedSettings{}, err
	}
	return yamlPath, &s, nil
}

func packagedSettingsPath() (string, error) {
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		log.Errorf("Could not get current directory %v", err)
		return "", err
	}
	log.Debugf("Opening externalUrl from: %v", dir)
	var yamldir string
	if runtime.GOOS == "windows" {
		yamldir = dir
	} else if runtime.GOOS == "darwin" {
		// Code signing doesn't like this file in the current directory
		// for whatever reason, so we grab it from the Resources
		// directory in the app bundle.
		yamldir = dir + "/../Resources"
	} else if runtime.GOOS == "linux" {
		yamldir = dir
	}
	yamlPath := yamldir + "/" + name
	return yamlPath, nil
}

func writeToDisk(ps *PackagedSettings) (string, error) {
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
