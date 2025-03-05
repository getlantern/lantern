package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/getlantern/lantern-outline/dart_api_dl"
	"github.com/getlantern/lantern-outline/logging"
)

const (
	logFile = "lantern.log"
)

var (
	logPort int64
	logMu   sync.Mutex

	watcherStarted bool
)

func configureLogging(baseDir string, logPort int64) {
	logFile := filepath.Join(baseDir, logFile)

	// Check if the log file exists.
	if _, err := os.Stat(logFile); err == nil {
		// Read and send the last 30 lines of the log file.
		fmt.Println("Sending last 30 log lines...")
		lines, err := logging.ReadLastLines(logFile, 30)
		if err != nil {
			log.Error(err)
			return
		}
		dart_api_dl.SendToPort(logPort, strings.Join(lines, "\n"))
	} else {
		fmt.Println("Log file does not exist, starting fresh.")
	}

	// Start the log timer once.
	if !watcherStarted {
		watcherStarted = true
		go logging.WatchLogFile(logFile, func(message string) {
			dart_api_dl.SendToPort(logPort, message)
			//sendLogToDart(port, message)
		})
	}
}

// TESTING
// startLogTimer creates a ticker that fires every five seconds.
func startLogTimer() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		<-ticker.C
		sendRandomLog()
	}
}

// sendRandomLog creates a random log message and calls the registered callback.
func sendRandomLog() {
	logMu.Lock()
	port := logPort
	logMu.Unlock()

	if port == 0 {
		return
	}

	// Create a random log message.
	logMsg := fmt.Sprintf("Random log message: %d", rand.Int())
	fmt.Println("Sending random log message %s", logMsg)
	cstr := C.CString(logMsg)
	defer C.free(unsafe.Pointer(cstr))

	// Post the log message to the Dart port.
	dart_api_dl.SendToPort(port, C.GoString(cstr))
}
