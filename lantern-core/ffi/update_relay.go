//go:build !android && !ios && !macos

package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"github.com/getlantern/lantern/lantern-core/updaterelay"
	"github.com/getlantern/lantern/lantern-core/utils"
)

// startUpdateRelay returns a caller-owned feed URL or JSON error.
// Non-nil results must be released with freeCString.
//
//export startUpdateRelay
func startUpdateRelay(cacheDir, feedURL *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		address, err := updaterelay.Start(C.GoString(cacheDir), C.GoString(feedURL))
		if err != nil {
			return SendError(err)
		}
		return C.CString(address)
	})
}

// stopUpdateRelay cancels in-flight requests and releases the listener.
//
//export stopUpdateRelay
func stopUpdateRelay() {
	_, _ = utils.RunOffCgoStack(func() (struct{}, error) {
		updaterelay.Stop()
		return struct{}{}, nil
	})
}
