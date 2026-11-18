//go:build windows

package winservice

import (
	"context"
	"debug/pe"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

// Query asks the service manager for LanternSvc's status and config. It
// opens both with only the rights a standard user holds; mgr.Connect asks
// for full access, which needs admin.
func Query() (Status, error) {
	m, err := windows.OpenSCManager(nil, nil, windows.SC_MANAGER_CONNECT)
	if err != nil {
		return Status{}, fmt.Errorf("open service manager: %w", err)
	}
	defer windows.CloseServiceHandle(m)

	name, err := windows.UTF16PtrFromString(Name)
	if err != nil {
		return Status{}, err
	}
	h, err := windows.OpenService(m, name, windows.SERVICE_QUERY_STATUS|windows.SERVICE_QUERY_CONFIG)
	if errors.Is(err, windows.ERROR_SERVICE_DOES_NOT_EXIST) {
		return Status{State: StateNotInstalled}, nil
	}
	if err != nil {
		return Status{}, fmt.Errorf("open %s: %w", Name, err)
	}
	s := &mgr.Service{Name: Name, Handle: h}
	defer s.Close()

	st, err := s.Query()
	if err != nil {
		return Status{}, fmt.Errorf("query %s status: %w", Name, err)
	}
	cfg, err := s.Config()
	if err != nil {
		return Status{}, fmt.Errorf("query %s config: %w", Name, err)
	}
	return Status{
		State:           stateOf(st.State),
		StartType:       startTypeOf(cfg.StartType, cfg.DelayedAutoStart),
		ExitCode:        st.Win32ExitCode,
		ServiceExitCode: st.ServiceSpecificExitCode,
		BinaryMissing:   binaryMissing(cfg.BinaryPathName),
	}, nil
}

func stateOf(s svc.State) State {
	switch s {
	case svc.Stopped:
		return StateStopped
	case svc.StartPending:
		return StateStartPending
	case svc.StopPending:
		return StateStopPending
	case svc.Running:
		return StateRunning
	default:
		return StateOther
	}
}

func startTypeOf(startType uint32, delayed bool) StartType {
	switch startType {
	case mgr.StartAutomatic:
		if delayed {
			return StartDelayedAuto
		}
		return StartAuto
	case mgr.StartManual:
		return StartManual
	case mgr.StartDisabled:
		return StartDisabled
	default:
		return StartOther
	}
}

// binaryMissing reports whether the executable in a service's command line
// is gone. A command line it can't parse counts as present.
func binaryMissing(commandLine string) bool {
	args, err := windows.DecomposeCommandLine(commandLine)
	if err != nil || len(args) == 0 {
		return false
	}
	_, err = os.Stat(args[0])
	return errors.Is(err, fs.ErrNotExist)
}

// Repair reinstalls LanternSvc the way the installer does, by running
// "lanternd install" elevated. That recreates the service set to start
// automatically, copies its executable back, and starts it. Windows shows
// its elevation prompt first; declining it returns ErrRepairCancelled.
func Repair(ctx context.Context) error {
	exe, err := lanterndPath()
	if err != nil {
		return err
	}
	code, err := runElevated(ctx, exe, "install")
	if err != nil {
		return err
	}
	if code != 0 {
		return fmt.Errorf("lanternd install exited with code %d", code)
	}
	return nil
}

// lanterndPath finds lanternd.exe beside the app, preferring the arm64 build
// on an arm64 machine, as the installer does.
func lanterndPath() (string, error) {
	app, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("locate app: %w", err)
	}
	dir := filepath.Dir(app)
	candidates := []string{filepath.Join(dir, "lanternd.exe")}
	if nativeArm64() {
		candidates = append([]string{filepath.Join(dir, "arm64", "lanternd.exe")}, candidates...)
	}
	for _, path := range candidates {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}
	return "", fmt.Errorf("lanternd.exe not found in %s", dir)
}

// nativeArm64 reports whether the machine is arm64, even when this process
// runs emulated.
func nativeArm64() bool {
	var process, native uint16
	if err := windows.IsWow64Process2(windows.CurrentProcess(), &process, &native); err != nil {
		return runtime.GOARCH == "arm64"
	}
	return native == pe.IMAGE_FILE_MACHINE_ARM64
}

var procShellExecuteExW = windows.NewLazySystemDLL("shell32.dll").NewProc("ShellExecuteExW")

const (
	seeMaskNoCloseProcess = 0x00000040
	seeMaskNoAsync        = 0x00000100
)

// shellExecuteInfo is SHELLEXECUTEINFOW.
type shellExecuteInfo struct {
	size          uint32
	mask          uint32
	hwnd          windows.HWND
	verb          *uint16
	file          *uint16
	parameters    *uint16
	directory     *uint16
	show          int32
	instApp       windows.Handle
	idList        uintptr
	class         *uint16
	keyClass      windows.Handle
	hotKey        uint32
	iconOrMonitor windows.Handle
	process       windows.Handle
}

// runElevated runs exe with args through the "runas" verb, which shows the
// elevation prompt, and returns its exit code once it ends. When ctx ends
// first it stops waiting; the elevated process can't be stopped from here.
func runElevated(ctx context.Context, exe, args string) (uint32, error) {
	// ShellExecuteEx can call shell extensions over COM, so it runs on one
	// thread with COM initialized.
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	defer initCOM()()

	verb, err := windows.UTF16PtrFromString("runas")
	if err != nil {
		return 0, err
	}
	file, err := windows.UTF16PtrFromString(exe)
	if err != nil {
		return 0, err
	}
	params, err := windows.UTF16PtrFromString(args)
	if err != nil {
		return 0, err
	}
	info := shellExecuteInfo{
		mask:       seeMaskNoCloseProcess | seeMaskNoAsync,
		hwnd:       windows.GetForegroundWindow(),
		verb:       verb,
		file:       file,
		parameters: params,
		show:       windows.SW_HIDE,
	}
	info.size = uint32(unsafe.Sizeof(info))
	if ok, _, err := procShellExecuteExW.Call(uintptr(unsafe.Pointer(&info))); ok == 0 {
		if errors.Is(err, windows.ERROR_CANCELLED) {
			return 0, ErrRepairCancelled
		}
		return 0, fmt.Errorf("run %s elevated: %w", filepath.Base(exe), err)
	}
	if info.process == 0 {
		return 0, fmt.Errorf("run %s elevated: no process handle", filepath.Base(exe))
	}
	defer windows.CloseHandle(info.process)

	const poll = 250 * time.Millisecond
	for {
		event, err := windows.WaitForSingleObject(info.process, uint32(poll/time.Millisecond))
		switch event {
		case windows.WAIT_OBJECT_0:
			var code uint32
			if err := windows.GetExitCodeProcess(info.process, &code); err != nil {
				return 0, fmt.Errorf("read %s exit code: %w", filepath.Base(exe), err)
			}
			return code, nil
		case uint32(windows.WAIT_TIMEOUT):
			if err := ctx.Err(); err != nil {
				return 0, fmt.Errorf("wait for %s: %w", filepath.Base(exe), err)
			}
		default:
			return 0, fmt.Errorf("wait for %s: %w", filepath.Base(exe), err)
		}
	}
}

// initCOM initializes COM on the calling thread and returns its cleanup.
func initCOM() func() {
	err := windows.CoInitializeEx(0, windows.COINIT_APARTMENTTHREADED|windows.COINIT_DISABLE_OLE1DDE)
	if err == nil || errors.Is(err, syscall.Errno(windows.S_FALSE)) {
		return windows.CoUninitialize
	}
	// COM is already set up in another mode on this thread; use it as is.
	return func() {}
}
