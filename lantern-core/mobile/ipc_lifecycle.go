package mobile

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/env"
	"github.com/getlantern/radiance/ipc"

	"github.com/getlantern/lantern/lantern-core/utils"
)

const (
	ipcStartTimeout = 60 * time.Second
	// bootstrapCloseWait bounds how long close waits for an in-flight backend
	// bootstrap before shutting it down anyway.
	bootstrapCloseWait = 2 * time.Second
)

var (
	errIPCLifecycleBusy = errors.New("ipc server lifecycle operation in progress")
	errIPCStartCanceled = errors.New("ipc server startup canceled")

	ipcClient    atomic.Pointer[ipc.Client] // loopback client for extension process
	ipcLifecycle ipcLifecycleState
)

// ipcState tracks the start/run lifecycle of the local IPC server. It's
// tracked separately from closing: beginIPCClose can cancel an in-flight
// start (via the generation bump) without waiting for it, so a close and a
// start can be in progress at the same time.
type ipcState int

const (
	ipcIdle ipcState = iota
	ipcStarting
	ipcRunning
)

type ipcLifecycleState struct {
	mu           sync.Mutex
	server       *ipc.Server
	backend      *backend.LocalBackend
	bootstrapped <-chan struct{}
	startState   ipcState
	closing      bool
	generation   uint64
}

type ipcResources struct {
	server  *ipc.Server
	backend *backend.LocalBackend
	// bootstrapped closes when the detached backend bootstrap returns.
	bootstrapped <-chan struct{}
}

// close shuts down the server and its backend. It gives an in-flight bootstrap
// a brief chance to finish first, so the common stop-during-startup does not
// tear the backend down from under its own Start.
func (resources ipcResources) close() {
	if resources.server != nil {
		_ = resources.server.Close()
	}
	// Wait before touching the backend: the bootstrap is still using it.
	if resources.bootstrapped != nil {
		select {
		case <-resources.bootstrapped:
		case <-time.After(bootstrapCloseWait):
			// Bounded on purpose: a bootstrap wedged on a censored network
			// must not hold teardown open. Close cancels the backend context
			// the bootstrap runs under, so it unwinds from here.
			slog.Warn("Closing IPC backend while its bootstrap is still running",
				"waited", bootstrapCloseWait)
		}
	}
	if resources.backend != nil {
		resources.backend.Close()
	}
}

type ipcStartResult struct {
	resources ipcResources
	err       error
}

// getClient returns an IPC client. It prefers the loopback client created by
// StartIPCServer (extension process), falling back to lanternCore's client
// (main app process).
func getClient() (*ipc.Client, error) {
	if client := ipcClient.Load(); client != nil {
		return client, nil
	}
	core, err := getCore()
	if err != nil {
		return nil, err
	}
	return core.Client(), nil
}

// StartIPCServer starts the local IPC server. Once it is running, repeated
// calls are no-ops.
func StartIPCServer(platform utils.PlatformInterface, opts *utils.Opts) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		return struct{}{}, startIPCServer(platform, opts)
	})
	return err
}

// startIPCServer builds the backend, then publishes it if shutdown did not
// happen in the meantime.
func startIPCServer(platform utils.PlatformInterface, opts *utils.Opts) error {
	generation, shouldStart, err := beginIPCStart()
	if err != nil || !shouldStart {
		return err
	}
	defer finishIPCStart()

	// The backend's config fetcher captures common.GetBaseURL() at
	// construction, so the environment must be set before NewLocalBackend.
	// SetupRadiance's SetStagingEnv runs too late on Android, where
	// StartIPCServer is called first.
	if opts.IsStaging() {
		env.SetStagingEnv()
	}

	startupCtx, cancelStartup := context.WithTimeout(context.Background(), ipcStartTimeout)
	defer cancelStartup()

	resources, err := startIPCResources(startupCtx, backend.Options{
		DataDir:           opts.DataDir,
		LogDir:            opts.LogDir,
		Locale:            opts.Locale,
		LogLevel:          opts.LogLevel,
		DeviceID:          opts.Deviceid,
		TelemetryConsent:  opts.TelemetryConsent,
		PlatformInterface: platform,
	})
	if err != nil {
		return err
	}
	return publishIPCResources(generation, resources)
}

// beginIPCStart reserves the lifecycle for one startup attempt. The generation
// tells us whether shutdown happened before that attempt finished.
func beginIPCStart() (generation uint64, shouldStart bool, err error) {
	ipcLifecycle.mu.Lock()
	defer ipcLifecycle.mu.Unlock()

	if ipcLifecycle.startState == ipcRunning {
		return 0, false, nil
	}
	if ipcLifecycle.startState == ipcStarting || ipcLifecycle.closing {
		return 0, false, errIPCLifecycleBusy
	}
	ipcLifecycle.startState = ipcStarting
	return ipcLifecycle.generation, true, nil
}

