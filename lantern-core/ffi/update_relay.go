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

//export stopUpdateRelay
func stopUpdateRelay() {
	_, _ = utils.RunOffCgoStack(func() (struct{}, error) {
		updaterelay.Stop()
		return struct{}{}, nil
	})
}
