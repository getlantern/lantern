package tunio

import (
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"testing"
	"time"
)

const (
	deviceName = "tun0"
	deviceIP   = "10.0.0.2"
	deviceMask = "255.255.255.0"
)

var hostIP string

func init() {
	if os.Getenv("HOST_IP") != "" {
		hostIP = os.Getenv("HOST_IP")
	} else {
		hostIP = "10.0.0.105"
	}
}

const (
	googleHumansTxt = "Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"
)

func TestTransparentConfigure(t *testing.T) {
	// This function dials to an external host which will take anything that
	// arrives on port 20443 to redirect it to www.google.com:80
	fn := func(proto, addr string) (net.Conn, error) {
		return net.Dial("tcp", hostIP+":20443")
	}
	go func() {
		if err := Configure(deviceName, deviceIP, deviceMask, fn); err != nil {
			t.Fatal(err)
		}
	}()
	time.Sleep(time.Millisecond * 500)
	log.Printf("Waiting at %q...", deviceName)
}

func TestTransparentProxy(t *testing.T) {
	c := &http.Client{}

	// This is a simple test with and https URL.
	res, err := c.Get("https://www.google.com/humans.txt")
	if err != nil {
		t.Fatal(err)
	}

	b, err := ioutil.ReadAll(res.Body)
	if err != nil {
		t.Fatal(err)
	}

	if string(b) != googleHumansTxt {
		t.Fatalf("Expecting %q, got %q.", googleHumansTxt, string(b))
	}
}
