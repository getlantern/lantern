// Package byteexec provides a very basic facility for running executables
// supplied as byte arrays, which is handy when used with
// github.com/jteeuwen/go-bindata.
//
// byteexec works by storing the provided command in a file.
//
// Example Usage:
//
//    programBytes := // read bytes from somewhere
//    be, err := byteexec.New(programBytes)
//    if err != nil {
//      log.Fatalf("Uh oh: %s", err)
//    }
//    cmd := be.Command("arg1", "arg2")
//    // cmd is an os/exec.Cmd
//    err = cmd.Run()
//
// Note - byteexec.New is somewhat expensive, and Exec is safe for concurrent
// use, so it's advisable to create only one Exec for each executable.
package byteexec

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	"path"
	"path/filepath"
	"sync"

	"github.com/getlantern/golog"
)

const (
	fileMode = 0744
)

var (
	log = golog.LoggerFor("Exec")

	initMutex sync.Mutex
)

// Exec is a handle to an executable that can be used to create an exec.Cmd
// using the Command method. Exec is safe for concurrent use.
type Exec struct {
	filename string
}

// New creates a new Exec using the program stored in the provided data, at the
// provided filename (relative or absolute path allowed). If the path given is
// a relative path, the executable will be placed in one of the following
// locations:
//
// On Windows - %APPDATA%/byteexec
// On OSX - ~/Library/Application Support/byteexec
// All Others - ~/.byteexec
//
// Creating a new Exec can be somewhat expensive, so it's best to create only
// one Exec per executable and reuse that.
//
// WARNING - if a file already exists at this location and its contents differ
// from data, Exec will attempt to overwrite it.
func New(data []byte, filename string) (*Exec, error) {
	// Use initMutex to synchronize file operations by this process
	initMutex.Lock()
	defer initMutex.Unlock()

	var err error
	if !path.IsAbs(filename) {
		filename, err = inStandardDir(filename)
		if err != nil {
			return nil, err
		}
	}
	filename = renameExecutable(filename)
	log.Tracef("Placing executable in %s", filename)

	log.Trace("Attempting to open file for creating, but only if it doesn't already exist")
	file, err := os.OpenFile(filename, os.O_RDWR|os.O_CREATE|os.O_EXCL, fileMode)
	if err != nil {
		if !os.IsExist(err) {
			return nil, fmt.Errorf("Unexpected error opening %s: %s", filename, err)
		}

		log.Tracef("%s already exists, check to make sure contents is the same", filename)
		if dataMatches(filename, data) {
			log.Tracef("Data in %s matches expected, using existing", filename)
			return newExecFromExisting(filename)
		}

		log.Tracef("Data in %s doesn't match expected, truncating file", filename)
		file, err = os.OpenFile(filename, os.O_RDWR|os.O_CREATE|os.O_TRUNC, fileMode)
		if err != nil {
			return nil, fmt.Errorf("Unable to truncate %s: %s", filename, err)
		}
	}

	log.Tracef("Created new file at %s, saving executable", filename)
	_, err = file.Write(data)
	if err != nil {
		os.Remove(filename)
		return nil, fmt.Errorf("Unable to write to file at %s: %s", filename, err)
	}
	file.Sync()
	file.Close()

	log.Trace("File saved, returning new Exec")
	return newExec(filename)
}

// Command creates an exec.Cmd using the supplied args.
func (be *Exec) Command(args ...string) *exec.Cmd {
	return exec.Command(be.filename, args...)
}

// dataMatches compares the file at filename byte for byte with the given data
func dataMatches(filename string, data []byte) bool {
	file, err := os.OpenFile(filename, os.O_RDONLY, 0)
	if err != nil {
		log.Tracef("Unable to open existing file at %s for reading: %s", filename, err)
		return false
	}
	fileInfo, err := file.Stat()
	if err != nil {
		log.Tracef("Unable to stat file %s", filename)
		return false
	}
	if fileInfo.Size() != int64(len(data)) {
		return false
	}
	b := make([]byte, 65536)
	i := 0
	for {
		n, err := file.Read(b)
		if err != nil && err != io.EOF {
			log.Tracef("Error reading %s for comparison: %s", filename, err)
			return false
		}
		for j := 0; j < n; j++ {
			if b[j] != data[i] {
				return false
			}
			i = i + 1
		}
		if err == io.EOF {
			break
		}
	}
	return true
}

func newExecFromExisting(filename string) (*Exec, error) {
	fi, err := os.Stat(filename)
	if err != nil || fi.Mode() != fileMode {
		log.Tracef("Chmodding %s", filename)
		err = os.Chmod(filename, fileMode)
		if err != nil {
			return nil, fmt.Errorf("Unable to chmod file %s: %s", filename, err)
		}
	}
	return newExec(filename)
}

func newExec(filename string) (*Exec, error) {
	absolutePath, err := filepath.Abs(filename)
	if err != nil {
		return nil, err
	}
	return &Exec{filename: absolutePath}, nil
}

func inStandardDir(filename string) (string, error) {
	folder, err := pathForRelativeFiles()
	if err != nil {
		return "", err
	}
	err = os.MkdirAll(folder, fileMode)
	if err != nil {
		return "", fmt.Errorf("Unable to make folder %s: %s", folder, err)
	}
	return path.Join(folder, filename), nil
}

func inHomeDir(filename string) (string, error) {
	log.Tracef("Determining user's home directory")
	usr, err := user.Current()
	if err != nil {
		return "", fmt.Errorf("Unable to determine user's home directory: %s", err)
	}
	return path.Join(usr.HomeDir, filename), nil
}
