// Package autoupdate provides Lantern with special tools to autoupdate itself
// with minimal effort.
package autoupdate

import (
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/getlantern/go-update"
	"github.com/getlantern/go-update/check"
)

// Making sure AutoUpdate and Patch satisfy AutoUpdater and Patcher.
var (
	_ = AutoUpdater(&AutoUpdate{})
	_ = Patcher(&Patch{})
)

var (
	// How much time should we wait between update attempts?
	sleepTime = time.Hour * 4
)

// AutoUpdate satisfies AutoUpdater and can be used for other programs to
// configure automatic updates.
type AutoUpdate struct {
	cfg *Config
	// When a patch has been applied, the patch's version will be sent to
	// UpdatedTo.
	UpdatedTo chan string
}

// New creates an AutoUpdate struct based in the configuration defined in
// config.go.
func New(cfg *Config) *AutoUpdate {
	if cfg == nil {
		panic(`autoupdate: Configuration must not be nil.`)
	}

	a := &AutoUpdate{
		UpdatedTo: make(chan string),
		cfg:       cfg,
	}

	// Validating and setting version.
	a.SetVersion(cfg.CurrentVersion)

	// Setting update's HTTP client.
	if a.cfg.HTTPClient == nil {
		update.HTTPClient = &http.Client{}
	} else {
		update.HTTPClient = a.cfg.HTTPClient
	}

	return a
}

// SetVersion sets the version of the process' executable file.
func (a *AutoUpdate) SetVersion(v string) {
	if !strings.HasPrefix(v, "v") {
		// Panicking because versions must begin with "v".
		panic(`autoupdate: Versions must begin with a "v".`)
	}
	if !isVersionTag(v) {
		panic(`autoupdate: Versions must be in the form vX.Y.Z.`)
	}
	a.cfg.CurrentVersion = v
}

// Version returns the internal version value passed to SetVersion(). If
// SetVersion() has not been called yet, a negative value will be returned
// instead.
func (a *AutoUpdate) Version() string {
	return a.cfg.CurrentVersion
}

// check uses go-update to look for updates.
func (a *AutoUpdate) check() (res *check.Result, err error) {
	var up *update.Update

	param := check.Params{
		AppVersion: a.Version(),
	}

	up = update.New().ApplyPatch(update.PATCHTYPE_BSDIFF)

	if _, err = up.VerifySignatureWithPEM(a.cfg.SignerPublicKey); err != nil {
		return nil, err
	}

	if res, err = param.CheckForUpdate(updateURI, up); err != nil {
		if err == check.NoUpdateAvailable {
			return nil, nil
		}
		return nil, err
	}

	return res, nil
}

// Query checks if a new version is available and returns a Patcher.
func (a *AutoUpdate) Query() (Patcher, error) {
	var res *check.Result
	var err error

	if res, err = a.check(); err != nil {
		return nil, err
	}

	if res == nil {
		// No new version is available.
		return &Patch{}, nil
	}

	return &Patch{res: res, v: res.Version}, nil
}

func (a *AutoUpdate) loop() {
	for {
		patch, err := a.Query()

		if err == nil {
			if VersionCompare(a.Version(), patch.Version()) == Higher {
				log.Printf("autoupdate: Attempting to update to %s.", patch.Version())

				err = patch.Apply()

				if err == nil {
					log.Printf("autoupdate: Patching succeeded!")
					// Updating version.
					a.UpdatedTo <- patch.Version()
					a.SetVersion(patch.Version())
				} else {
					log.Printf("autoupdate: Patching failed: %q\n", err)
				}

			} else {
				log.Printf("autoupdate: Already up to date.")
			}
		} else {
			log.Printf("autoupdate: Could not reach update server: %q\n", err)
		}

		time.Sleep(sleepTime)
	}
}

// Watch spawns a goroutine that will apply updates whenever they're available.
func (a *AutoUpdate) Watch() {
	if a.cfg.CurrentVersion == "" {
		// Panicking because Watch is useless without the ability to compare
		// versions.
		panic(`autoupdate: You must set the executable version in order to watch for updates!`)
	}
	go a.loop()
}
