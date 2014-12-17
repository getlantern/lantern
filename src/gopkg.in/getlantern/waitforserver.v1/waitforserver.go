// package waitforserver provides a function to wait for a server at given
// address.
//
// Typical usage:
//
//   import (
//     "time"
//
//     . "gopkg.in/getlantern/waitforserver.v1"
//   )
//
//   func doStuff() {
//     // start a server at localhost:5234
//     if err := WaitForServer("tcp", "localhost:5234", 10 * time.Second); err != nil {
//       // handle failure
//     }
//   }
//}
package waitforserver

import (
	"fmt"
	"net"
	"time"
)

// WaitForServer waits for a TCP server to start at the given address, waiting
// up to the given limit and reporting an error if the server didn't start
// within the time limit.
func WaitForServer(protocol string, addr string, limit time.Duration) error {
	cutoff := time.Now().Add(limit)
	for {
		if time.Now().After(cutoff) {
			return fmt.Errorf("Server never came up at %s address %s", protocol, addr)
		}
		c, err := net.DialTimeout(protocol, addr, limit)
		if err == nil {
			c.Close()
			return nil
		}
		time.Sleep(10 * time.Millisecond)
	}
}
