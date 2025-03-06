package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"fmt"
	"os"
	"strings"
	"sync"

	"github.com/getlantern/lantern-outline/dart_api_dl"
	"github.com/getlantern/lantern-outline/logging"
)

var (
	logPort int64
	logMu   sync.Mutex

	watcherStarted bool
)

func configureLogging(logFile string, logPort int64) error {
	// Check if the log file exists.
	if _, err := os.Stat(logFile); err == nil {
		// Read and send the last 30 lines of the log file.
		fmt.Println("Sending last 30 log lines...")
		lines, err := logging.ReadLastLines(logFile, 30)
		if err != nil {
			return err
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
		})
	}
	return nil
}
