package draw

import (
	"fmt"
	"os"
	"strings"
)

/*
 * Default version: convert to file name
 */

func subfontname(cfname, fname string, maxdepth int) string {
	t := cfname
	if cfname == "*default*" {
		return t
	}
	if !strings.HasPrefix(t, "/") {
		dir := fname
		i := strings.LastIndex(dir, "/")
		if i >= 0 {
			dir = dir[:i]
		} else {
			dir = "."
		}
		t = dir + "/" + t
	}
	if maxdepth > 8 {
		maxdepth = 8
	}
	for i := 3; i >= 0; i-- {
		if 1<<uint(i) > maxdepth {
			continue
		}
		// try i-bit grey
		tmp2 := fmt.Sprintf("%s.%d", t, i)
		if _, err := os.Stat(tmp2); err == nil {
			return tmp2
		}
	}

	// try default
	if strings.HasPrefix(t, "/mnt/font/") {
		return t
	}
	if _, err := os.Stat(t); err == nil {
		return t
	}

	return ""
}
