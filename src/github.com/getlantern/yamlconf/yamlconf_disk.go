package yamlconf

import (
	"crypto/aes"
	"crypto/cipher"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"reflect"
	"time"

	"github.com/getlantern/yaml"
)

var (
	// Empty AES-128 key for obfuscation
	obfuscationKey = make([]byte, 16)
)

func (m *Manager) loadFromDisk() error {
	_, err := m.reloadFromDisk()
	return err
}

func (m *Manager) reloadFromDisk() (bool, error) {
	var cfg Config

	fileInfo, err := os.Stat(m.FilePath)
	if err == nil {
		if m.fileInfo == fileInfo {
			log.Trace("Config unchanged on disk")
			return false, nil
		}
	} else if m.DefaultConfig == nil || !os.IsNotExist(err) {
		return false, fmt.Errorf("Unable to stat config file %s: %s", m.FilePath, err)
	}

	cfg, err = readFromDisk(m.FilePath, m.Obfuscate, m.EmptyConfig)
	if err != nil {
		if m.DefaultConfig == nil {
			return false, err
		}
		log.Debugf("Error reading config from disk, replacing with default: %v", err)
		cfg, err = m.DefaultConfig()
	} else if m.ValidateConfig != nil {
		if m.DefaultConfig == nil {
			log.Debug("Not validating config because no DefaultConfig provided!")
		} else {
			err2 := m.ValidateConfig(cfg)
			if err2 != nil {
				log.Debugf("Config failed to validate, replacing with default: %v", err2)
			}
			cfg, err = m.DefaultConfig()
		}
	}
	if err != nil {
		return false, err
	}

	if m.cfg != nil && m.cfg.GetVersion() != cfg.GetVersion() {
		log.Trace("Version mismatch on disk, overwriting what's on disk with current version")
		if err := m.writeToDisk(m.cfg); err != nil {
			log.Errorf("Unable to write to disk: %v", err)
		}
		return false, fmt.Errorf("Version of config on disk did not match expected. Expected %d, found %d", m.cfg.GetVersion(), cfg.GetVersion())
	}

	if reflect.DeepEqual(m.cfg, cfg) {
		log.Trace("Config on disk is same as in memory, ignoring")
		return false, nil
	}

	log.Debugf("Configuration changed on disk, applying")

	m.setCfg(cfg)
	m.fileInfo = fileInfo

	return true, nil
}

func readFromDisk(filePath string, allowObfuscation bool, emptyConfig func() Config) (Config, error) {
	var cfg Config
	if allowObfuscation {
		log.Trace("Attempting to read obfuscated config")
		var err1, err2 error
		cfg, err1 = doReadFromDisk(filePath, true, emptyConfig)
		if err1 != nil {
			log.Tracef("Error reading obfuscated config from disk, try reading non-obfuscated: %v", err1)
			cfg, err2 = doReadFromDisk(filePath, false, emptyConfig)
			if err2 != nil {
				return nil, fmt.Errorf("%v / %v", err1, err2)
			}
		}
		return cfg, nil
	}

	log.Trace("Attempting to read non-obfuscated config")
	var err1, err2 error
	cfg, err1 = doReadFromDisk(filePath, false, emptyConfig)
	if err1 != nil {
		log.Tracef("Error reading non-obfuscated config from disk, try reading obfuscated: %v", err1)
		cfg, err2 = doReadFromDisk(filePath, true, emptyConfig)
		if err2 != nil {
			return nil, fmt.Errorf("%v / %v", err1, err2)
		}
	}
	return cfg, nil
}

func doReadFromDisk(filePath string, allowObfuscation bool, emptyConfig func() Config) (Config, error) {
	start := time.Now()
	infile, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("Unable to open config file %v for reading: %v", filePath, err)
	}
	defer infile.Close()

	var in io.Reader = infile
	if allowObfuscation {
		// Read file as obfuscated with AES
		stream, err2 := obfuscationStream()
		if err2 != nil {
			return nil, err2
		}
		in = &cipher.StreamReader{S: stream, R: in}
	}

	bytes, err := ioutil.ReadAll(in)
	if err != nil {
		return nil, fmt.Errorf("Error reading config from %s: %s", filePath, err)
	}

	cfg := emptyConfig()
	err = yaml.Unmarshal(bytes, cfg)
	if err != nil {
		return nil, fmt.Errorf("Error unmarshaling config yaml from %s: %s", filePath, err)
	}

	delta := time.Now().Sub(start)
	log.Debugf("*********************** Read from disk in %v", delta)
	return cfg, nil
}

func (m *Manager) saveToDiskAndUpdate(updated Config) (bool, error) {
	log.Trace("Applying defaults before saving")
	updated.ApplyDefaults()

	log.Trace("Remembering current version")
	original := m.cfg
	nextVersion := 0
	if original != nil {
		log.Trace("Copying original config in preparation for comparison")
		var err error
		original, err = m.copy(m.cfg)
		if err != nil {
			return false, fmt.Errorf("Unable to copy original config for comparison")
		}
		log.Trace("Set version to 0 prior to comparison")
		original.SetVersion(0)
		log.Trace("Incrementing version")
		nextVersion = m.cfg.GetVersion() + 1
	}

	log.Trace("Compare config without version")
	updated.SetVersion(0)
	if reflect.DeepEqual(original, updated) {
		log.Trace("Configuration unchanged, do nothing")
		return false, nil
	}

	log.Debug("Configuration changed programmatically, saving")
	log.Trace("Increment version")
	updated.SetVersion(nextVersion)

	log.Trace("Save updated")
	err := m.writeToDisk(updated)
	if err != nil {
		return false, fmt.Errorf("Unable to write to disk: %v", err)
	}

	log.Trace("Point to updated")
	m.setCfg(updated)
	return true, nil
}

func (m *Manager) writeToDisk(cfg Config) error {
	bytes, err := yaml.Marshal(cfg)
	if err != nil {
		return fmt.Errorf("Unable to marshal config yaml: %s", err)
	}

	outfile, err := os.OpenFile(m.FilePath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("Unable to open file %v for writing: %v", m.FilePath, err)
	}
	defer outfile.Close()

	var out io.Writer = outfile
	if m.Obfuscate {
		// write file as obfuscated with AES
		stream, err2 := obfuscationStream()
		if err2 != nil {
			return err2
		}
		out = &cipher.StreamWriter{S: stream, W: out}
	}
	_, err = out.Write(bytes)
	if err != nil {
		return fmt.Errorf("Unable to write config yaml to file %s: %s", m.FilePath, err)
	}
	m.fileInfo, err = os.Stat(m.FilePath)
	if err != nil {
		return fmt.Errorf("Unable to stat file %s: %s", m.FilePath, err)
	}
	return nil
}

// HasChangedOnDisk checks whether Config has changed on disk
func (m *Manager) hasChangedOnDisk() bool {
	nextFileInfo, err := os.Stat(m.fileInfo.Name())
	if err != nil {
		return false
	}
	hasChanged := nextFileInfo.Size() != m.fileInfo.Size() || nextFileInfo.ModTime() != m.fileInfo.ModTime()
	return hasChanged
}

func obfuscationStream() (cipher.Stream, error) {
	block, err := aes.NewCipher(obfuscationKey)
	if err != nil {
		return nil, fmt.Errorf("Unable to initialize AES for obfuscation: %v", err)
	}
	iv := make([]byte, block.BlockSize())
	return cipher.NewOFB(block, iv), nil
}
