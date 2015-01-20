package fdcount

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type Counter struct {
	match         string
	startingLines string
	startingCount int
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
	c.startingLines, c.startingCount = c.matchingLines(out)
	return c.startingCount, c, nil
}

// Asserts that the number of file descriptors added/removed since Counter was
// created euqlas the given number.
func (c *Counter) AssertDelta(expected int) error {
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
	lines := make([]string, 0)
	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, c.match) {
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
	if len(a) > 0 {
		result = fmt.Sprintf("New file descriptors\n-----------------------------\n%v\n",
			strings.Join(a, "\n"))
	}
	if len(r) > 0 {
		if len(a) > 0 {
			result = result + "\n"
		}
		result = fmt.Sprintf("%sRemoved file descriptors\n-----------------------------\n%v\n",
			result, strings.Join(r, "\n"))
	}
	return result
}
