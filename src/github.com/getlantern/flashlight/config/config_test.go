package config

import (
	"compress/gzip"
	"io/ioutil"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/fronted"
)

func domainFrontInitialConfig() {

	/*
		df := &client.FrontedServerInfo{
			Host:           defaultRoundRobin(),
			Port:           443,
			PoolSize:       0,
			MasqueradeSet:  cloudfront,
			MaxMasquerades: 20,
			QOS:            10,
			Weight:         4000,
			Trusted:        true,
		}
	*/

	masqueradeSets := make(map[string][]*fronted.Masquerade)
	masqueradeSets[cloudfront] = cloudfrontMasquerades

	fd := fronted.NewDialer(fronted.Config{
		Host:               "d2wi0vwulmtn99.cloudfront.net",
		Port:               443,
		PoolSize:           0,
		InsecureSkipVerify: true,
		BufferRequests:     false,
		DialTimeoutMillis:  10000,
		RedialAttempts:     3,
		OnDial:             func(conn net.Conn, err error) (net.Conn, error) { return nil, nil },
		OnDialStats:        func(success bool, domain, addr string, resolutionTime, connectTime, handshakeTime time.Duration) {},
		Masquerades:        cloudfrontMasquerades,
		MaxMasquerades:     1,
		RootCAs:            globals.TrustedCAs,
	})

	client := fd.NewDirectDomainFronter()

	url := "https://config-test.getiantem.org/cloud.yaml.gz"
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return
	}

	// Prevents intermediate nodes (CloudFlare) from caching the content
	req.Header.Set("Cache-Control", "no-cache")

	// make sure to close the connection after reading the Body
	// this prevents the occasional EOFs errors we're seeing with
	// successive requests
	req.Close = true

	resp, err := client.Do(req)
	if err != nil {
		return
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Error closing response body: %v", err)
		}
	}()

	if resp.StatusCode == 304 {
		log.Debugf("Config unchanged in cloud")
		return
	} else if resp.StatusCode != 200 {
		return
	}

	gzReader, err := gzip.NewReader(resp.Body)
	if err != nil {
		return
	}
	log.Debugf("Fetched cloud config")
	if data, err := ioutil.ReadAll(gzReader); err != nil {
		log.Debugf("Read: %v", string(data))
	}
}

func TestDomainFrontedConfig(t *testing.T) {
	domainFrontInitialConfig()
}

func TestCopyOldConfig(t *testing.T) {
	existsFunc := func(file string) (string, bool) {
		return "fullpath", true
	}

	path := copyNewest("lantern-2.yaml", existsFunc)
	assert.Equal(t, "fullpath", path, "unexpected path used")

	// Test with temp files to make sure the actual copy of an old file to a
	// new one works.
	tf, _ := ioutil.TempFile("", "2.0.1")
	tf2, _ := ioutil.TempFile("", "2.0.2")

	log.Debugf("Created temp file: %v", tf.Name())

	existsFunc = func(file string) (string, bool) {
		if file == "lantern-2.0.1.yaml" {
			return tf.Name(), true
		}
		return tf2.Name(), false
	}

	path = copyNewest("lantern-2.yaml", existsFunc)
	assert.Equal(t, tf.Name(), path, "unexpected path used")
}

func TestMajorVersion(t *testing.T) {
	ver := "222.00.1"
	maj := majorVersion(ver)
	assert.Equal(t, "222.00", maj, "Unexpected major version")
}

func TestDataCenter(t *testing.T) {
	dc := defaultRoundRobinForTerritory("IR")
	assert.Equal(t, "nl.fallbacks.getiantem.org", dc, "Unexpected data center")
	dc = defaultRoundRobinForTerritory("cn")
	assert.Equal(t, "jp.fallbacks.getiantem.org", dc, "Unexpected data center")
	dc = defaultRoundRobin()
	assert.Equal(t, "nl.fallbacks.getiantem.org", dc, "Unexpected data center")
}
