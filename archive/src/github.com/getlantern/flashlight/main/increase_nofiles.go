// +build !windows

package main

import (
	"syscall"
)

const (
	// 1024 is the default hard limit on Ubuntu, so let's not get greedier than
	// that. On OS X, the default hard limit is unlimited.
	DesiredNoFilesLimit = 1024
)

func init() {
	// We increase the nofiles limit on UNIX platforms to avoid running out of
	// file descriptors
	var rLimit syscall.Rlimit
	err := syscall.Getrlimit(syscall.RLIMIT_NOFILE, &rLimit)
	if err != nil {
		log.Errorf("Error getting nofiles limit %v", err)
		return
	}
	if rLimit.Cur > DesiredNoFilesLimit {
		log.Debugf("Current nofiles soft limit of %d is enough", rLimit.Cur)
		return
	}
	rLimit.Cur = DesiredNoFilesLimit
	err = syscall.Setrlimit(syscall.RLIMIT_NOFILE, &rLimit)
	if err != nil {
		log.Errorf("Unable to increase nofiles limit: %v", err)
	}
	log.Debugf("Changed nofiles soft limit to %d", rLimit.Cur)
}
