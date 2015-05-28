package draw

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"strings"
)

// OpenFont reads the named file and returns the font it defines. The name may
// be an absolute path, or identify a file in a standard font directory:
// /lib/font/bit, /usr/local/plan9, /mnt/font, etc.
func (d *Display) OpenFont(name string) (*Font, error) {
	// nil display is allowed, for querying font metrics
	// in non-draw program.
	if d != nil {
		d.mu.Lock()
		defer d.mu.Unlock()
	}
	return d.openFont(name)
}

func (d *Display) openFont(name string) (*Font, error) {
	data, err := ioutil.ReadFile(name)

	if err != nil && strings.HasPrefix(name, "/lib/font/bit/") {
		root := os.Getenv("PLAN9")
		if root == "" {
			root = "/usr/local/plan9"
		}
		name1 := root + "/font/" + name[len("/lib/font/bit/"):]
		data1, err1 := ioutil.ReadFile(name1)
		name, data, err = name1, data1, err1
	}

	if err != nil && strings.HasPrefix(name, "/mnt/font/") {
		data1, err1 := fontPipe(name[len("/mnt/font/"):])
		if err1 == nil {
			data, err = data1, err1
		}
	}
	if err != nil {
		return nil, err
	}

	return d.buildFont(data, name)
}

func fontPipe(name string) ([]byte, error) {
	data, err := exec.Command("fontsrv", "-pp", name).CombinedOutput()

	// Success marked with leading \001. Otherwise an error happened.
	if len(data) > 0 && data[0] != '\001' {
		i := bytes.IndexByte(data, '\n')
		if i >= 0 {
			data = data[:i]
		}
		return nil, fmt.Errorf("fontsrv -pp %s: %v", name, data)
	}
	if err != nil {
		return nil, err
	}
	return data[1:], nil
}
