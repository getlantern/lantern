package draw

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
)

func getsubfont(d *Display, name string) (*Subfont, error) {
	data, err := ioutil.ReadFile(name)
	if err != nil && strings.HasPrefix(name, "/mnt/font/") {
		data1, err1 := fontPipe(name[len("/mnt/font/"):])
		if err1 == nil {
			data, err = data1, err1
		}
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "getsubfont: %v\n", err)
		return nil, err
	}
	f, err := d.readSubfont(name, bytes.NewReader(data), nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "getsubfont: can't read %s: %v\n", name, err)
	}
	return f, err
}
