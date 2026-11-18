//go:build windows

package winservice

import (
	"os"
	"path/filepath"
	"testing"
	"unsafe"

	"github.com/stretchr/testify/assert"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

func TestStateOf(t *testing.T) {
	assert.Equal(t, StateStopped, stateOf(svc.Stopped))
	assert.Equal(t, StateStartPending, stateOf(svc.StartPending))
	assert.Equal(t, StateStopPending, stateOf(svc.StopPending))
	assert.Equal(t, StateRunning, stateOf(svc.Running))
	assert.Equal(t, StateOther, stateOf(svc.Paused))
}

func TestStartTypeOf(t *testing.T) {
	assert.Equal(t, StartAuto, startTypeOf(mgr.StartAutomatic, false))
	assert.Equal(t, StartDelayedAuto, startTypeOf(mgr.StartAutomatic, true))
	assert.Equal(t, StartManual, startTypeOf(mgr.StartManual, false))
	assert.Equal(t, StartDisabled, startTypeOf(mgr.StartDisabled, false))
}

func TestShellExecuteInfoLayout(t *testing.T) {
	want := uintptr(60)
	if unsafe.Sizeof(uintptr(0)) == 8 {
		want = 112
	}
	assert.Equal(t, want, unsafe.Sizeof(shellExecuteInfo{}), "matches sizeof(SHELLEXECUTEINFOW)")
}

func TestBinaryMissing(t *testing.T) {
	dir := t.TempDir()
	exe := filepath.Join(dir, "Lantern Svc.exe")
	assert.NoError(t, os.WriteFile(exe, nil, 0o600))

	assert.False(t, binaryMissing(`"`+exe+`" run --data-path x`), "quoted path with a space")
	assert.True(t, binaryMissing(`"`+filepath.Join(dir, "gone.exe")+`" run`))
	assert.False(t, binaryMissing(""), "an unparsable command line counts as present")
}
