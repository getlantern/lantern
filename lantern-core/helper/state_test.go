package helper

import (
	"errors"
	"io/fs"
	"syscall"
	"testing"

	"github.com/stretchr/testify/assert"
)

type fakeSyncFile struct {
	writeErr, closeErr error
	closed             int
}

func (f *fakeSyncFile) Chmod(fs.FileMode) error { return nil }
func (f *fakeSyncFile) Write(b []byte) (int, error) {
	if f.writeErr != nil {
		return 0, f.writeErr
	}
	return len(b), nil
}
func (f *fakeSyncFile) Sync() error  { return nil }
func (f *fakeSyncFile) Close() error { f.closed++; return f.closeErr }

func TestWriteAndCloseReportsCloseErrors(t *testing.T) {
	writeErr := errors.New("write")
	closeErr := errors.New("close")

	ok := &fakeSyncFile{}
	assert.NoError(t, writeAndClose(ok, []byte("x")))
	assert.Equal(t, 1, ok.closed)

	closeFails := &fakeSyncFile{closeErr: closeErr}
	assert.ErrorIs(t, writeAndClose(closeFails, []byte("x")), closeErr)
	assert.Equal(t, 1, closeFails.closed)

	bothFail := &fakeSyncFile{writeErr: writeErr, closeErr: closeErr}
	err := writeAndClose(bothFail, []byte("x"))
	assert.ErrorIs(t, err, writeErr)
	assert.ErrorIs(t, err, closeErr)
	assert.Equal(t, 1, bothFail.closed)

	writeFails := &fakeSyncFile{writeErr: writeErr}
	assert.ErrorIs(t, writeAndClose(writeFails, []byte("x")), writeErr)
	assert.Equal(t, 1, writeFails.closed)
}

type fakeDir struct {
	syncErr error
	closed  int
}

func (d *fakeDir) Sync() error  { return d.syncErr }
func (d *fakeDir) Close() error { d.closed++; return nil }

func TestSyncDirIgnoresOnlyUnsupported(t *testing.T) {
	assert.NoError(t, syncDir(t.TempDir()))
	for _, err := range []error{nil, syscall.EINVAL, syscall.ENOTSUP, errors.ErrUnsupported} {
		d := &fakeDir{syncErr: err}
		assert.NoError(t, syncAndCloseDir(d), "%v", err)
		assert.Equal(t, 1, d.closed)
	}
	d := &fakeDir{syncErr: syscall.EIO}
	assert.ErrorIs(t, syncAndCloseDir(d), syscall.EIO)
	assert.Equal(t, 1, d.closed)
}
