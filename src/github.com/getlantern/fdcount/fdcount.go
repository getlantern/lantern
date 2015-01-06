package fdcount

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
)

type Counter struct {
	match         string
	startingCount int
	startingOut   []byte
}

// Returns a count of the file descriptors matching the given string (not a
// regex). Also returns a Counter that can be used to check the delta of file
// descriptors after this point.
//
// Currently only works on systems that have the lsof command available.
//
// see https://groups.google.com/forum/#!topic/golang-nuts/c0AnWXjzNIA
//
func Matching(s string) (int, *Counter, error) {
	c := &Counter{match: s}

	// Count initial file descriptors
	out, err := runLsof()
	if err != nil {
		return 0, nil, err
	}
	c.startingOut = out
	c.startingCount = c.countMatches(out)
	return c.startingCount, c, nil
}

// Asserts that the number of file descriptors added/removed since Counter was
// created euqlas the given number.
func (c *Counter) AssertDelta(expected int) error {
	out, err := runLsof()
	if err != nil {
		return err
	}
	actual := c.countMatches(out) - c.startingCount
	if actual != expected {
		return fmt.Errorf("Unexpected TCP file descriptor count. Expected %d, have %d.\n\nInitial lsof output\n-----------------------------\n%s\n\nCurrent lsof output\n-----------------------------\n%s\n",
			expected, actual, string(c.startingOut), string(out))
	}
	return nil
}

func (c *Counter) countMatches(out []byte) int {
	return bytes.Count(out, []byte(c.match))
}

func runLsof() ([]byte, error) {
	out, err := exec.Command("lsof", "-p", fmt.Sprintf("%v", os.Getpid())).Output()
	if err != nil {
		err = fmt.Errorf("Unable to run lsof: %v", err)
	}
	return out, err
}
