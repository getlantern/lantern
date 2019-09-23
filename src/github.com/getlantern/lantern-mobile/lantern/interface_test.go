package client

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"testing"
	"time"
)

const (
	listenProxyAddr = "127.0.0.1:7672"
)

const expectedBody = "Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"

type testProtector struct{}

func (p *testProtector) Protect(fd int) error {
	log.Debugf("Simulating fd(%d) protection...")
	return nil
}

type testCb struct{}

func (cb *testCb) AfterConfigure() {
	log.Debugf("AfterConfigure called.")
}

func (cb *testCb) AfterStart() {
	log.Debugf("AfterStart called.")
}

func testReverseProxy() error {
	var req *http.Request

	req = &http.Request{
		Method: "GET",
		URL: &url.URL{
			Scheme: "http",
			Host:   "www.google.com",
			Path:   "http://www.google.com/humans.txt",
		},
		ProtoMajor: 1,
		ProtoMinor: 1,
		Header: http.Header{
			"Host": {"www.google.com:80"},
		},
	}

	client := &http.Client{
		Timeout: time.Second * 5,
		Transport: &http.Transport{
			Dial: func(n, a string) (net.Conn, error) {
				//return net.Dial("tcp", "127.0.0.1:9898")
				return net.Dial("tcp", listenProxyAddr)
			},
		},
	}

	var res *http.Response
	var err error

	if res, err = client.Do(req); err != nil {
		return err
	}

	var buf []byte

	buf, err = ioutil.ReadAll(res.Body)

	fmt.Printf(string(buf))

	if string(buf) != expectedBody {
		return errors.New("Expecting another response.")
	}

	return nil
}

func TestStartClientAndTestReverseProxy(t *testing.T) {

	var err error

	// Let's run a proxy instance.
	go func() {
		if RunClientProxy(listenProxyAddr, "TestApp", new(testProtector), new(testCb)); err != nil {
			t.Fatalf("RunClientProxy: %q", err)
		}
	}()

	// Waiting a bit so the server could start.
	time.Sleep(time.Second * 5)

	// Attempt to proxy something.
	if err = testReverseProxy(); err != nil {
		t.Fatal(err)
	}

	// Attempt to stop server.
	if err = StopClientProxy(); err != nil {
		t.Fatal(err)
	}

	// Attempt to run again on the same port should not fail since we stopped the
	// server.
	if err = RunClientProxy(listenProxyAddr, "TestApp", new(testProtector), new(testCb)); err != nil {
		t.Fatalf("RunClientProxy: %q", err)
	}

}
