package client

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"testing"
	"time"
)

const listenProxyAddr = "127.0.0.1:9997"

var testURLs = map[string][]byte{
	"http://www.google.com/humans.txt": []byte("Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"),
	// TODO: This is not working, we actually need to implement a CONNECT request to proxy HTTPs traffic.
	// "https://www.google.com/humans.txt": []byte("Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"),
}

func testReverseProxy(uri string, expectedContent []byte) (err error) {
	var req *http.Request
	var u *url.URL

	if u, err = url.Parse(uri); err != nil {
		return err
	}

	port := 80

	if u.Scheme == "https" {
		// TODO: implement a CONNECT request.
	}

	req = &http.Request{
		Method: "GET",
		URL: &url.URL{
			Scheme: u.Scheme,
			Host:   u.Host,
			Path:   uri,
		},
		ProtoMajor: 1,
		ProtoMinor: 1,
		Header: http.Header{
			"Host": {fmt.Sprintf("%s:%d", u.Host, port)},
		},
	}

	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(n, a string) (net.Conn, error) {
				return net.Dial("tcp", listenProxyAddr)
			},
		},
	}

	var res *http.Response

	if res, err = client.Do(req); err != nil {
		return err
	}

	var buf []byte

	buf, err = ioutil.ReadAll(res.Body)

	fmt.Printf(string(buf))

	if bytes.Equal(buf, expectedContent) == false {
		return fmt.Errorf("The response we've got from %s differs from what we expected.", uri)
	}

	return nil
}

func TestListenAndServeStop(t *testing.T) {

	c := NewClient(listenProxyAddr)

	go func() {
		c.ListenAndServe()
	}()

	time.Sleep(time.Millisecond * 100)

	c.Stop()
}

func TestListenAndServeAgain(t *testing.T) {

	go func() {
		c := NewClient(listenProxyAddr)
		var err error
		if err = c.ListenAndServe(); err != nil {
			t.Fatal(err)
		}
	}()

}

func TestListenAndServeProxy(t *testing.T) {
	for uri, expectedContent := range testURLs {
		if err := testReverseProxy(uri, expectedContent); err != nil {
			t.Fatal(err)
		}
	}
}
