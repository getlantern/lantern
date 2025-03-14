package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"os"
	"strings"
	"sync"

	"github.com/getlantern/lantern-outline/dart_api_dl"
	"github.com/getlantern/lantern-outline/logging"
)

var (
	logMu          sync.Mutex
	logPort        int64
	watcherStarted bool
)

func configureLogging(logFile string, logPort int64) error {
	logMu.Lock()
	defer logMu.Unlock()
	// Check if the log file exists.
	if _, err := os.Stat(logFile); err == nil {
		// Read and send the last 30 lines of the log file.
		lines, err := logging.ReadLastLines(logFile, 30)
		if err != nil {
			return err
		}
		dart_api_dl.SendToPort(logPort, strings.Join(lines, "\n"))
	}

	// Start the log watcher only once.
	if !watcherStarted {
		watcherStarted = true
		go logging.WatchLogFile(logFile, func(message string) {
			dart_api_dl.SendToPort(logPort, message)
		})
	}
	return nil
}
