package rotator

import (
	"fmt"
	"os"
	"strconv"
	"sync"
)

const (
	defaultRotationSize = 1024 * 1024 * 10
	defaultMaxRotation  = 999
)

// SizeRotator is file writer which rotates files by size
type SizeRotator struct {
	path         string     // base file path
	totalSize    int64      // current file size
	file         *os.File   // current file
	mutex        sync.Mutex // lock
	RotationSize int64      // size threshold of the rotation
	MaxRotation  int        // maximum count of the rotation
}

// Write bytes to the file. If binaries exceeds rotation threshold,
// it will automatically rotate the file.
func (r *SizeRotator) Write(bytes []byte) (n int, err error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.file == nil {
		// Check file existence
		stat, _ := os.Lstat(r.path)
		if stat != nil {
			// Update initial size by file size
			r.totalSize = stat.Size()
		}
	}

	// Do rotate when size exceeded
	if r.totalSize+int64(len(bytes)) > r.RotationSize {
		if r.file != nil {
			if err := r.file.Close(); err != nil {
				return 0, fmt.Errorf("Unable to close file: %v", err)
			}
			r.file = nil
		}
		// Remove oldest file (in case it exists)
		dpath := r.path + "." + strconv.Itoa(r.MaxRotation)
		err := os.Remove(dpath)
		if err != nil && !os.IsNotExist(err) {
			return 0, fmt.Errorf("Unable to delete oldest file: %v", err)
		}

		// Rename existing files
		for i := r.MaxRotation - 1; i >= 0; i-- {
			opath := r.path
			if i != 0 {
				opath = opath + "." + strconv.Itoa(i)
			}
			npath := r.path + "." + strconv.Itoa(i+1)
			err := os.Rename(opath, npath)
			if err != nil && !os.IsNotExist(err) {
				return 0, fmt.Errorf("Unable to rename old file %v to %v: %v", opath, npath, err)
			}
		}
	}

	if r.file == nil {
		r.file, err = os.OpenFile(r.path, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
		if err != nil {
			return 0, err
		}
		// Switch current date
		r.totalSize = 0
	}

	n, err = r.file.Write(bytes)
	r.totalSize += int64(n)
	return n, err
}

// WriteString writes strings to the file. If binaries exceeds rotation threshold,
// it will automatically rotate the file.
func (r *SizeRotator) WriteString(str string) (n int, err error) {
	return r.Write([]byte(str))
}

// Close the file
func (r *SizeRotator) Close() error {
	r.mutex.Lock()
	defer r.mutex.Unlock()
	return r.file.Close()
}

// NewSizeRotator creates new writer of the file
func NewSizeRotator(path string) *SizeRotator {
	return &SizeRotator{
		path:         path,
		RotationSize: defaultRotationSize,
		MaxRotation:  defaultMaxRotation,
	}
}
