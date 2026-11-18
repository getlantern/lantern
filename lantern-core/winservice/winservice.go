// Package winservice checks and repairs LanternSvc, the Windows service that
// runs lanternd. The app can't reach lanternd while the service is down.
package winservice

import (
	"errors"
	"fmt"
	"log/slog"

	"github.com/getlantern/radiance/ipc"
)

// Name is the service lanternd's installer registers.
const Name = "LanternSvc"

// UnavailableMarker starts every UnavailableError message. The app matches
// on it to offer a repair.
const UnavailableMarker = "lantern_service_unavailable"

var (
	// ErrUnsupported is returned on platforms other than Windows.
	ErrUnsupported = errors.New("winservice: only supported on Windows")
	// ErrRepairCancelled means the user declined the elevation prompt. Its
	// text is matched by the app.
	ErrRepairCancelled = errors.New("lantern_service_repair_cancelled")
)

// State is the service's run state.
type State string

const (
	StateNotInstalled State = "not_installed"
	StateStopped      State = "stopped"
	StateStartPending State = "start_pending"
	StateStopPending  State = "stop_pending"
	StateRunning      State = "running"
	// StateOther covers the pause states, which LanternSvc doesn't accept.
	StateOther State = "other"
)

// StartType is how the service is set to start.
type StartType string

const (
	StartAuto        StartType = "auto"
	StartDelayedAuto StartType = "delayed_auto"
	StartManual      StartType = "manual"
	StartDisabled    StartType = "disabled"
	StartOther       StartType = "other"
)

// Status is what the service manager reports for LanternSvc.
type Status struct {
	State     State
	StartType StartType
	// ExitCode and ServiceExitCode are the Win32 and service-specific codes
	// the service last stopped with.
	ExitCode        uint32
	ServiceExitCode uint32
	// BinaryMissing is set when the executable the service runs is gone,
	// such as after antivirus quarantined it.
	BinaryMissing bool
}

// NeedsRepair reports whether the service can't run lanternd as it stands.
// A running or starting service is left alone: lanternd restarts its own
// child process.
func (s Status) NeedsRepair() bool {
	return s.State == StateNotInstalled || s.State == StateStopped || s.BinaryMissing
}

func (s Status) String() string {
	if s.State == StateNotInstalled {
		return string(StateNotInstalled)
	}
	return fmt.Sprintf("state=%s start=%s exit=%d/%d binary_missing=%t",
		s.State, s.StartType, s.ExitCode, s.ServiceExitCode, s.BinaryMissing)
}

// LogValue implements slog.LogValuer.
func (s Status) LogValue() slog.Value {
	return slog.GroupValue(
		slog.String("state", string(s.State)),
		slog.String("start", string(s.StartType)),
		slog.Uint64("exit_code", uint64(s.ExitCode)),
		slog.Uint64("service_exit_code", uint64(s.ServiceExitCode)),
		slog.Bool("binary_missing", s.BinaryMissing),
	)
}

// UnavailableError is an IPC failure caused by LanternSvc not running.
type UnavailableError struct {
	Status Status
	Err    error
}

func (e *UnavailableError) Error() string {
	return fmt.Sprintf("%s (%s): %v", UnavailableMarker, e.Status, e.Err)
}

func (e *UnavailableError) Unwrap() error { return e.Err }

// query is replaced in tests.
var query = Query

// Explain returns err as an *UnavailableError when lanternd is unreachable
// because LanternSvc needs repair, and err unchanged otherwise. It logs what
// the service manager reports, so issue reports show why lanternd was down.
func Explain(err error) error {
	if !errors.Is(err, ipc.ErrIPCNotRunning) {
		return err
	}
	status, qerr := query()
	if errors.Is(qerr, ErrUnsupported) {
		return err
	}
	if qerr != nil {
		slog.Warn("lanternd is unreachable and its service could not be queried", "error", qerr)
		return err
	}
	slog.Warn("lanternd is unreachable", "service", status)
	if !status.NeedsRepair() {
		return err
	}
	return &UnavailableError{Status: status, Err: err}
}
