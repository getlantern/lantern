package winservice

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/getlantern/radiance/ipc"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func stubQuery(t *testing.T, status Status, err error) *int {
	t.Helper()
	calls := 0
	prev := query
	query = func() (Status, error) {
		calls++
		return status, err
	}
	t.Cleanup(func() { query = prev })
	return &calls
}

func ipcDown() error {
	return fmt.Errorf("get VPN status failed: ipc request GET /vpn/status: %w: %w",
		ipc.ErrIPCNotRunning, errors.New(`open \\.\pipe\Lantern\lantern: The system cannot find the file specified.`))
}

func TestStatusNeedsRepair(t *testing.T) {
	tests := []struct {
		name   string
		status Status
		want   bool
	}{
		{"not installed", Status{State: StateNotInstalled}, true},
		{"stopped", Status{State: StateStopped, StartType: StartAuto}, true},
		{"disabled", Status{State: StateStopped, StartType: StartDisabled}, true},
		{"binary missing", Status{State: StateRunning, BinaryMissing: true}, true},
		{"running", Status{State: StateRunning, StartType: StartAuto}, false},
		{"starting", Status{State: StateStartPending, StartType: StartAuto}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, tt.status.NeedsRepair())
		})
	}
}

func TestExplain(t *testing.T) {
	t.Run("leaves other errors alone without asking the service manager", func(t *testing.T) {
		calls := stubQuery(t, Status{State: StateStopped}, nil)
		err := errors.New("ipc: status 500: tunnel failed")
		assert.Same(t, err, Explain(err))
		assert.Zero(t, *calls)
	})

	t.Run("explains a stopped service", func(t *testing.T) {
		status := Status{State: StateStopped, StartType: StartDisabled, ExitCode: 1077}
		stubQuery(t, status, nil)
		err := Explain(ipcDown())

		var unavailable *UnavailableError
		require.ErrorAs(t, err, &unavailable)
		assert.Equal(t, status, unavailable.Status)
		assert.ErrorIs(t, err, ipc.ErrIPCNotRunning, "the IPC error stays matchable")
		assert.True(t, strings.HasPrefix(err.Error(), UnavailableMarker), err.Error())
		assert.Contains(t, err.Error(), "start=disabled")
	})

	t.Run("explains a missing service", func(t *testing.T) {
		stubQuery(t, Status{State: StateNotInstalled}, nil)
		var unavailable *UnavailableError
		require.ErrorAs(t, Explain(ipcDown()), &unavailable)
		assert.Contains(t, unavailable.Error(), "(not_installed)")
	})

	t.Run("leaves a running service's error alone", func(t *testing.T) {
		stubQuery(t, Status{State: StateRunning, StartType: StartAuto}, nil)
		err := ipcDown()
		assert.Same(t, err, Explain(err))
	})

	t.Run("leaves the error alone when the service can't be queried", func(t *testing.T) {
		stubQuery(t, Status{}, errors.New("access denied"))
		err := ipcDown()
		assert.Same(t, err, Explain(err))
	})

	t.Run("leaves the error alone off Windows", func(t *testing.T) {
		stubQuery(t, Status{}, ErrUnsupported)
		err := ipcDown()
		assert.Same(t, err, Explain(err))
	})
}