// finishIPCStart releases the startup guard, resolving to ipcRunning if
// publishIPCResources succeeded or ipcIdle if the start failed or was
// canceled.
func finishIPCStart() {
	ipcLifecycle.mu.Lock()
	if ipcLifecycle.server != nil {
		ipcLifecycle.startState = ipcRunning
	} else {
		ipcLifecycle.startState = ipcIdle
	}
	ipcLifecycle.mu.Unlock()
}

// startIPCResources waits for backend setup and cleans up if the result arrives
// after the caller has stopped waiting.
func startIPCResources(startupCtx context.Context, opts backend.Options) (ipcResources, error) {
	resultCh := make(chan ipcStartResult)
	go func() {
		result := newIPCResources(opts)
		select {
		case resultCh <- result:
		case <-startupCtx.Done():
			result.resources.close()
		}
	}()

	select {
	case result := <-resultCh:
		return result.resources, result.err
	case <-startupCtx.Done():
		return ipcResources{}, fmt.Errorf(
			"ipc server startup exceeded %s: %w",
			ipcStartTimeout,
			startupCtx.Err(),
		)
	}
}

// newIPCResources builds the local backend and starts its IPC server.
//
// Start runs detached because it is network-dependent bootstrap — config fetch
// and transport construction — that takes seconds on a censored network, while
// the iOS caller is a NEPacketTunnelProvider that iOS kills at ~7.5s
// (getlantern/engineering#3822). The app process has always run this same
// sequence detached; only the extension paid for it inline. Requests arriving
// before it finishes wait on their own deadline rather than failing, so the
// server is safe to publish first.
func newIPCResources(opts backend.Options) ipcStartResult {
	localBackend, err := backend.NewLocalBackend(context.Background(), opts)
	if err != nil {
		return ipcStartResult{err: fmt.Errorf("error creating backend for IPC server: %w", err)}
	}

	server := ipc.NewServer(localBackend, !common.IsMobile())
	if err := server.Start(); err != nil {
		localBackend.Close()
		return ipcStartResult{err: err}
	}

	return ipcStartResult{resources: ipcResources{
		server:       server,
		backend:      localBackend,
		bootstrapped: bootstrapBackend(localBackend),
	}}
}

// bootstrapBackend runs the backend's network-dependent Start off the caller's
// path and returns a handle that closes when it finishes. A package var so
// tests can stand in a bootstrap that takes as long as a censored network does.
var bootstrapBackend = func(localBackend *backend.LocalBackend) <-chan struct{} {
	bootstrapped := make(chan struct{})
	go func() {
		defer close(bootstrapped)
		localBackend.Start()
	}()
	return bootstrapped
}

// publishIPCResources makes a completed startup visible to clients. If
// CloseIPCServer ran during setup, it closes the new resources instead.
func publishIPCResources(generation uint64, resources ipcResources) error {
	ipcLifecycle.mu.Lock()
	if generation != ipcLifecycle.generation {
		ipcLifecycle.mu.Unlock()
		resources.close()
		return errIPCStartCanceled
	}
	ipcLifecycle.backend = resources.backend
	ipcLifecycle.server = resources.server
	ipcLifecycle.bootstrapped = resources.bootstrapped
	ipcClient.Store(newLoopbackClient(resources.backend))
	ipcLifecycle.mu.Unlock()
	return nil
}

// CloseIPCServer detaches the current IPC resources before shutting them down.
func CloseIPCServer() error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		resources, shouldClose := beginIPCClose()
		if !shouldClose {
			return struct{}{}, nil
		}
		defer finishIPCClose()

		resources.close()
		return struct{}{}, nil
	})
	return err
}

// beginIPCClose detaches the live resources and invalidates any in-flight start.
func beginIPCClose() (ipcResources, bool) {
	ipcLifecycle.mu.Lock()
	defer ipcLifecycle.mu.Unlock()

	if ipcLifecycle.closing {
		return ipcResources{}, false
	}
	ipcLifecycle.closing = true
	ipcLifecycle.generation++
	ipcClient.Store(nil)

	resources := ipcResources{
		server:       ipcLifecycle.server,
		backend:      ipcLifecycle.backend,
		bootstrapped: ipcLifecycle.bootstrapped,
	}
	ipcLifecycle.server = nil
	ipcLifecycle.backend = nil
	ipcLifecycle.bootstrapped = nil
	if ipcLifecycle.startState == ipcRunning {
		ipcLifecycle.startState = ipcIdle
	}
	return resources, true
}

// finishIPCClose releases the shutdown guard.
func finishIPCClose() {
	ipcLifecycle.mu.Lock()
	ipcLifecycle.closing = false
	ipcLifecycle.mu.Unlock()
}
