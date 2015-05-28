package client

import (
	"fmt"
	"net"
	"os"
	"regexp"
	"strings"
)

func Dial(network, addr string) (*Conn, error) {
	c, err := net.Dial(network, addr)
	if err != nil {
		return nil, err
	}
	return NewConn(c)
}

func DialService(service string) (*Conn, error) {
	ns := Namespace()
	return Dial("unix", ns+"/"+service)
}

func Mount(network, addr string) (*Fsys, error) {
	c, err := Dial(network, addr)
	if err != nil {
		return nil, err
	}
	fsys, err := c.Attach(nil, getuser(), "")
	if err != nil {
		c.Close()
	}
	return fsys, err
}

func MountService(service string) (*Fsys, error) {
	c, err := DialService(service)
	if err != nil {
		return nil, err
	}
	fsys, err := c.Attach(nil, getuser(), "")
	if err != nil {
		c.Close()
	}
	return fsys, err
}

var dotZero = regexp.MustCompile(`\A(.*:\d+)\.0\z`)

// Namespace returns the path to the name space directory.
func Namespace() string {
	ns := os.Getenv("NAMESPACE")
	if ns != "" {
		return ns
	}

	disp := os.Getenv("DISPLAY")
	if disp == "" {
		// No $DISPLAY? Use :0.0 for non-X11 GUI (OS X).
		disp = ":0.0"
	}

	// Canonicalize: xxx:0.0 => xxx:0.
	if m := dotZero.FindStringSubmatch(disp); m != nil {
		disp = m[1]
	}

	// Turn /tmp/launch/:0 into _tmp_launch_:0 (OS X 10.5).
	disp = strings.Replace(disp, "/", "_", -1)

	// NOTE: plan9port creates this directory on demand.
	// Maybe someday we'll need to do that.

	return fmt.Sprintf("/tmp/ns.%s.%s", os.Getenv("USER"), disp)
}
