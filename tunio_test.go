package tunio

import (
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"testing"
	"time"
)

const (
	deviceName = "tun0"
	deviceIP   = "10.0.0.2"
	deviceMask = "255.255.255.0"
)

const (
	googleHumansTxt = "Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"
)

func TestTransparentConfigure(t *testing.T) {
	fn := func(proto, addr string) (net.Conn, error) {
		return net.Dial("tcp", "10.0.0.105:20443")
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
