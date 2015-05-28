// Test of time suffixes.

// Package foo ...
package foo

import (
	"flag"
	"time"
)

var rpcTimeoutMsec = flag.Duration("rpc_timeout", 100*time.Millisecond, "some flag") // MATCH /Msec.*\*time.Duration/

var timeoutSecs = 5 * time.Second // MATCH /Secs.*time.Duration/
