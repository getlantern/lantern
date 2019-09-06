package rotator

import (
	"os"
	"sync"
	"time"
)

const (
	dateFormat string = "2006-01-02"
)

// DailyRotator is writer which rotates file by date
type DailyRotator struct {
	path        string
	currentDate string
	file        *os.File
	Now         time.Time
	mutex       sync.Mutex
}

// Write binaries to the file.
// It will rotate files if date is chnaged from last writing.
func (r *DailyRotator) Write(bytes []byte) (n int, err error) {

	now := time.Now()

	// Override when time is provided
	if r.Now.Unix() > 0 {
		now = r.Now
	}

	nextDate := now.Format(dateFormat)

	// Using mutex instead of goroutine to avoid asynchronous writing
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.file == nil {

		// Check file existence
		stat, _ := os.Lstat(r.path)
		if stat != nil {
			// If file exists and modificated last date, just rotate it
			modDate := stat.ModTime().Format(dateFormat)
			if modDate != nextDate {
				if err := os.Rename(r.path, r.path+"."+modDate); err != nil {
					log.Debugf("Unable to rename file: %v", err)
				}
			}
		}

		file, err := os.OpenFile(r.path, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
		if err != nil {
			return 0, err
		}
		r.file = file
		r.currentDate = nextDate

	} else {

		// Do rotate
		if r.currentDate != nextDate {
			// Close current file
			if r.file != nil {
				err := r.file.Close()
				if err != nil {
					return 0, err
				}
			}
			// Resolve rotated file name
			renamedName := r.path + "." + r.currentDate
			// Check rotated file existence
			stat, _ := os.Lstat(renamedName)
			if stat != nil {
				// Remove if the file already exist
				err := os.Remove(renamedName)
				if err != nil {
					return 0, err
				}
			}
			// Rename current log file to be archived
			if err := os.Rename(r.path, renamedName); err != nil {
				log.Debugf("Unable to rename file: %v", err)
			}

			file, err := os.OpenFile(r.path, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
			if err != nil {
				return 0, err
			}
			r.file = file
			// Switch current date
			r.currentDate = nextDate
		}
	}

	// Reset now
	if r.Now.Unix() > 0 {
		r.Now = time.Time{}
	}

	return r.file.Write(bytes)
}

// WriteString writes strings to the file.
// It will rotate files if date is chnaged from last writing.
func (r *DailyRotator) WriteString(str string) (n int, err error) {
	return r.Write([]byte(str))
}

// Close the file
func (r *DailyRotator) Close() error {
	r.mutex.Lock()
	defer r.mutex.Unlock()
	return r.file.Close()
}

// NewDailyRotator creates rotator which writes to the file
func NewDailyRotator(path string) *DailyRotator {
	return &DailyRotator{path: path}
}
