package main

import (
	"os"
)

// On windows, make sure that flashlight stops running if its parent
// process has stopped.  This is necessary on Windows, where child processes
// don't tend to get terminated it the parent process dies unexpectedly.
func init() {
	go func() {
		if *parentPID == 0 {
			log.Errorf("No parent PID specified, not terminating when orphaned")
		}
		parent, _ := os.FindProcess(*parentPID)
		if parent == nil {
			log.Errorf("No parent, not terminating when orphaned")
			return
		}
		log.Debugf("Waiting for parent %d to terminate", *parentPID)
		parent.Wait()
		log.Debug("Parent no longer running, terminating")
		os.Exit(0)
	}()
}
