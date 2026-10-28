package helper

import (
	"errors"
	"io/fs"
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
