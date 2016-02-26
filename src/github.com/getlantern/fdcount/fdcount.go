package fdcount

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

var (
	maxAssertAttempts = uint(7)
)

// Matching returns a count of the file descriptors matching the given string (not a
// regex). Also returns a Counter that can be used to check the delta of file
// descriptors after this point.
//
// Currently only works on systems that have the lsof command available.
//
// see https://groups.google.com/forum/#!topic/golang-nuts/c0AnWXjzNIA
//
func Matching(match string) (int, *Counter, error) {
	c := &Counter{match: match}

	// Count initial file descriptors
	out, err := runLsof()
	if err != nil {
		return 0, nil, err
	}
	c.startingLines, c.startingCount = c.matchingLines(out)
	return c.startingCount, c, nil
}

// WaitUntilNoneMatch waits until no file descriptors match the given string, or
// the timeout is hit.
func WaitUntilNoneMatch(match string, timeout time.Duration) error {
	start := time.Now()
	var out []byte
	var err error
	var count int

	for time.Now().Sub(start) < timeout {
		out, err = runLsof()
		if err != nil {
			return err
		}
		_, count = matchingLines(match, out)
		if count == 0 {
			// Success!
			return nil
		}
		time.Sleep(50 * time.Millisecond)
	}

	return fmt.Errorf("%d lines still match %v\n\n%v", count, match, string(out))
}

// Counter memorizes the number of file descriptors and compare them.
type Counter struct {
	match         string
	startingLines string
	startingCount int
}

// AssertDelta asserts that the number of file descriptors added/removed since Counter was
// created equals the given number.
func (c *Counter) AssertDelta(expected int) error {
	var err error

	for try := uint(0); try < maxAssertAttempts; try++ {
		err = c.doAssertDelta(expected)
		if err == nil {
			return nil
		}
		// Count didn't match, could be we have some lingering descriptors, wait
		// and then try again.
		time.Sleep((50 << try) * time.Millisecond)
	}

	return err
}

func (c *Counter) doAssertDelta(expected int) error {
	out, err := runLsof()
	if err != nil {
		return err
	}
	endingLines, endingCount := c.matchingLines(out)
	actual := endingCount - c.startingCount
	if actual != expected {
		return fmt.Errorf("Unexpected TCP file descriptor count. Expected %d, have %d.\n\n%s",
			expected, actual, lsofDelta(c.startingLines, endingLines))
	}
	return nil
}

func (c *Counter) matchingLines(out []byte) (string, int) {
	return matchingLines(c.match, out)
}

func matchingLines(match string, out []byte) (string, int) {
	var lines []string
	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, match) {
			lines = append(lines, line)
		}
	}
	return strings.Join(lines, "\n"), len(lines)
}

func runLsof() ([]byte, error) {
	out, err := exec.Command("lsof", "-p", fmt.Sprintf("%v", os.Getpid())).Output()
	if err != nil {
		err = fmt.Errorf("Unable to run lsof: %v", err)
	}
	return out, err
}

func lsofDelta(start string, end string) string {
	startLines := strings.Split(start, "\n")
	endLines := strings.Split(end, "\n")

	added := make(map[string]interface{})
	removed := make(map[string]interface{})

	for _, line := range startLines {
		removed[line] = nil
	}

	for _, line := range endLines {
		added[line] = nil
		delete(removed, line)
	}

	for _, line := range startLines {
		delete(added, line)
	}

	a := make([]string, 0, len(added))
	r := make([]string, 0, len(removed))

	for line := range added {
		a = append(a, line)
	}

	for line := range removed {
		r = append(r, line)
	}

	result := ""
	if len(r) > 0 {
		result = fmt.Sprintf("Removed file descriptors\n-----------------------------\n%v\n",
			strings.Join(r, "\n"))
	}
	if len(a) > 0 {
		if len(r) > 0 {
			result = result + "\n"
		}
		result = fmt.Sprintf("%sNew file descriptors\n-----------------------------\n%v\n",
			result, strings.Join(a, "\n"))
	}
	return result
}
