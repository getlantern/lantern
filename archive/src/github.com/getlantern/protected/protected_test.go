package protected

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/golog"
	"github.com/stretchr/testify/assert"
)

var testAddr = "example.com:80"

type testprotector struct {
	lastProtected int
}

func (p *testprotector) Protect(fileDescriptor int) error {
	p.lastProtected = fileDescriptor
	return nil
}

func TestConnectIP(t *testing.T) {
	p := &testprotector{}
	pt := New(p.Protect, "8.8.8.8")
	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(netw, addr string) (net.Conn, error) {
				resolved, err := pt.Resolve("tcp", addr)
				if err != nil {
					return nil, err
				}
				return pt.Dial(netw, resolved.String(), 10*time.Second)
			},
			ResponseHeaderTimeout: time.Second * 2,
		},
	}
	err := sendTestRequest(client, testAddr)
	if assert.NoError(t, err, "Request should have succeeded") {
		assert.NotEqual(t, 0, p.lastProtected, "Should have gotten file descriptor from protecting")
	}
}

func TestConnectHost(t *testing.T) {
	p := &testprotector{}
	pt := New(p.Protect, "8.8.8.8")
	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(netw, addr string) (net.Conn, error) {
				return pt.Dial(netw, addr, 10*time.Second)
			},
			ResponseHeaderTimeout: time.Second * 2,
		},
	}
	err := sendTestRequest(client, testAddr)
	if assert.NoError(t, err, "Request should have succeeded") {
		assert.NotEqual(t, 0, p.lastProtected, "Should have gotten file descriptor from protecting")
	}
}

func sendTestRequest(client *http.Client, addr string) error {
	log := golog.LoggerFor("protected")

	req, err := http.NewRequest("GET", "http://"+addr+"/", nil)
	if err != nil {
		return fmt.Errorf("Error constructing new HTTP request: %s", err)
	}
	req.Header.Add("Connection", "keep-alive")
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("Could not make request to %s: %s", addr, err)
	}
	_, err = ioutil.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("Error reading response body: %s", err)
	}
	resp.Body.Close()
	log.Debugf("Successfully processed request to %s", addr)
	return nil
}
