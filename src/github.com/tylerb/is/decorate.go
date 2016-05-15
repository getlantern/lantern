package is

import (
	"bytes"
	"fmt"
	"runtime"
	"strings"
)

// callerinfo returns a string containing the file and line number of the test call
// that failed.
func callerinfo() (string, int, bool) {

	file := ""
	line := 0
	ok := false

	for i := 0; ; i++ {
		_, file, line, ok = runtime.Caller(i)
		if !ok {
			return "", 0, false
		}
		parts := strings.Split(file, "/")
		dir := parts[len(parts)-2]
		file = parts[len(parts)-1]
		if !strings.HasPrefix(dir, "is") || file == "is_test.go" {
			break
		}
	}

	return file, line, ok
}

// decorate prefixes the string with the file and line of the call site,
// inserts indentation tabs for formatting and adds the final newline if
// needed. This function was copied from the testing framework.
func decorate(s string) string {
	file, line, ok := callerinfo() // decorate + log + public function.
	if ok {
		// Truncate file name at last file name separator.
		if index := strings.LastIndex(file, "/"); index >= 0 {
			file = file[index+1:]
		} else if index = strings.LastIndex(file, "\\"); index >= 0 {
			file = file[index+1:]
		}
	} else {
		file = "???"
		line = 1
	}

	return buildCallerPrefix(file, line, s)
}

func buildCallerPrefix(file string, line int, s string) string {
	buf := new(bytes.Buffer)
	// Every line is indented at least one tab.
	err := buf.WriteByte('\t')
	if err != nil {
		return "???:1"
	}
	fmt.Fprintf(buf, "%s:%d: ", file, line)
	lines := strings.Split(s, "\n")
	if l := len(lines); l > 1 && lines[l-1] == "" {
		lines = lines[:l-1]
	}
	for i, l := range lines {
		if i > 0 {
			// Second and subsequent lines are indented an extra tab.
			_, err = buf.WriteString("\n\t\t")
			if err != nil {
				return "???:1"
			}
		}
		_, err = buf.WriteString(l)
		if err != nil {
			return "???:1"
		}
	}
	err = buf.WriteByte('\n')
	if err != nil {
		return "???:1"
	}
	return buf.String()
}
