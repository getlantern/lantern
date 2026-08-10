package mobile

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/env"
	"github.com/getlantern/radiance/ipc"

	"github.com/getlantern/lantern/lantern-core/utils"
)

const ipcStartTimeout = 60 * time.Second

var (
	errIPCLifecycleBusy = errors.New("ipc server lifecycle operation in progress")
	errIPCStartCanceled = errors.New("ipc server startup canceled")

	ipcClient    atomic.Pointer[ipc.Client] // loopback client for extension process
	ipcLifecycle ipcLifecycleState
)

type ipcLifecycleState struct {
	mu         sync.Mutex
	server     *ipc.Server
	backend    *backend.LocalBackend
	starting   bool
	closing    bool
	generation uint64
}

type ipcResources struct {
	server  *ipc.Server
	backend *backend.LocalBackend
}

func (resources ipcResources) close() {
	if resources.server != nil {
		_ = resources.server.Close()
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

func StartIPCServer(platform utils.PlatformInterface, opts *utils.Opts) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		return struct{}{}, startIPCServer(platform, opts)
	})
	return err
}

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

func beginIPCStart() (generation uint64, shouldStart bool, err error) {
	ipcLifecycle.mu.Lock()
	defer ipcLifecycle.mu.Unlock()

	if ipcLifecycle.server != nil {
		return 0, false, nil
	}
	if ipcLifecycle.starting || ipcLifecycle.closing {
		return 0, false, errIPCLifecycleBusy
	}
	ipcLifecycle.starting = true
	return ipcLifecycle.generation, true, nil
}

func finishIPCStart() {
	ipcLifecycle.mu.Lock()
	ipcLifecycle.starting = false
	ipcLifecycle.mu.Unlock()
}

// startIPCResources bounds backend construction and server startup even though
// NewLocalBackend does not consistently observe a context. LocalBackend retains
// its context for its full lifetime, so construction uses an independent
// background context while startupCtx controls waiting and late-result cleanup.
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

func newIPCResources(opts backend.Options) ipcStartResult {
	localBackend, err := backend.NewLocalBackend(context.Background(), opts)
	if err != nil {
		return ipcStartResult{err: fmt.Errorf("error creating backend for IPC server: %w", err)}
	}
	localBackend.Start()

	server := ipc.NewServer(localBackend, !common.IsMobile())
	if err := server.Start(); err != nil {
		localBackend.Close()
		return ipcStartResult{err: err}
	}
	return ipcStartResult{resources: ipcResources{
		server:  server,
		backend: localBackend,
	}}
}

func publishIPCResources(generation uint64, resources ipcResources) error {
	ipcLifecycle.mu.Lock()
	if generation != ipcLifecycle.generation {
		ipcLifecycle.mu.Unlock()
		resources.close()
		return errIPCStartCanceled
	}
	ipcLifecycle.backend = resources.backend
	ipcLifecycle.server = resources.server
	ipcClient.Store(newLoopbackClient(resources.backend))
	ipcLifecycle.mu.Unlock()
	return nil
}

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
		server:  ipcLifecycle.server,
		backend: ipcLifecycle.backend,
	}
	ipcLifecycle.server = nil
	ipcLifecycle.backend = nil
	return resources, true
}

func finishIPCClose() {
	ipcLifecycle.mu.Lock()
	ipcLifecycle.closing = false
	ipcLifecycle.mu.Unlock()
}
