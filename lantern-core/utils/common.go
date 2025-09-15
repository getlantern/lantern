package utils

import (
	"log"
	"os"
	"path/filepath"
	"runtime"

	"github.com/getlantern/radiance/issue"
)

type Opts struct {
	LogDir   string
	DataDir  string
	Deviceid string
	LogLevel string
	Locale   string
}

type PrivateServerEventListener interface {
	OpenBrowser(url string) error
	OnPrivateServerEvent(event string)
	OnError(err string)
}

// CreateLogAttachment tries to read the log file at logFilePath and returns
// an []*issue.Attachment with the log (if found)
func CreateLogAttachment(logFilePath string) []*issue.Attachment {
	if logFilePath == "" {
		return nil
	}
	data, err := os.ReadFile(logFilePath)
	if err != nil {
		log.Printf("could not read log file %q: %v", logFilePath, err)
		return nil
	}
	return []*issue.Attachment{{
		Name: "lantern.log",
		Data: data,
	}}
}

// DefaultDataDir returns the shared application data directory
func DefaultDataDir() string {
	switch runtime.GOOS {
	case "windows":
		programData := os.Getenv("ProgramData")
		if programData == "" {
			programData = `C:\ProgramData`
		}
		return filepath.Join(programData, "Lantern")
	case "darwin":
		sharedDir := filepath.Join("/Users", "Shared", "Lantern")
		return sharedDir
	case "linux":
		if xdg := os.Getenv("XDG_DATA_HOME"); xdg != "" {
			return filepath.Join(xdg, "lantern")
		}
		home, _ := os.UserHomeDir()
		return filepath.Join(home, ".local", "share", "lantern")
	default:
		home, _ := os.UserHomeDir()
		return filepath.Join(home, ".lantern")
	}
}

// DefaultLogDir returns the shared logs directory
func DefaultLogDir() string {
	switch runtime.GOOS {
	case "windows":
		return filepath.Join(DefaultDataDir(), "logs")
	case "darwin":
		home, _ := os.UserHomeDir()
		return filepath.Join(home, "Library", "Logs", "Lantern")
	default:
		return filepath.Join(DefaultDataDir(), "logs")
	}
}
