package main

import (
	"fmt"
	"io"
	"os"
	"os/user"
	"strconv"
	"strings"

	"9fans.net/go/acme"
)

type acmeFile struct {
	name       string
	body       []byte
	offset     int
	runeOffset int
}

func acmeCurrentFile() (*acmeFile, error) {
	win, err := acmeCurrentWin()
	if err != nil {
		return nil, err
	}
	defer win.CloseFiles()
	_, _, err = win.ReadAddr() // make sure address file is already open.
	if err != nil {
		return nil, fmt.Errorf("cannot read address: %v", err)
	}
	err = win.Ctl("addr=dot")
	if err != nil {
		return nil, fmt.Errorf("cannot set addr=dot: %v", err)
	}
	q0, _, err := win.ReadAddr()
	if err != nil {
		return nil, fmt.Errorf("cannot read address: %v", err)
	}
	body, err := readBody(win)
	if err != nil {
		return nil, fmt.Errorf("cannot read body: %v", err)
	}
	tagb, err := win.ReadAll("tag")
	if err != nil {
		return nil, fmt.Errorf("cannot read tag: %v", err)
	}
	tag := string(tagb)
	i := strings.Index(tag, " ")
	if i == -1 {
		return nil, fmt.Errorf("strange tag with no spaces")
	}

	w := &acmeFile{
		name:       tag[0:i],
		body:       body,
		offset:     runeOffset2ByteOffset(body, q0),
		runeOffset: q0,
	}
	return w, nil
}

// We would use win.ReadAll except for a bug in acme
// where it crashes when reading trying to read more
// than the negotiated 9P message size.
func readBody(win *acme.Win) ([]byte, error) {
	var body []byte
	buf := make([]byte, 8000)
	for {
		n, err := win.Read("body", buf)
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		body = append(body, buf[0:n]...)
	}
	return body, nil
}

func acmeCurrentWin() (*acme.Win, error) {
	winid := os.Getenv("winid")
	if winid == "" {
		return nil, fmt.Errorf("$winid not set - not running inside acme?")
	}
	id, err := strconv.Atoi(winid)
	if err != nil {
		return nil, fmt.Errorf("invalid $winid %q", winid)
	}
	if err := setNameSpace(); err != nil {
		return nil, err
	}
	win, err := acme.Open(id, nil)
	if err != nil {
		return nil, fmt.Errorf("cannot open acme window: %v", err)
	}
	return win, nil
}

func runeOffset2ByteOffset(b []byte, off int) int {
	r := 0
	for i, _ := range string(b) {
		if r == off {
			return i
		}
		r++
	}
	return len(b)
}

func setNameSpace() error {
	if ns := os.Getenv("NAMESPACE"); ns != "" {
		return nil
	}
	ns, err := nsFromDisplay()
	if err != nil {
		return fmt.Errorf("cannot get name space: %v", err)
	}
	os.Setenv("NAMESPACE", ns)
	return nil
}

// taken from src/lib9/getns.c
// This should go into goplan9/plan9/client.
func nsFromDisplay() (string, error) {
	disp := os.Getenv("DISPLAY")
	if disp == "" {
		// original code had heuristic for OS X here;
		// we'll just assume that and fail anyway if it
		// doesn't work.
		disp = ":0.0"
	}
	// canonicalize: xxx:0.0 => xxx:0
	if i := strings.LastIndex(disp, ":"); i >= 0 {
		if strings.HasSuffix(disp, ".0") {
			disp = disp[:len(disp)-2]
		}
	}

	// turn /tmp/launch/:0 into _tmp_launch_:0 (OS X 10.5)
	disp = strings.Replace(disp, "/", "_", -1)

	u, err := user.Current()
	if err != nil {
		return "", fmt.Errorf("cannot get current user name: %v", err)
	}
	ns := fmt.Sprintf("/tmp/ns.%s.%s", u.Username, disp)
	_, err = os.Stat(ns)
	if os.IsNotExist(err) {
		return "", fmt.Errorf("no name space directory found")
	}
	if err != nil {
		return "", fmt.Errorf("cannot stat name space directory: %v", err)
	}
	// heuristics for checking permissions and owner of name space
	// directory omitted.
	return ns, nil
}
