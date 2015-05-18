package client

import (
	"net/http"
	"testing"
	"time"
)

func TestConfigDownload(t *testing.T) {
	httpDefaultClient := &http.Client{Timeout: time.Second * 5}
	var buf []byte
	var err error

	// Resetting Etag.
	lastCloudConfigETag = ""

	// Pulling first time.
	if buf, err = pullConfigFile(httpDefaultClient); err != nil {
		t.Fatal(err)
	}

	// Check that we got a valid config.
	cfg := &config{}
	if err = cfg.updateFrom(buf); err != nil {
		t.Fatal(err)
	}

	// Pulling a second time should trigger an error.
	if _, err = pullConfigFile(httpDefaultClient); err != nil {
		if err != errConfigurationUnchanged {
			t.Fatal(err)
		}
	}
}
