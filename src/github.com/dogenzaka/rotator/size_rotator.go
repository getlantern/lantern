package rotator

import (
	"errors"
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
		// Get available file name to be rotated
		for i := 1; i <= r.MaxRotation; i++ {
			renamedPath := r.path + "." + strconv.Itoa(i)
			stat, _ := os.Lstat(renamedPath)
			if stat == nil {
				err := os.Rename(r.path, renamedPath)
				if err != nil {
					return 0, err
				}
				if r.file != nil {
					// reset file reference
					r.file.Close()
					r.file = nil
				}
				break
			}
			if i == r.MaxRotation {
				return 0, errors.New("rotation count has been exceeded")
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
