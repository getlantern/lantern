// Package autoupdate provides Lantern with special tools to autoupdate itself
// with minimal effort.
package autoupdate

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/go-update"
	"github.com/getlantern/go-update/check"
)

const noVersion = -1

// Making sure AutoUpdate and Patch satisfy AutoUpdater and Patcher.
var (
	_ = AutoUpdater(&AutoUpdate{})
	_ = Patcher(&Patch{})
)

var (
	// How much time should we wait between update attempts?
	sleepTime = time.Hour * 4
)

// SetProxy sets the proxy to use.
func SetProxy(proxyAddr string) {
	var err error

	if proxyAddr != "" {
		// Create a HTTP proxy and pass it to the update package.
		if update.HTTPClient, err = util.HTTPClient("", proxyAddr); err != nil {
			log.Printf("Could not use proxy: %q\n", err)
		}
	} else {
		update.HTTPClient = &http.Client{}
	}
}

// AutoUpdate satisfies AutoUpdater and can be used for other programs to
// configure automatic updates.
type AutoUpdate struct {
	cfg config
	v   int
	// When a patch has been applied, the patch's version will be sent to
	// UpdatedTo.
	UpdatedTo chan int
}

// New creates an AutoUpdate struct based in the configuration defined in
// config.go.
func New(appName string) *AutoUpdate {
	if configMap[appName] == nil {
		// Panicking because we can't continue with autoupdates without proper
		// configuration.
		panic(fmt.Sprintf(`autoupdate: You must define a new config["%s"] entry to configure updates for this application. See config.go.`, appName))
	}
	a := &AutoUpdate{
		UpdatedTo: make(chan int),
		cfg:       *configMap[appName],
		v:         noVersion,
	}
	return a
}

// SetVersion sets the version of the process' executable file.
func (a *AutoUpdate) SetVersion(i int) {
	if i < 0 {
		// Panicking because we need a valid version in order to tell when a new
		// version has been applied.
		panic(`autoupdate: Negative internal version values are not supported. `)
	}
	a.v = i
}

// Version returns the internal version value passed to SetVersion(). If
// SetVersion() has not been called yet, a negative value will be returned
// instead.
func (a *AutoUpdate) Version() int {
	return a.v
}

// check uses go-update to look for updates.
func (a *AutoUpdate) check() (res *check.Result, err error) {
	var up *update.Update

	param := check.Params{
		AppVersion: strconv.Itoa(a.Version()),
		AppId:      a.cfg.appID,
		// Should we pick an update channel from ENV? It could be useful to test
		// development updates.
		Channel: a.cfg.updateChannel,
	}

	up = update.New()

	// TODO: This is not working.
	// up = update.New().ApplyPatch(update.PATCHTYPE_BSDIFF)

	if _, err = up.VerifySignatureWithPEM(a.cfg.publicKey); err != nil {
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
		return &Patch{v: noVersion}, nil
	}

	// Setting patch's version.
	patchToVersion, _ := strconv.Atoi(res.Version)

	return &Patch{res: res, v: patchToVersion}, nil
}

func (a *AutoUpdate) loop() {
	for {
		patch, err := a.Query()

		if err == nil {
			if patch.Version() > a.Version() {

				if err = patch.Apply(); err != nil {
					log.Printf("autoupdate: Patch failed: %q\n", err)
				}

				// Updating version.
				a.UpdatedTo <- patch.Version()
				a.SetVersion(patch.Version())
			}
		} else {
			log.Printf("autoupdate: Could not reach update server: %q\n", err)
		}

		time.Sleep(sleepTime)
	}
}

// Watch spawns a goroutine that will apply updates whenever they're available.
func (a *AutoUpdate) Watch() {
	if a.v < 0 {
		// Panicking because Watch is useless without the ability to compare
		// versions.
		panic(`autoupdate: You must set the executable version in order to watch for updates!`)
	}
	go a.loop()
}
