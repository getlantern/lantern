package protected

import (
	"io/ioutil"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/golog"
)

var testAddr = "example.com:80"

func TestConnect(t *testing.T) {
	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(netw, addr string) (net.Conn, error) {
				return Dial(netw, addr)
			},
			ResponseHeaderTimeout: time.Second * 2,
		},
	}
	sendTestRequest(client, testAddr)
}

func sendTestRequest(client *http.Client, addr string) {
	log := golog.LoggerFor("protected")

	req, err := http.NewRequest("GET", "http://"+addr+"/", nil)
	if err != nil {
		log.Errorf("Error constructing new HTTP request: %s", err)
		return
	}
	req.Header.Add("Connection", "keep-alive")
	if resp, err := client.Do(req); err != nil {
		log.Errorf("Could not make request to %s: %s", addr, err)
		return
	} else {
		result, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			log.Errorf("Error reading response body: %s", err)
			return
		}
		resp.Body.Close()
		log.Debugf("Successfully processed request to %s", addr)
		log.Debugf("RESULT: %s", result)
	}
}
