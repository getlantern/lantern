// Package autoupdate provides Lantern with special tools to autoupdate itself
// with minimal effort.
package autoupdate

import (
	"fmt"
	"net/http"
	"time"

	"github.com/blang/semver"
	"github.com/getlantern/go-update"
	"github.com/getlantern/go-update/check"
	"github.com/getlantern/golog"
)

var (
	log                  = golog.LoggerFor("autoupdate")
	defaultCheckInterval = time.Hour * 4
	defaultHTTPClient    = &http.Client{}
)

type Config struct {
	// CurrentVersion: the current version of the program, must be in the form
	// X.Y.Z
	CurrentVersion string

	version semver.Version

	// URL: the url at which to check for updates
	URL string

	// PublicKey: the public key against which to check the signature of any
	// received updates.
	PublicKey []byte

	// CheckInterval: the interval at which to check for updates, defaults to
	// 4 hours.
	CheckInterval time.Duration

	// HTTPClient: (optional), an http.Client to use when checking for updates
	HTTPClient *http.Client
}

// Apply applies the next available update whenever it is available, blocking
// until the next update has been applied. If ApplyNext returns without an
// error, that means that the current program's executable has been udpated in
// place and you may want to restart. If ApplyNext returns an error, that means
// that an unrecoverable error has occurred and we can't continue checking for
// updates.
func ApplyNext(cfg *Config) error {
	// Parse the semantic version
	var err error
	cfg.version, err = semver.Parse(cfg.CurrentVersion)
	if err != nil {
		return fmt.Errorf("Bad version string: %v", err)
	}
	if cfg.CheckInterval == 0 {
		cfg.CheckInterval = defaultCheckInterval
		log.Debugf("Defaulted CheckInterval to %v", cfg.CheckInterval)
	}
	if cfg.HTTPClient == nil {
		cfg.HTTPClient = defaultHTTPClient
		log.Debug("Defaulted HTTPClient")
	}
	update.HTTPClient = cfg.HTTPClient

	return cfg.loop()
}

func (cfg *Config) loop() error {
	for {
		res, err := cfg.check()

		if err != nil {
			log.Errorf("Problem checking for update: %v", err)
		} else {
			if res == nil {
				log.Debug("No update available")
			} else if cfg.isNewerVersion(res.Version) {
				log.Debugf("Attempting to update to %s.", res.Version)
				err, errRecover := res.Update()
				if errRecover != nil {
					// This should never happen, if this ever happens it means bad news such as
					// a missing executable file.
					return fmt.Errorf("Failed to recover from failed update attempt: %v\n", errRecover)
				}
				if err == nil {
					log.Debugf("Patching succeeded!")
					return nil
				}
				log.Errorf("Patching failed: %q\n", err)
			} else {
				log.Debug("Already up to date.")
			}
		}

		time.Sleep(cfg.CheckInterval)
	}
}

func (cfg *Config) isNewerVersion(newer string) bool {
	nv, err := semver.Parse(newer)
	if err != nil {
		log.Errorf("Bad version string on update: %v", err)
		return false
	}
	return nv.GT(cfg.version)
}

// check uses go-update to look for updates.
func (cfg *Config) check() (res *check.Result, err error) {
	var up *update.Update

	param := check.Params{
		AppVersion: cfg.CurrentVersion,
	}

	up = update.New().ApplyPatch(update.PATCHTYPE_BSDIFF)

	if _, err = up.VerifySignatureWithPEM(cfg.PublicKey); err != nil {
		return nil, fmt.Errorf("Problem verifying signature of update: %v", err)
	}

	if res, err = param.CheckForUpdate(cfg.URL, up); err != nil {
		if err == check.NoUpdateAvailable {
			return nil, nil
		}
		return nil, fmt.Errorf("Problem fetching update: %v", err)
	}

	return res, nil
}
